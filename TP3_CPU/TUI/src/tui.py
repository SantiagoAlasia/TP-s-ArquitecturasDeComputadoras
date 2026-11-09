"""TUI de la Debug Unit RISC-V (estilo lazygit, una sola pantalla).

Uso:
    python tui.py                           # solo interfaz, sin puerto (revisar layout)
    python tui.py --port /dev/ttyUSB1       # con FPGA
    python tui.py --port COM4 --baud 115200 --asm programa.asm
"""
import argparse
import time
from pathlib import Path

from rich.table import Table
from rich.text import Text
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.theme import Theme
from textual.widgets import DirectoryTree, Label, RichLog, Static

import assembler
import protocol as proto
from link import SerialLink

# Paleta (inspirada en Posting). Si se cambia, actualizar tambien el bloque CSS.
BG      = "#100f21"   # fondo
BG_ALT  = "#181829"   # barra inferior
FG      = "#f4f4f4"   # texto
MUTED   = "#857e8d"   # texto atenuado
BORDER  = "#523564"   # borde sin foco
PINK    = "#d964b4"   # borde con foco / puntero
VIOLET  = "#9368dc"
LILAC   = "#d48dff"   # acentos (titulos, atajos, TX)
GREEN   = "#3fcda7"   # OK / RX / etapas
RED     = "#ff5f87"
AMBER   = "#f0c674"

THEME = Theme(
    name="debug-unit", dark=True,
    primary=VIOLET, secondary=LILAC, accent=PINK,
    foreground=FG, background=BG, surface=BG, panel=BG_ALT,
    success=GREEN, warning=AMBER, error=RED,
)

ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
       "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
       "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
       "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]


# ----------------------------------------------------------------------------
# Widgets
# ----------------------------------------------------------------------------
class Panel(VerticalScroll, can_focus=True):
    """Panel con borde, titulo y scroll. Se enfoca con Tab o con su numero."""

    def __init__(self, title: str, **kwargs):
        super().__init__(**kwargs)
        self.border_title = title
        self._body = Static()

    def compose(self) -> ComposeResult:
        yield self._body

    def set(self, renderable) -> None:
        self._body.update(renderable)


class AsmTree(DirectoryTree):
    """Arbol de directorios que solo muestra carpetas y archivos .asm / .s"""

    def filter_paths(self, paths):
        return [p for p in paths
                if (p.is_dir() and not p.name.startswith("."))
                or p.suffix.lower() in (".asm", ".s")]


class FilePicker(ModalScreen):
    """Buscador de archivos .asm. Devuelve la ruta elegida o None."""

    BINDINGS = [("escape", "cancel", "Cancelar")]

    def __init__(self, start: Path):
        super().__init__()
        self._start = start

    def compose(self) -> ComposeResult:
        with Vertical(id="picker"):
            yield Label("Elegí un archivo .asm   (↑↓ navegar · Enter abrir/seleccionar · Esc cancelar)")
            yield AsmTree(self._start)

    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        event.stop()
        self.dismiss(Path(event.path))

    def action_cancel(self) -> None:
        self.dismiss(None)


# ----------------------------------------------------------------------------
# Aplicacion
# ----------------------------------------------------------------------------
class DebugApp(App):
    TITLE = "RISC-V Debug Unit"
    ENABLE_COMMAND_PALETTE = False

    CSS = """
    Screen { background: #100f21; color: #f4f4f4; }

    Panel, RichLog#log {
        background: #100f21;
        border: round #523564;
        border-title-color: #d48dff;
        padding: 0 1;
        scrollbar-color: #523564;
        scrollbar-color-hover: #d964b4;
        scrollbar-color-active: #d964b4;
        scrollbar-background: #100f21;
        scrollbar-corner-color: #100f21;
    }
    Panel:focus, RichLog#log:focus {
        border: round #d964b4;
        border-title-color: #f4f4f4;
        border-title-style: bold;
    }

    #main   { height: 1fr; }
    #prog   { width: 44; height: 100%; }
    #right  { width: 1fr; height: 100%; }
    #regs   { height: 12; }
    #mem    { height: 1fr; }
    #pipe   { height: 9; }
    #log    { height: 8; }
    #bar    { height: 1; background: #181829; }
    #status { width: 1fr; padding: 0 1; text-wrap: nowrap; text-overflow: ellipsis; }
    #keys   { width: auto; padding: 0 1; }

    FilePicker { align: center middle; }
    #picker { width: 80%; height: 80%; border: round #d964b4; background: #100f21; padding: 0 1; }
    AsmTree { background: #100f21; }
    AsmTree > .directory-tree--folder { color: #d48dff; }
    AsmTree > .tree--cursor { background: #523564; color: #f4f4f4; }
    AsmTree:focus > .tree--cursor { background: #9368dc; color: #f4f4f4; }
    """

    # (tecla, descripcion) mostrados a la derecha de la barra de estado
    KEYS = [("p", "Programa"), ("c", "Continuo"), ("s", "Paso"),
            ("Tab", "Panel"), ("a", "ABI"), ("l", "Log"), ("q", "Salir")]

    BINDINGS = [
        Binding("p", "program", "Programa"),
        Binding("c", "run", "Continuo"),
        Binding("s", "step", "Paso"),
        Binding("tab", "focus_next", "Panel"),
        Binding("a", "toggle_abi", "ABI"),
        Binding("l", "toggle_log", "Log"),
        Binding("q", "quit", "Salir"),
        Binding("1", "focus_panel('prog')", show=False),
        Binding("2", "focus_panel('regs')", show=False),
        Binding("3", "focus_panel('mem')", show=False),
        Binding("4", "focus_panel('pipe')", show=False),
        Binding("5", "focus_panel('log')", show=False),
    ]

    def __init__(self, port: str | None, baud: int, asm: Path | None):
        super().__init__()
        self.register_theme(THEME)
        self.theme = "debug-unit"
        self.port, self.baud, self.initial_asm = port, baud, asm
        self.link: SerialLink | None = None

        # Estado del sistema (lo que muestran los paneles)
        self.state_txt = "SIN CONEXIÓN" if port is None else "PAUSADO"
        self.pc = 0
        self.regs = [0] * 32
        self.prev_regs = [0] * 32
        self.latches: dict[str, dict] = {}
        self.mem_words: list[int] = []
        self.use_abi = False

        # Programa cargado
        self.asm_path: Path | None = None
        self.listing: list[tuple[int | None, str]] = []   # (direccion | None, texto)

    # ------------------------------------------------------------------ UI
    def compose(self) -> ComposeResult:
        with Horizontal(id="main"):
            yield Panel("1 Programa", id="prog")
            with Vertical(id="right"):
                yield Panel("2 Registros", id="regs")
                yield Panel("3 Memoria de datos", id="mem")
                yield Panel("4 Pipeline (latches)", id="pipe")
                yield RichLog(id="log", markup=False, wrap=False)
        with Horizontal(id="bar"):
            yield Static(id="status")
            yield Static(id="keys")

    def on_mount(self) -> None:
        self.query_one("#log", RichLog).border_title = "5 Log UART"
        self.query_one("#prog").focus()
        self.render_keys()
        if self.port:
            self._open_port()
        if self.initial_asm:
            self._load_asm(self.initial_asm, send=False)
        self.refresh_all()

    # -------------------------------------------------------------- acciones
    def action_focus_panel(self, panel_id: str) -> None:
        self.query_one(f"#{panel_id}").focus()

    def action_toggle_abi(self) -> None:
        self.use_abi = not self.use_abi
        self.render_regs()

    def action_toggle_log(self) -> None:
        log = self.query_one("#log")
        log.display = not log.display

    def action_program(self) -> None:
        start = self.asm_path.parent if self.asm_path else Path.cwd()
        self.push_screen(FilePicker(start), self._on_file_chosen)

    def action_run(self) -> None:
        if self._send(proto.CMD_RUN, "c  (continuo)"):
            self.state_txt = "CORRIENDO"
            self.render_status()

    def action_step(self) -> None:
        self._send(proto.CMD_STEP, "s  (paso)")

    # ------------------------------------------------------------- programa
    def _on_file_chosen(self, path: Path | None) -> None:
        if path is not None:
            self._load_asm(path, send=True)

    def _load_asm(self, path: Path, send: bool) -> None:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            self.log_line("ERR", f"no se pudo leer {path}: {exc}")
            return
        self.asm_path = path
        self.listing = self._build_listing(text)
        self.log_line("---", f"archivo: {path.name}")
        self.render_prog()
        self.render_status()
        if not send:
            return
        try:
            words = assembler.assemble(text)
        except NotImplementedError as exc:
            self.log_line("WARN", f"{exc}: se muestra el programa pero no se envía")
            return
        except assembler.AssemblerError as exc:
            self.log_line("ERR", str(exc))
            return
        if self.link is None:
            self.log_line("WARN", "sin puerto serie: programa ensamblado, no enviado")
            return
        try:
            self.link.send_program(words)
            self.log_line("TX", f"p  N={len(words)}  ({4 * len(words)} bytes)")
        except Exception as exc:
            self.log_line("ERR", str(exc))

    @staticmethod
    def _build_listing(text: str) -> list[tuple[int | None, str]]:
        """Asigna direcciones asumiendo 1 instruccion = 4 bytes (heuristica).
        Si el ensamblador expande pseudoinstrucciones, esto debe reemplazarse
        por el mapa direccion->linea que devuelva el ensamblador real."""
        rows, addr = [], 0
        for raw in text.splitlines():
            code = raw.split("#")[0].split(";")[0].strip()
            if ":" in code:
                code = code.split(":", 1)[1].strip()
            if code and not code.startswith("."):
                rows.append((addr, raw.strip()))
                addr += 4
            elif raw.strip():
                rows.append((None, raw.strip()))
        return rows

    # ---------------------------------------------------------------- serie
    def _open_port(self) -> None:
        self.link = SerialLink(
            self.port, self.baud,
            on_frame=lambda h, p: self.call_from_thread(self.on_frame, h, p),
            on_error=lambda m: self.call_from_thread(self.on_link_error, m),
        )
        try:
            self.link.open()
            self.log_line("---", f"puerto abierto: {self.port} @ {self.baud}")
        except Exception as exc:
            self.link = None
            self.state_txt = "SIN CONEXIÓN"
            self.log_line("ERR", f"no se pudo abrir {self.port}: {exc}")

    def on_link_error(self, msg: str) -> None:
        self.state_txt = "SIN CONEXIÓN"
        self.log_line("ERR", f"enlace serie: {msg}")
        self.render_status()

    def _send(self, data: bytes, label: str) -> bool:
        if self.link is None:
            self.log_line("WARN", "sin puerto serie (iniciar con --port)")
            return False
        try:
            self.link.send(data)
            self.log_line("TX", label)
            return True
        except Exception as exc:
            self.log_line("ERR", str(exc))
            return False

    def on_frame(self, header: str, payload: bytes) -> None:
        """Procesa una trama recibida de la FPGA (corre en el hilo de la UI)."""
        self.log_line("RX", f"{header}  ({len(payload)} B)")
        if header == "S" and payload:
            flags = payload[0]
            if flags & proto.FLAG_HALTED:
                self.state_txt = "HALT"
            elif flags & proto.FLAG_RUNNING:
                self.state_txt = "CORRIENDO"
            else:
                self.state_txt = "PAUSADO"
        elif header == "C" and len(payload) >= 4:
            self.pc = int.from_bytes(payload[:4], "little")
        elif header == "R" and len(payload) >= 128:
            self.prev_regs = self.regs
            self.regs = proto.decode_words(payload[:128])
        elif header in proto.LATCHES:
            self.latches[header] = proto.decode_latch(header, payload)
        elif header == "M":
            self.mem_words = proto.decode_words(payload)
        elif header == "N":
            self.log_line("ERR", "la FPGA respondió NACK")
        self.refresh_all()

    # -------------------------------------------------------------- render
    def log_line(self, tag: str, msg: str) -> None:
        styles = {"TX": LILAC, "RX": GREEN, "ERR": f"bold {RED}",
                  "WARN": AMBER, "---": MUTED}
        line = Text(f"{time.strftime('%H:%M:%S')} ", style=MUTED)
        line.append(f"{tag:<4}", style=styles.get(tag, ""))
        line.append(msg)
        self.query_one("#log", RichLog).write(line)

    def refresh_all(self) -> None:
        self.render_prog()
        self.render_regs()
        self.render_pipe()
        self.render_mem()
        self.render_status()

    def _stage_by_addr(self) -> dict[int, str]:
        """Etapa en la que esta cada instruccion, segun el pc de cada latch."""
        stages = {}
        if self.latches:
            stages[self.pc] = "IF"
        for key, name in (("I", "ID"), ("D", "EX"), ("E", "MEM"), ("W", "WB")):
            pc = self.latches.get(key, {}).get("pc")
            if pc is not None:
                stages[pc] = name
        return stages

    def render_prog(self) -> None:
        panel = self.query_one("#prog", Panel)
        if not self.listing:
            panel.set(Text("Sin programa.\nPresioná [p] para elegir un .asm", style=MUTED))
            return
        stages = self._stage_by_addr()
        text = Text()
        current_row = 0
        for row, (addr, src) in enumerate(self.listing):
            if addr is None:
                text.append(f"         {src}\n", style=MUTED)
                continue
            current = addr == self.pc and bool(self.latches)
            if current:
                current_row = row
            text.append("▶ " if current else "  ", style=f"bold {PINK}")
            text.append(f"0x{addr:04X}  ", style=MUTED)
            text.append(f"{src:<24}", style="bold" if current else "")
            text.append(f" {stages.get(addr, '')}\n", style=f"bold {GREEN}")
        panel.set(text)
        # mantiene visible la instruccion actual (con algo de contexto arriba)
        panel.scroll_to(y=max(current_row - 3, 0), animate=False)

    def render_regs(self) -> None:
        text = Text()
        for row in range(8):
            for col in range(4):
                r = row + 8 * col
                label = ABI[r] if self.use_abi else f"x{r}"
                changed = self.regs[r] != self.prev_regs[r]
                text.append(f"{label:<5}", style=MUTED)
                text.append(f"{self.regs[r]:08X}", style=f"bold {BG} on {LILAC}" if changed else "")
                if col < 3:
                    text.append("  ")
            text.append("\n")
        text.append("\nresaltado = cambió en el último paso   [a] nombres ABI", style=MUTED)
        self.query_one("#regs", Panel).set(text)

    def render_pipe(self) -> None:
        grid = Table.grid(padding=(0, 3), expand=True)
        for _ in proto.LATCHES:
            grid.add_column()
        cols = []
        for key, (name, fields) in proto.LATCHES.items():
            col = Text(name + "\n", style=f"bold {LILAC}")
            data = self.latches.get(key)
            for fname, _, _ in fields:
                col.append(f"{fname:<6}", style=MUTED)
                if data is None:
                    col.append("--\n", style=MUTED)
                elif fname == "rd":
                    col.append(f"x{data[fname]}\n")
                else:
                    col.append(f"0x{data[fname]:08X}\n")
            cols.append(col)
        grid.add_row(*cols)
        self.query_one("#pipe", Panel).set(grid)

    def render_mem(self) -> None:
        panel = self.query_one("#mem", Panel)
        if not self.mem_words:
            panel.set(Text("Sin datos de memoria todavía", style=MUTED))
            return
        text = Text()
        for i in range(0, len(self.mem_words), 4):
            text.append(f"0x{4 * i:04X}  ", style=MUTED)
            text.append("  ".join(f"{w:08X}" for w in self.mem_words[i:i + 4]) + "\n")
        panel.set(text)

    def render_keys(self) -> None:
        text = Text()
        for i, (key, desc) in enumerate(self.KEYS):
            if i:
                text.append("  ")
            text.append(key, style=f"bold {LILAC}")
            text.append(f" {desc}")
        self.query_one("#keys", Static).update(text)

    def render_status(self) -> None:
        colors = {"CORRIENDO": GREEN, "PAUSADO": LILAC, "HALT": RED}
        color = colors.get(self.state_txt, MUTED)
        text = Text()
        text.append(f" {self.state_txt} ", style=f"bold {BG} on {color}")
        text.append(" │ ", style=MUTED)
        text.append(f"PC 0x{self.pc:04X}")
        text.append(" │ ", style=MUTED)
        text.append(f"{self.port} @ {self.baud}" if self.port else "sin puerto")
        if self.asm_path:
            text.append(" │ ", style=MUTED)
            text.append(self.asm_path.name)
        self.query_one("#status", Static).update(text)

    def on_unmount(self) -> None:
        if self.link:
            self.link.close()


def main() -> None:
    ap = argparse.ArgumentParser(description="TUI de la Debug Unit RISC-V")
    ap.add_argument("--port", help="puerto serie (ej. /dev/ttyUSB1, COM4). Sin esto: solo interfaz")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--asm", type=Path, help="archivo .asm a mostrar al iniciar")
    args = ap.parse_args()
    DebugApp(args.port, args.baud, args.asm).run()


if __name__ == "__main__":
    main()

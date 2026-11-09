"""Protocolo de la Debug Unit (PC <-> FPGA).

PC -> FPGA:
    'p' + N_lo + N_hi + 4*N bytes    cargar programa (N instrucciones, little-endian)
    'c'                              modo continuo
    's'                              un paso

FPGA -> PC (tramas):  header(1) + len_lo(1) + len_hi(1) + payload(len)
    S estado (flags)      C PC          R registros x0..x31
    I IF/ID   D ID/EX   E EX/MEM   W MEM/WB      M memoria de datos
    K / N : ACK / NACK, sin longitud ni payload (un solo byte)
"""

CMD_PROG = b"p"
CMD_RUN = b"c"
CMD_STEP = b"s"

SIMPLE_FRAMES = set(b"KN")           # tramas de un solo byte
LEN_FRAMES = set(b"SCRIDEWM")        # tramas con longitud + payload
VALID_HEADERS = SIMPLE_FRAMES | LEN_FRAMES

# Flags de la trama 'S' (1 byte)
FLAG_RUNNING = 0x01
FLAG_HALTED = 0x02
FLAG_PIPE_EMPTY = 0x04

# ---------------------------------------------------------------------------
# Campos de cada latch: (nombre, bit_inicial, ancho).
# PLACEHOLDER: ajustar cuando el pipeline defina sus latches. Mientras cada
# latch incluya "pc" la TUI puede marcar en que etapa esta cada instruccion.
# ---------------------------------------------------------------------------
LATCHES = {
    "I": ("IF/ID",  [("pc", 0, 32), ("instr", 32, 32)]),
    "D": ("ID/EX",  [("pc", 0, 32), ("rs1v", 32, 32), ("rs2v", 64, 32),
                     ("imm", 96, 32), ("rd", 128, 5)]),
    "E": ("EX/MEM", [("pc", 0, 32), ("alu", 32, 32), ("wdata", 64, 32),
                     ("rd", 96, 5)]),
    "W": ("MEM/WB", [("pc", 0, 32), ("alu", 32, 32), ("rdata", 64, 32),
                     ("rd", 96, 5)]),
}


def decode_latch(key: str, payload: bytes) -> dict:
    value = int.from_bytes(payload, "little")
    return {name: (value >> lsb) & ((1 << width) - 1)
            for name, lsb, width in LATCHES[key][1]}


def decode_words(payload: bytes) -> list[int]:
    """Bytes little-endian -> lista de palabras de 32 bits."""
    return [int.from_bytes(payload[i:i + 4], "little")
            for i in range(0, len(payload) - len(payload) % 4, 4)]


class FrameParser:
    """Arma tramas a partir de bytes sueltos. Si aparece un byte que no es un
    header valido mientras espera uno, lo descarta (resincronizacion)."""

    def __init__(self):
        self._state = "header"
        self._header = 0
        self._len = 0
        self._buf = bytearray()

    def feed(self, data: bytes) -> list[tuple[str, bytes]]:
        frames = []
        for b in data:
            if self._state == "header":
                if b in SIMPLE_FRAMES:
                    frames.append((chr(b), b""))
                elif b in LEN_FRAMES:
                    self._header, self._state = b, "len_lo"
                # cualquier otro byte se ignora
            elif self._state == "len_lo":
                self._len, self._state = b, "len_hi"
            elif self._state == "len_hi":
                self._len |= b << 8
                self._buf = bytearray()
                if self._len == 0:
                    frames.append((chr(self._header), b""))
                    self._state = "header"
                else:
                    self._state = "payload"
            else:  # payload
                self._buf.append(b)
                if len(self._buf) == self._len:
                    frames.append((chr(self._header), bytes(self._buf)))
                    self._state = "header"
        return frames

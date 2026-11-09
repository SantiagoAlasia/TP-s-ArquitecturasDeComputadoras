---
title: TUI
date: 2026-11-09
tags: [tui, textual, python, interfaz]
aliases: [Interfaz, rvdebug, Textual]
---

# TUI

Up: [Índice](INDEX.md)

Interfaz de terminal para operar la Debug Unit, al estilo de lazygit: **una sola pantalla** con toda la información y una barra de atajos. Código en `rvdebug/` (Python, [Textual](https://textual.textualize.io/) y pyserial). Probada en modo headless, sin FPGA.

## Disposición

```
┌─ 1 Programa ─────────┐┌─ 2 Registros ─────────────────────┐
│                      ││  (4 columnas x 8)                 │
│  (alto completo,     │├─ 3 Memoria de datos ──────────────┤
│   sigue al PC)       ││                                   │
└──────────────────────┘└───────────────────────────────────┘
┌─ 4 Pipeline (latches) ───────────────────────────────────┐
└──────────────────────────────────────────────────────────┘
┌─ 5 Log UART ─────────────────────────────────────────────┐
└──────────────────────────────────────────────────────────┘
 PAUSADO │ PC 0x0010 │ /dev/ttyUSB1 @ 115200 │ demo.asm      p Programa  c Continuo  s Paso ...
```

| Panel | Contenido |
|---|---|
| 1 Programa | Fuente del `.asm` con direcciones; marca la instrucción actual y la **etapa** (IF, ID, EX, MEM, WB) de cada una, calculada con el `pc` de cada latch. Sigue al PC si el programa es largo |
| 2 Registros | x0 a x31 en 4 columnas; resalta los que **cambiaron** respecto al snapshot anterior; `a` alterna `x1` y `ra` |
| 3 Memoria de datos | Solo el rango usado (`hwm`), 4 palabras por fila |
| 4 Pipeline | Un bloque por latch con campos con nombre |
| 5 Log UART | Bytes TX y RX, errores y avisos |
| Barra | Estado (`PAUSADO`, `CORRIENDO`, `HALT`, `SIN CONEXIÓN`), PC, puerto, archivo; atajos a la derecha |

## Atajos

| Tecla | Acción |
|---|---|
| `p` | Abrir el buscador de `.asm` y programar |
| `c` | Modo continuo |
| `s` | Un paso |
| `Tab` o `1` a `5` | Cambiar de panel |
| `a` | Alternar nombres de registros (`x` o ABI; ver [Glosario](12-glosario.md)) |
| `l` | Mostrar u ocultar el log |
| `q` | Salir |

## Cargar un programa

`p` abre un buscador de archivos (solo carpetas y `.asm` o `.s`). Al elegir uno: se muestra en el panel Programa, se llama a `assembler.assemble(texto)` y, si hay puerto, se envía `p + N + bytes`. También se puede pasar `--asm archivo.asm` al arrancar. El ensamblador es **solo un punto de enganche** (`assembler.py`): hoy lanza `NotImplementedError` y la TUI muestra el programa sin enviarlo.

## Estructura del código

| Archivo | Rol |
|---|---|
| `tui.py` | Aplicación Textual: paneles, atajos, buscador, tema |
| `protocol.py` | Constantes del [protocolo](02-protocolo-uart.md), parser de tramas con resincronización, tabla `LATCHES` |
| `link.py` | Hilo lector del puerto serie y envío de comandos |
| `assembler.py` | Gancho del ensamblador (`assemble`, `AssemblerError`) |
| `requirements.txt` | `textual`, `pyserial` |

## Paleta

Inspirada en Posting.

| Uso | Color |
|---|---|
| Fondo | `#100f21` |
| Borde sin foco | `#523564` |
| Borde con foco y puntero | `#d964b4` |
| Títulos, atajos, TX | `#d48dff` |
| OK, RX, etapas | `#3fcda7` |
| Errores, HALT | `#ff5f87` |
| Texto atenuado | `#857e8d` |

Las constantes están al principio de `tui.py`; el bloque `CSS` repite algunas como valores literales, así que un cambio de color hay que hacerlo en ambos lados. Necesita una terminal de 24 bits de color y unas **120 columnas** como mínimo.

## Cómo ejecutarla

```bash
cd ~/tp-riscv/rvdebug
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt     # ojo: con -r
python tui.py                       # solo interfaz, sin puerto
python tui.py --port /dev/ttyUSB1   # con la FPGA
```

Se eligió un venv y no Docker: el acceso al puerto serie en un contenedor es incómodo (hay que pasar el dispositivo y se pierde al reconectar la FPGA) y solo hay dos dependencias. Si da `Permission denied` en el puerto: `sudo usermod -aG dialout $USER` y volver a iniciar sesión.

## Limitaciones actuales

- Las direcciones del panel Programa son una **heurística** (1 instrucción = 4 bytes). Si el ensamblador expande pseudoinstrucciones se desfasan; lo correcto es que el ensamblador devuelva el mapa dirección a línea.
- Los campos de los latches en `LATCHES` son **provisorios** hasta que el pipeline defina los suyos.
- **Falta** bloquear el envío de comandos hasta recibir la trama `M` del snapshot anterior (ver [Protocolo UART](02-protocolo-uart.md)).

Related: [Protocolo UART](02-protocolo-uart.md), [Contrato con el CPU](08-contrato-cpu.md), [Pendientes y riesgos](11-pendientes.md)

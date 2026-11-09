---
title: Protocolo UART
date: 2026-11-09
tags: [protocolo, uart, debug-unit]
aliases: [Protocolo, Comandos, Tramas]
---

# Protocolo UART

Up: [Índice](INDEX.md)

Define cómo se hablan la PC (la [TUI](09-tui.md)) y la Debug Unit. Lo implementan el [Command Decoder](04-command-decoder.md) (PC a FPGA) y el [Serializer](07-serializer.md) (FPGA a PC); lo interpreta `protocol.py` en la TUI.

## Convenciones

- Los **comandos** son caracteres ASCII en **minúscula**; los **headers de respuesta** en **mayúscula**. Así un log nunca confunde un comando con un header.
- Todo valor multibyte va en **little-endian** (byte menos significativo primero), en ambos sentidos.
- Se mantuvieron pocos comandos a propósito; se pueden ampliar sin romper lo existente.

## Comandos (PC a FPGA)

| Byte | Código | Argumentos | Efecto | Respuesta |
|---|---|---|---|---|
| `p` | `0x70` | `N_lo`, `N_hi`, luego `4·N` bytes | Frena y resetea el CPU y carga el programa (N instrucciones) | Opcional: `K` |
| `c` | `0x63` | ninguno | Modo continuo: corre hasta HALT y drena el pipeline | Snapshot |
| `s` | `0x73` | ninguno | Un paso (un ciclo de clock) | Snapshot |

Reglas:

- `p` es **siempre válido**, incluso con el CPU corriendo. Es la salida de emergencia ante un bucle infinito.
- Si llega un `c` o `s` y el CPU ya está en HALT (o no hay programa válido), el Controller no lo habilita pero **igual responde con un snapshot** con el flag `halted = 1`. Así la TUI nunca queda esperando.
- Un byte desconocido en modo comando se ignora (el Decoder emite el pulso `error`, que hoy no se transmite).
- `N` se cuenta en **instrucciones** (2 bytes), no en bytes, así nunca queda un múltiplo de 4 roto. Rango válido: 1 a `IMEM_DEPTH - 1` (hay que dejar lugar para al menos un HALT; ver [pendientes](11-pendientes.md)).
- Si durante un `p` pasan más de 50 ms sin recibir un byte, se aborta la carga y `nwords` queda en 0.

Ejemplo: cargar 2 instrucciones y ejecutar en continuo.

```
70 02 00  <8 bytes de programa>  63
```

## Respuestas (FPGA a PC)

Formato de trama con longitud: `header` (1 byte) + `len_lo` + `len_hi` + `payload` (`len` bytes).

| Header | Contenido | Palabras de 32 bits |
|---|---|---|
| `S` | Estado: flags en el byte bajo | 1 |
| `C` | PC | 1 |
| `R` | Registros x0 a x31 | 32 |
| `I` | Latch IF/ID | según su ancho |
| `D` | Latch ID/EX | según su ancho |
| `E` | Latch EX/MEM | según su ancho |
| `W` | Latch MEM/WB | según su ancho |
| `M` | Memoria de datos usada (de 0 hasta `hwm`) | `mem_used_words` |
| `K` | ACK (opcional) | sin longitud ni payload: **un solo byte** |
| `N` | NACK | sin longitud ni payload: **un solo byte** |

Flags de la trama `S` (byte 0 del payload):

| Bit | Máscara | Significado |
|---|---|---|
| 0 | `0x01` | running |
| 1 | `0x02` | halted |
| 2 | `0x04` | pipeline vacío |

El Serializer manda `S` como una palabra completa (4 bytes); la TUI solo lee el primer byte.

## Snapshot

Cada `c` o `s` produce un **snapshot**: las 8 secciones en este orden fijo.

`S`, `C`, `R`, `I`, `D`, `E`, `W`, `M`

- **`M` es siempre la última**, aunque tenga longitud 0. La TUI la usa como marcador de fin de snapshot.
- Las secciones de longitud 0 mandan solo header y longitud.
- Los latches viajan en palabras de 32 bits, con relleno de ceros en los bits altos. La TUI decodifica el payload como un entero little-endian y toma los campos por posición de bit (tabla `LATCHES` en `protocol.py`).

## Reglas para la TUI

- **No mandar ningún comando hasta recibir la trama `M`** del snapshot anterior. Si llegara un `p` durante el volcado, el Loader empezaría a borrar la memoria de datos mientras el Serializer la está leyendo.
- Parser con **resincronización**: si aparece un byte que no es un header válido mientras espera uno, lo descarta.

## Tamaño y duración de un snapshot

Con los latches provisorios actuales: 24 B de headers y longitudes, 8 B de `S` y `C`, 128 B de `R` y 60 B de latches, o sea **220 B base** más `4 · mem_used_words`. A 115200 baudios (unos 87 µs por byte) son **~19 ms** la base, y cada palabra de memoria suma ~0,35 ms. Un paso completo tarda unos 20 ms.

Related: [Command Decoder](04-command-decoder.md), [Serializer](07-serializer.md), [TUI](09-tui.md), [Registro de decisiones](10-decisiones.md)

---
title: UART core reutilizado
date: 2026-11-09
tags: [uart, fifo, verilog]
aliases: [UART, FIFO, Uart_Top]
---

# UART core reutilizado

Up: [Índice](INDEX.md)

Se reaprovecha la UART desarrollada en el TP anterior (ALU por UART).

## Qué se reutiliza y qué se reemplaza

| Módulo | Estado | Nota |
|---|---|---|
| `Baud_Rate_Generator.v` | reutilizado | Genera el tick de muestreo |
| `Uart_Rx.v` | reutilizado | Entrega `rx_done` como pulso de 1 ciclo |
| `Uart_Tx.v` | reutilizado | Se dispara con `tx_start` |
| `Fifo.v` (RX y TX) | reutilizado | Ver el comportamiento de abajo |
| `Interface.v` | **reemplazado** | Estaba atado a la ALU (opcode + A + B); lo sustituyen los bloques de la Debug Unit |
| `Uart_Top.v` | **a adaptar** | Hay que reconectar las FIFOs a [Command Decoder](04-command-decoder.md) y [Serializer](07-serializer.md) |

## Comportamiento de la FIFO (importante)

- `i_read` y `i_write` se **muestrean solo en el estado `IDLE`** de su FSM interna. Una lectura o escritura que llega mientras la FIFO está en otro estado se descarta.
- En `IDLE`, si coinciden, la **escritura tiene prioridad** sobre la lectura.
- La lectura toma 2 ciclos: la FSM pasa por `READ`, y `o_done_read` sube un ciclo **después**, con el dato ya estable en `o_data`.

Consecuencias para el diseño:

- El **Byte Fetcher** del Decoder mantiene `o_rx_read` alto hasta ver `done`, y lo baja combinacionalmente en ese ciclo para no disparar una segunda lectura. Ver [Command Decoder](04-command-decoder.md).
- El **Byte Pusher** del Serializer hace lo mismo con la escritura, usando `o_done_write`. Ver [Serializer](07-serializer.md).

## Riesgo conocido: escritura perdida desde `Uart_Rx`

`Uart_Rx` escribe en la FIFO RX con un pulso de un ciclo. Si ese pulso coincide con el estado `READ` de la FIFO (por una lectura del Fetcher), el byte se pierde. A 115200 baudios llega un byte cada ~87 µs y la ventana de colisión es de un ciclo, así que la probabilidad es muy baja pero no nula. Opciones si llegara a verse en la práctica: rediseñar la FIFO para aceptar lectura y escritura simultáneas, o hacer que el lado RX reintente. Ver [pendientes](11-pendientes.md).

## Velocidad (baud rate)

El TP anterior usaba 19200 baudios. Para la Debug Unit se recomienda **115200**, porque un snapshot de ~220 bytes tarda ~100 ms a 19200 y ~19 ms a 115200. El generador calcula el divisor a partir del parámetro `CLK_FREQ_HZ`; conviene **verificar el error de baudios** con la frecuencia real de la placa antes de integrar.

Related: [Command Decoder](04-command-decoder.md), [Serializer](07-serializer.md), [Protocolo UART](02-protocolo-uart.md)

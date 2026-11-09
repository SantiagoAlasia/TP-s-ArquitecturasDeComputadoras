---
title: Debug Unit RISC-V - Índice
date: 2026-11-09
tags: [indice, tp-final, debug-unit]
aliases: [Índice, Home, MOC]
---

# Debug Unit RISC-V - Índice

Documentación de diseño de la **Debug Unit** y la **TUI** del TP Final (pipeline RISC-V, Arquitectura de Computadoras). Reúne las decisiones tomadas, las FSM, las señales y lo que queda pendiente. Se actualiza a medida que avanza el diseño.

## Notas

- [Arquitectura general](01-arquitectura.md): empezar acá; objetivo, bloques y flujos de ejecución.
- [Protocolo UART](02-protocolo-uart.md): comandos, tramas, orden del snapshot; leer antes de tocar el Decoder, el Serializer o la TUI.
- [UART core reutilizado](03-uart-core.md): qué se reaprovechó del TP anterior y las limitaciones de la FIFO.
- [Command Decoder](04-command-decoder.md): FSM de comandos y Byte Fetcher (ya implementado y simulado).
- [Program Loader](05-program-loader.md): carga de la memoria de programa, relleno con HALT y borrado de la memoria de datos.
- [Execution Controller](06-execution-controller.md): modos continuo y paso a paso, drenaje del pipeline, `cpu_en` y `cpu_rst`.
- [Serializer](07-serializer.md): armado del snapshot y Byte Pusher hacia la FIFO TX.
- [Contrato con el CPU](08-contrato-cpu.md): señales a acordar.
- [TUI](09-tui.md): diseño de la interfaz, atajos, paleta y cómo ejecutarla.
- [Registro de decisiones](10-decisiones.md): todas las decisiones con su motivo, y las respuestas a las preguntas del enunciado.
- [Pendientes y riesgos](11-pendientes.md): qué falta hacer y qué hay que revisar.
- [Glosario](12-glosario.md): hwm, ABI, drenaje, snapshot y otros términos.

## Estado actual

| Bloque                   | Diseño      | Verilog / código             | Verificación                                                                       |
| ------------------------ | ----------- | ---------------------------- | ---------------------------------------------------------------------------------- |
| UART core                | reutilizado | del TP anterior              | probado antes                                                                      |
| Command Decoder          | listo       | `Command_Decoder.v`          | simulado (Icarus), 0 errores; falta un ajuste (ver [pendientes](11-pendientes.md)) |
| Program Loader           | listo       | pendiente                    | -                                                                                  |
| Execution Controller     | listo       | pendiente                    | -                                                                                  |
| Serializer + Byte Pusher | listo       | pendiente                    | -                                                                                  |
| Contrato con el CPU      | borrador    | -                            | falta acordar con el pipeline                                                      |
| TUI                      | listo       | `rvdebug/` (Python, Textual) | probada en modo headless, sin FPGA                                                 |

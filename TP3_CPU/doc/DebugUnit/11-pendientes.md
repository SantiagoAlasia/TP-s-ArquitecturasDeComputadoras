---
title: Pendientes y riesgos
date: 2026-11-09
tags: [pendientes, riesgos, todo]
aliases: [TODO, Riesgos]
---

# Pendientes y riesgos

Up: [Índice](INDEX.md)

## Pendientes

### Debug Unit

- [ ] [Command Decoder](04-command-decoder.md): cambiar la condición de N válido a `N <= IMEM_DEPTH - 1`.
- [ ] Verilog del [Program Loader](05-program-loader.md) (dos FSM) y su testbench.
- [ ] Verilog del [Execution Controller](06-execution-controller.md) y su testbench, incluyendo el drenaje.
- [ ] Verilog del [Serializer](07-serializer.md) con el Byte Pusher y su testbench.
- [ ] Adaptar `Uart_Top.v`: conectar las FIFOs a Decoder y Serializer.
- [ ] Decidir si se agregan las respuestas `K` y `N` (hoy opcionales).

### Con el pipeline

- [ ] Acordar el [Contrato con el CPU](08-contrato-cpu.md): señales, orden de campos de los latches, `pc` en cada latch, puertos de debug.
- [ ] Fijar `IMEM_DEPTH` y `DMEM_DEPTH`.
- [ ] Fijar `HALT_WORD` (propuesta: `ebreak`, `0x00100073`) en el CPU, el Loader y el ensamblador.
- [ ] Confirmar que el pipeline hace *squash* después de HALT y que los puertos de lectura funcionan con `cpu_en = 0`.

### TUI

- [ ] Bloquear el envío de comandos hasta recibir la trama `M`.
- [ ] Implementar el ensamblador (`assembler.py`) con soporte de nombres `x` y ABI, y que devuelva el mapa dirección a línea.
- [ ] Ajustar la tabla `LATCHES` cuando el pipeline defina sus latches.
- [ ] Probar con la FPGA real.

### Integración (enunciado)

- [ ] **Camino crítico** del sistema, **skew** y sus consecuencias.
- [ ] Si hay skew: frecuencia óptima de funcionamiento, métricas con las herramientas de Vivado, y aplicarla (por ejemplo con Clock Wizard, sin intervenir el clock en la lógica).
- [ ] Verificar el error de baudios a 115200 con la frecuencia real.
- [ ] Documentar y responder las preguntas del enunciado en el informe final.

## Riesgos conocidos

| Riesgo | Efecto | Mitigación |
|---|---|---|
| Escritura perdida desde `Uart_Rx` cuando coincide con el estado `READ` de la FIFO | Se pierde un byte recibido (probabilidad muy baja) | Rediseñar la FIFO para lectura y escritura simultáneas, o reintento del lado RX. Ver [UART core](03-uart-core.md) |
| `p` durante un volcado | El final del snapshot sale con ceros | La TUI no manda comandos hasta recibir `M` (D33) |
| El pipeline no congela el PC tras HALT | El drenaje ejecuta instrucciones posteriores | Pedirlo en el contrato; el Controller no puede corregirlo |
| `hwm` llevado al tope por el stack | Se pierde el beneficio de volcar solo lo usado | Mapa de bits por palabra. Ver [Registro de decisiones](10-decisiones.md) |
| Direcciones del panel Programa por heurística | Desfase con pseudoinstrucciones | Mapa dirección a línea desde el ensamblador |
| `dump_done` que nunca llega | `WAIT` colgado | Error de integración; no se agregó timeout |
| Latches con ancho cambiante | Parser de la TUI desactualizado | Tabla `LATCHES` configurable (D30) |

## Posibles mejoras futuras

- Comando `x` (reset sin recargar el programa), si resulta incómodo reenviar `p`.
- Volcados durante la ejecución, con el flag `running`.
- Mapa de bits de memoria usada.
- Velocidades de UART mayores (230400) si el paso a paso se siente lento.

Related: [Registro de decisiones](10-decisiones.md), [Contrato con el CPU](08-contrato-cpu.md), [TUI](09-tui.md), [Arquitectura general](01-arquitectura.md)

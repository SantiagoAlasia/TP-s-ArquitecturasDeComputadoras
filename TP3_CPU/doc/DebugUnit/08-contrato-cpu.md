---
title: Contrato con el CPU
date: 2026-11-09
tags: [contrato, cpu, senales, pipeline]
aliases: [Interfaz con el CPU, Señales CPU]
---

# Contrato con el CPU

Up: [Índice](INDEX.md)

Estado: **borrador, a acordar**. Reúne todo lo que la Debug Unit necesita del CPU y lo que se le pide.

## Señales

Vistas desde el CPU.

| Señal | Dir | Para qué | Usa |
|---|---|---|---|
| `cpu_en` | in | Clock enable de todos los registros del pipeline (PC, latches, regfile, memorias). **No se toca el clock** | [Controller](06-execution-controller.md) |
| `cpu_rst` | in | Limpia PC, latches, registros x0 a x31 y el contador de memoria usada | Controller |
| `halt_seen` | out | Nivel que sube cuando HALT está en ID | Controller |
| `imem_we`, `imem_addr`, `imem_data` | in | Puerto de escritura de la memoria de programa | [Loader](05-program-loader.md) |
| `dm_we`, `dm_addr`, `dm_data` | in | Puerto de escritura de la memoria de datos desde la Debug Unit | Loader (`CLEAR`) |
| `rf_addr` / `rf_data` | in / out | Lectura de los 32 registros | [Serializer](07-serializer.md) |
| `dm_addr` / `dm_data` (lectura) | in / out | Lectura de la memoria de datos (latencia de 1 ciclo si es BRAM) | Serializer |
| `latch_if_id`, `latch_id_ex`, `latch_ex_mem`, `latch_mem_wb` | out | Buses planos de cada latch | Serializer |
| `cpu_pc` | out | PC actual | Serializer |
| `mem_used_words` | out | Cantidad de palabras usadas de la memoria de datos (`hwm`) | Serializer |

## Pedidos al pipeline

1. **Después de HALT no se ejecuta nada.** El PC se congela y lo que entra detrás son burbujas que no escriben registros ni memoria. Si el pipeline no hace *squash* de lo que sigue a HALT, el drenaje ejecutaría instrucciones posteriores y el Controller no puede corregirlo.
2. **`cpu_en` apaga todo**, incluidos los write-enable del regfile y de la memoria de datos.
3. **Puertos de lectura de debug** (registros, memoria de datos, latches) que funcionen con `cpu_en = 0`, sin depender de él.
4. **`cpu_rst` síncrono**, que deje en cero PC, latches, registros y el contador de memoria usada.
5. **Cada latch incluye su `pc`**, incluso MEM/WB, aunque el pipeline no lo necesite. Es lo que permite a la TUI marcar en qué etapa está cada instrucción. Son pocos flip-flops.
6. **Orden de los campos en los buses de latch** acordado con la tabla `LATCHES` de `protocol.py`: `pc` en los bits bajos, ancho total y campos.
7. **Mux de puertos de escritura de memoria** con prioridad a la Debug Unit mientras `busy = 1`, para que una escritura pendiente del CPU no ensucie la memoria recién borrada.
8. **Puerto de escritura de la memoria de datos desde la Debug Unit** (nuevo; antes solo se había definido lectura).
9. **`HALT_WORD` única** para el `FILL` del Loader, el decoder del CPU (que activa `halt_seen`) y el ensamblador. Propuesta: `ebreak` (`0x00100073`).
10. **Parámetros de tamaño:** `IMEM_DEPTH` y `DMEM_DEPTH` (aún sin fijar).

## Convención del `hwm`

- `mem_used_words` vale **0** si no hubo ningún store, y `hwm + 1` en palabras en caso contrario. Sin esta convención, `M` no distingue "nada escrito" de "solo se escribió la palabra 0".
- El contador **solo escucha los stores del CPU**, no las escrituras de la Debug Unit. Si no, el `CLEAR` del Loader (que escribe ceros en toda la memoria) lo dejaría en el máximo y se perdería el beneficio.
- Guarda **índice de palabra**, no de byte, para que un `sb` en medio de una palabra no deje una palabra a medias en el volcado.
- Se resetea con `cpu_rst`.

Related: [Execution Controller](06-execution-controller.md), [Serializer](07-serializer.md), [Program Loader](05-program-loader.md), [Pendientes y riesgos](11-pendientes.md)

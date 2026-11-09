---
title: Glosario
date: 2026-11-09
tags: [glosario, terminos]
aliases: [Términos, hwm, ABI]
---

# Glosario

Up: [Índice](INDEX.md)

## hwm (high-water mark)

Registro de la Debug Unit que guarda la **dirección más alta que el programa escribió** en la memoria de datos. Se actualiza en cada `sb`, `sh` o `sw`: si la dirección es mayor que el valor guardado, lo reemplaza; se reinicia con cada `p`. Sirve para volcar solo la memoria de 0 hasta `hwm` en lugar de la memoria entera (con una memoria de 128 palabras donde se tocaron 10, 40 bytes en vez de 512). En el contrato con el CPU aparece como `mem_used_words`. Limitación: si el programa inicializa el stack en el tope de la memoria, el `hwm` salta al final y se pierde el beneficio. Alternativa futura: un bit "sucia" por palabra. Ver [Contrato con el CPU](08-contrato-cpu.md) y [Registro de decisiones](10-decisiones.md).

## ABI (Application Binary Interface)

Conjunto de convenciones que acuerdan compilador, ensamblador y sistema operativo (cómo se pasan argumentos, qué registros se preservan, el stack). En la [TUI](09-tui.md), la tecla `a` alterna entre el nombre de arquitectura (`x0` a `x31`, lo que codifica el hardware) y el nombre ABI (`zero`, `ra`, `sp`...). Son el mismo registro físico. **Solo `x0` es especial por hardware** (vale siempre 0); el resto de los nombres ABI son convención de software.

| Registros | Nombre ABI | Uso convencional |
|---|---|---|
| x0 | `zero` | Siempre 0 |
| x1 | `ra` | Dirección de retorno |
| x2 | `sp` | Stack pointer |
| x3 | `gp` | Global pointer |
| x4 | `tp` | Thread pointer |
| x5 a x7 | `t0` a `t2` | Temporales |
| x8 a x9 | `s0` a `s1` | Guardados (`s0` también es `fp`) |
| x10 a x17 | `a0` a `a7` | Argumentos y retorno |
| x18 a x27 | `s2` a `s11` | Guardados |
| x28 a x31 | `t3` a `t6` | Temporales |

## Snapshot

Foto completa del estado del CPU que se envía a la PC tras cada `c` o `s`: las 8 secciones `S C R I D E W M`. Ver [Protocolo UART](02-protocolo-uart.md) y [Serializer](07-serializer.md).

## Drenaje

Ciclos adicionales que se dejan correr después de detectar HALT, para que el pipeline termine de vaciarse. Ver [Execution Controller](06-execution-controller.md).

## Clock enable (`cpu_en`)

Señal que habilita o congela los registros del pipeline sin tocar el clock. Es la forma de implementar el paso a paso respetando el requisito del enunciado.

## FILL y CLEAR

`FILL`: el Loader escribe HALT en las posiciones de la memoria de programa posteriores al último programa. `CLEAR`: el Loader pone en cero la memoria de datos. Ver [Program Loader](05-program-loader.md).

## HALT_WORD

Palabra de 32 bits que codifica la instrucción de parada. Propuesta: `ebreak`, `0x00100073`. Debe ser la misma en el Loader, el CPU y el ensamblador.

## Byte Fetcher y Byte Pusher

Mini-FSM de dos estados que manejan el handshake con las FIFOs (lectura y escritura respectivamente), manteniendo la señal hasta recibir `done`. Ver [Command Decoder](04-command-decoder.md) y [Serializer](07-serializer.md).

Related: [Registro de decisiones](10-decisiones.md), [Arquitectura general](01-arquitectura.md)

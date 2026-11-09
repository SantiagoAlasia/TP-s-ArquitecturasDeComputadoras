---
title: Registro de decisiones
date: 2026-11-09
tags: [decisiones, enunciado, diseno]
aliases: [Decisiones, Log de decisiones, Respuestas al enunciado]
---

# Registro de decisiones

Up: [Índice](INDEX.md)

El enunciado pide documentar las decisiones y su porqué. Este registro las reúne, agrupadas por tema, junto con las respuestas a las preguntas explícitas del enunciado.

## Respuestas a las preguntas del enunciado

| Pregunta | Respuesta y decisión |
|---|---|
| ¿Es necesario vaciar la memoria de programa? | No entera, pero sí se **rellena con HALT** después del último programa cargado (`FILL`). Así no se ejecutan restos del programa anterior |
| ¿Y los registros? | Sí: `cpu_rst` los deja en 0, para que un programa no herede estado del anterior |
| ¿Se necesita vaciar el pipeline? | Sí: `cpu_rst` limpia PC y latches. Si no, instrucciones del programa anterior terminarían de ejecutarse |
| ¿Y la memoria de datos? | Sí, se **borra** (`CLEAR`) en cada `p`. Garantiza repetibilidad entre ejecuciones (ver D16) |
| ¿Qué pasa si no hay instrucción de parada en la memoria? | Nada grave: el `FILL` deja un HALT justo después del programa. Un bucle infinito, en cambio, solo se corta con `p` |
| ¿Cómo se maneja el clock? | Con **clock enable**, nunca con clock gating (el enunciado prohíbe intervenir el clock) |
| Camino crítico, skew y frecuencia óptima | **Aún no tratado**: es parte de la integración (ver [Pendientes](11-pendientes.md)) |

## Protocolo

| ID | Decisión | Motivo | Alternativas descartadas |
|---|---|---|---|
| D01 | Comandos mínimos: `p`, `c`, `s` | Simplicidad; se pueden ampliar sin romper lo existente | `h`, `x`, `d` (se evaluaron y se postergaron) |
| D02 | `p` siempre válido, incluso con el CPU corriendo | Salida de emergencia ante un bucle infinito, sin necesitar `h` ni `x` | Aceptar `p` solo con el CPU detenido |
| D03 | Comandos en minúscula, headers de respuesta en mayúscula | Un log nunca confunde un comando con un header | Mismo alfabeto para ambos |
| D04 | Tramas `header + len (2 bytes) + payload` | Tolera cambios en el ancho de los latches y permite resincronizar | Longitud implícita por header |
| D05 | Little-endian en todo valor multibyte | Un solo criterio; permite armar palabras con un registro de desplazamiento | Big-endian |
| D06 | `N` en instrucciones (2 bytes), no en bytes | Nunca queda un múltiplo de 4 roto | Contar bytes |
| D07 | `M` siempre es la última sección, aunque vacía | Marcador de fin de snapshot para la TUI | Byte de fin aparte |
| D08 | `K` y `N` son de un solo byte; `K` es opcional | Los bytes llegan en orden, así que la TUI puede mandar `c` justo tras el programa sin esperar ACK | ACK obligatorio |
| D21 | Un `c` o `s` ignorado igual responde con snapshot (`halted = 1`) | La TUI nunca queda esperando y sabe por qué no avanzó, sin comandos nuevos | Ignorar en silencio; enviar `N` |

## Decoder y UART

| ID | Decisión | Motivo | Alternativas descartadas |
|---|---|---|---|
| D09 | Decoder dividido en Byte Fetcher y FSM de comandos | La FSM de comandos queda corta y el handshake con la FIFO no se repite en cada estado | Una sola FSM |
| D10 | `o_rx_read` sostenido hasta `done` | La FIFO solo muestrea `i_read` en `IDLE`; un pulso podía perderse y el `Interface.v` viejo se colgaba | Pulso de un ciclo |
| D11 | Solo el Serializer escribe en la FIFO TX | Evita arbitraje y que una respuesta se intercale en medio de un snapshot | Decoder y Serializer escriben |
| D12 | El Decoder no conoce el estado del CPU | Desacopla bloques; decide el Controller | Entrada `cpu_running` en el Decoder |
| D13 | Timeout de 50 ms entre bytes en un `p`; `nwords <= 0` al abortar | Una pérdida de bytes no cuelga la FSM ni deja un programa a medias ejecutable | Sin timeout |
| D27 | Baud rate recomendado: 115200 | Snapshot de ~19 ms contra ~100 ms a 19200 | Mantener 19200 |

## Loader, Controller y Serializer

| ID | Decisión | Motivo | Alternativas descartadas |
|---|---|---|---|
| D14 | Paso a paso con clock enable (`cpu_en`), nunca con clock gating | Requisito del enunciado | Gating del clock |
| D15 | `FILL` con HALT después del programa (`ebreak`, `0x00100073`) | Resuelve el programa sin parada y los restos de cargas anteriores | Borrar toda la memoria de programa |
| D16 | `CLEAR` de la memoria de datos en cada `p` | Repetibilidad: si no, la primera ejecución funciona y las siguientes fallan por estado residual | No borrar (como una computadora real) |
| D17 | Loader con dos FSM en paralelo (programa y `CLEAR`) | Sin supuestos de temporización sobre cuándo llegan los bytes | `CLEAR` como estado de la FSM principal |
| D18 | Palabra armada con registro de desplazamiento | No hay que decodificar el índice de byte | Escribir byte por byte con máscaras |
| D19 | La Debug Unit es dueña de los puertos de escritura mientras `busy` | Una escritura pendiente del CPU no ensucia la memoria recién borrada | Sin prioridad |
| D20 | Drenaje con `DRAIN = 4` y `halt_lat` propio; el CPU debe congelar el PC tras HALT | El pipeline queda vacío al terminar (exigido); no depende de cómo implemente `halt_seen` el CPU | Detener al detectar HALT |
| D22 | `prog_pending` | Un `cmd_prog` en un estado ocupado se perdería (es un pulso de 1 ciclo) | Ignorarlo |
| D23 | Snapshot en palabras de 32 bits, con relleno de ceros en los latches | Un solo recorrido por palabras; la TUI no se rompe si cambia el ancho | Bytes de ancho variable |
| D24 | Byte Pusher con escritura sostenida hasta `done_write` | Misma razón que D10 | Pulso de escritura |
| D25 | `flags_r` y `used_r` capturados al inicio del snapshot | La longitud de `M` queda fija durante todo el volcado | Leerlos en vivo |

## Memoria de datos usada

| ID | Decisión | Motivo | Alternativas descartadas |
|---|---|---|---|
| D26 | **`hwm`** (dirección más alta escrita) en la v1; guarda índice de palabra; solo cuenta stores del CPU; `mem_used_words = hwm + 1` (0 si no hubo stores) | Pocas líneas de hardware y alcanza para programas simples; con `CLEAR` desaparece el riesgo de ver datos viejos en los huecos | Mapa de bits por palabra: más fiel, pero más lógica; queda como mejora si aparece el stack |

Limitaciones del `hwm`: si el programa inicializa `sp` en el tope de la memoria, el primer store al stack lleva el `hwm` al final y se pierde el beneficio. Ver [Glosario](12-glosario.md).

## TUI

| ID | Decisión | Motivo | Alternativas descartadas |
|---|---|---|---|
| D28 | Textual, una sola pantalla, estilo lazygit, paleta tipo Posting | Paneles con foco, atajos y barra de comandos ya resueltos | `curses`, GUI |
| D29 | Cada latch incluye su `pc` | La TUI marca en qué etapa está cada instrucción | Mostrar solo valores |
| D30 | Campos de los latches en una tabla (`LATCHES`) | Los latches del pipeline van a cambiar; se actualiza una línea | Parser fijo |
| D31 | Ensamblador como punto de enganche; direcciones por heurística | Separa la interfaz del ensamblador | Escribir el ensamblador junto con la TUI |
| D32 | Entorno con `venv`, no Docker | Dos dependencias; el puerto serie en contenedores es incómodo | Docker |
| D33 | La TUI no manda comandos hasta recibir `M` | Evita un `p` durante un volcado (el `CLEAR` pisaría la lectura) | Control de flujo por hardware |

Related: [Arquitectura general](01-arquitectura.md), [Protocolo UART](02-protocolo-uart.md), [Program Loader](05-program-loader.md), [Execution Controller](06-execution-controller.md), [Pendientes y riesgos](11-pendientes.md)

"""
Consola para probar la ALU por UART.

Manda 3 bytes crudos (opcode, A, B) y muestra el byte que responde la placa,
comparandolo con el resultado esperado.

Uso:
    python uart_alu.py [--port COM6] [--baud 19200] [--dry-run]

Comandos (numeros en decimal, 0x.. hex o 0b.. binario, de 0 a 255):
    ADD 5 3
    SUB 0x0A 4
    SRA 0b10000000 2
    RAW 20 05 03      -> manda los bytes tal cual, en hex
    BURST 100 [seed]  -> manda 100 operaciones aleatorias seguidas, sin esperar
                         respuestas, y despues verifica todos los resultados
    PORTS             -> lista los puertos serie
    HELP / EXIT

--dry-run muestra los bytes que se mandarian sin abrir el puerto.
"""

import argparse
import random
import sys
import time

import serial
import serial.tools.list_ports

# Opcodes de ALU_Core (TP1_ALU/ALU_Core.v)
OPCODES = {
    "ADD": 0b100000,
    "SUB": 0b100010,
    "AND": 0b100100,
    "OR":  0b100101,
    "XOR": 0b100110,
    "SRA": 0b000011,
    "SRL": 0b000010,
    "NOR": 0b100111,
}


def parse_byte(text):
    t = text.strip().lower()
    try:
        if t.startswith("0x"):
            value = int(t[2:], 16)
        elif t.startswith("0b"):
            value = int(t[2:], 2)
        else:
            value = int(t, 10)
    except ValueError:
        raise ValueError(f"'{text}' no es un numero valido")
    if not 0 <= value <= 255:
        raise ValueError(f"'{text}' esta fuera de rango (0..255)")
    return value


def expected_result(op, a, b):
    """Replica ALU_Core para saber que deberia contestar la placa."""
    if op == "ADD":
        return (a + b) & 0xFF
    if op == "SUB":
        return (a - b) & 0xFF
    if op == "AND":
        return a & b
    if op == "OR":
        return a | b
    if op == "XOR":
        return a ^ b
    if op == "NOR":
        return ~(a | b) & 0xFF
    if op == "SRL":
        return a >> b
    if op == "SRA":
        signed_a = a - 256 if a & 0x80 else a
        return (signed_a >> b) & 0xFF
    return 0  # opcode desconocido -> la ALU devuelve 0


def fmt(value):
    return f"0x{value:02X}  {value:3d}  {value:08b}"


def list_ports():
    for p in serial.tools.list_ports.comports():
        print(f"  {p.device:6s} {p.description}")


def show_help():
    print()
    print("Operaciones: " + ", ".join(OPCODES))
    print("  <OP> <A> <B>       ej: ADD 5 3   |   XOR 0xF0 0x0F   |   SRL 0b1000 2")
    print("  RAW <b1> <b2> ...  manda bytes en hex tal cual, ej: RAW 20 05 03")
    print("  BURST <N> [seed]   N operaciones aleatorias seguidas, ej: BURST 100")
    print("  PORTS, HELP, EXIT")
    print()


def random_operation(rng):
    op = rng.choice(list(OPCODES))
    a = rng.randrange(256)
    b = rng.randrange(8) if op in ("SRA", "SRL") else rng.randrange(256)
    return op, a, b


def burst(port, count, baud, seed=None):
    """Manda `count` operaciones aleatorias de una sola vez, sin esperar respuestas,
    y despues lee todos los resultados y los compara en orden."""
    rng = random.Random(seed)
    ops = [random_operation(rng) for _ in range(count)]
    expected = [expected_result(op, a, b) for op, a, b in ops]
    frame = bytes(byte for op, a, b in ops for byte in (OPCODES[op], a, b))

    print(f"  Rafaga de {count} operaciones ({len(frame)} bytes), seed={seed}")
    if port is None:
        for i, (op, a, b) in enumerate(ops[:10]):
            print(f"  #{i:<4d} {op:3s} 0x{a:02X} 0x{b:02X} -> esperado 0x{expected[i]:02X}")
        if count > 10:
            print(f"  ... ({count - 10} mas)")
        return

    # Cada byte son 10 bits en la linea; margen x2 + 1 s
    old_timeout = port.timeout
    port.timeout = (len(frame) + count) * 10 / baud * 2 + 1
    try:
        port.reset_input_buffer()
        start = time.perf_counter()
        port.write(frame)
        rx = port.read(count)
        elapsed = time.perf_counter() - start
    finally:
        port.timeout = old_timeout

    mismatches = [i for i, value in enumerate(rx) if value != expected[i]]
    for i in mismatches[:10]:
        op, a, b = ops[i]
        print(f"  #{i:<4d} {op:3s} 0x{a:02X} 0x{b:02X} -> esperado 0x{expected[i]:02X}, recibido 0x{rx[i]:02X}")
    if len(mismatches) > 10:
        print(f"  ... ({len(mismatches) - 10} errores mas)")

    ok = len(rx) == count and not mismatches
    print(f"  Recibidos {len(rx)}/{count}, errores {len(mismatches)}, "
          f"tiempo {elapsed * 1000:.1f} ms ({len(frame) / elapsed:.0f} bytes/s enviados)  "
          + ("OK" if ok else "FALLO"))
    if len(rx) < count:
        print(f"  Faltan {count - len(rx)} respuestas (se perdieron bytes o la placa se trabo)")


def send_frame(port, frame):
    """Manda los bytes y espera 1 byte de respuesta. Devuelve None si hay timeout."""
    print("  TX -> " + " ".join(f"{b:02X}" for b in frame))
    if port is None:
        return None
    port.reset_input_buffer()
    port.write(bytes(frame))
    rx = port.read(1)
    return rx[0] if rx else None


def main():
    parser = argparse.ArgumentParser(description="Prueba de la ALU por UART")
    parser.add_argument("--port", default="COM6")
    parser.add_argument("--baud", type=int, default=19200)
    parser.add_argument("--timeout", type=float, default=1.0, help="segundos a esperar la respuesta")
    parser.add_argument("--dry-run", action="store_true", help="no abre el puerto, solo muestra los bytes")
    args = parser.parse_args()

    port = None
    if args.dry_run:
        print("Modo dry-run: no se abre ningun puerto")
    else:
        try:
            port = serial.Serial(args.port, args.baud, bytesize=8, parity="N", stopbits=1,
                                 timeout=args.timeout, rtscts=False, xonxoff=False)
        except serial.SerialException as e:
            print(f"No se pudo abrir {args.port}: {e}")
            print("Puertos disponibles:")
            list_ports()
            print("Si dice 'Access denied', cerra PuTTY o el Hardware Manager de Vivado.")
            sys.exit(1)
        print(f"Conectado a {args.port} @ {args.baud} 8N1")

    show_help()

    try:
        while True:
            try:
                line = input("alu> ")
            except EOFError:
                break
            parts = line.split()
            if not parts:
                continue
            cmd = parts[0].upper()

            try:
                if cmd in ("EXIT", "QUIT"):
                    break
                elif cmd == "HELP":
                    show_help()
                elif cmd == "PORTS":
                    list_ports()
                elif cmd == "BURST":
                    if len(parts) not in (2, 3):
                        raise ValueError("Uso: BURST <N> [seed]")
                    try:
                        count = int(parts[1])
                        seed = int(parts[2]) if len(parts) == 3 else random.randrange(10000)
                    except ValueError:
                        raise ValueError("Uso: BURST <N> [seed]")
                    if count < 1:
                        raise ValueError("N tiene que ser mayor a 0")
                    burst(port, count, args.baud, seed)
                elif cmd == "RAW":
                    if len(parts) < 2:
                        raise ValueError("RAW necesita al menos un byte")
                    frame = [parse_byte("0x" + p) for p in parts[1:]]
                    rx = send_frame(port, frame)
                    if port is not None:
                        print("  RX <- " + (fmt(rx) if rx is not None else f"(sin respuesta en {args.timeout} s)"))
                elif cmd in OPCODES:
                    if len(parts) != 3:
                        raise ValueError(f"Uso: {cmd} <A> <B>")
                    a, b = parse_byte(parts[1]), parse_byte(parts[2])
                    expected = expected_result(cmd, a, b)

                    rx = send_frame(port, [OPCODES[cmd], a, b])
                    print("  Esperado  " + fmt(expected))
                    if port is None:
                        continue
                    if rx is None:
                        print(f"  RX <- (sin respuesta en {args.timeout} s)")
                    else:
                        print("  Recibido  " + fmt(rx) + ("  OK" if rx == expected else "  DISTINTO"))
                else:
                    raise ValueError(f"Comando desconocido '{parts[0]}'. Escribi HELP.")
            except ValueError as e:
                print(f"  {e}")
    except KeyboardInterrupt:
        print()
    finally:
        if port is not None and port.is_open:
            port.close()


if __name__ == "__main__":
    main()

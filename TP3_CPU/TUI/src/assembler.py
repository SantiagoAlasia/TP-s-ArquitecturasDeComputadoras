"""Punto de enganche del ensamblador.

La TUI llama a assemble(texto_del_asm) y espera una lista de palabras de
32 bits (una por instruccion, en orden de direcciones). Mientras no este
implementado, la TUI muestra el programa pero no lo envia.
"""


class AssemblerError(Exception):
    """Error de sintaxis. Usar el mensaje 'linea N: detalle'."""


def assemble(text: str) -> list[int]:
    raise NotImplementedError("ensamblador sin implementar (assembler.py)")

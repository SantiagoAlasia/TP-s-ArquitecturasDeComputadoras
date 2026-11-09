"""Enlace serie con la FPGA: hilo lector + envio de comandos."""
import threading

from protocol import CMD_PROG, FrameParser


class SerialLink:
    def __init__(self, port, baud, on_frame, on_error):
        self.port, self.baud = port, baud
        self._on_frame, self._on_error = on_frame, on_error
        self._ser = None
        self._thread = None
        self._running = False
        self._parser = FrameParser()

    def open(self):
        import serial  # import tardio: la TUI arranca igual sin pyserial
        self._ser = serial.Serial(self.port, self.baud, timeout=0.05)
        self._running = True
        self._thread = threading.Thread(target=self._reader, daemon=True)
        self._thread.start()

    def close(self):
        self._running = False
        if self._ser:
            self._ser.close()

    def send(self, data: bytes):
        if self._ser is None:
            raise RuntimeError("puerto serie no abierto")
        self._ser.write(data)

    def send_program(self, words: list[int]):
        n = len(words)
        payload = b"".join(w.to_bytes(4, "little") for w in words)
        self.send(CMD_PROG + n.to_bytes(2, "little") + payload)

    def _reader(self):
        while self._running:
            try:
                data = self._ser.read(self._ser.in_waiting or 1)
            except Exception as exc:  # puerto desconectado, etc.
                self._on_error(str(exc))
                return
            for header, payload in self._parser.feed(data):
                self._on_frame(header, payload)

#!/usr/bin/env python3
"""
StemBosque BLE Receiver — Raspberry Pi
=======================================
Servidor BLE con Nordic UART Service (NUS) para recibir archivos .stb
enviados desde StemBosque IDE.

Instalación:
    pip3 install bless

Uso:
    sudo python3 stemBosque_bt_receiver.py
"""

import asyncio
import os
import sys
import signal
import datetime
import logging

# ── Configuración ─────────────────────────────────────────────────────────────
SAVE_DIR    = os.path.expanduser("~/stemBosque_programs")
LOG_FILE    = os.path.expanduser("~/stemBosque_ble_receiver.log")
DEVICE_NAME = "StemBosque"

NUS_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
NUS_TX_CHAR_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  # app → RPi
NUS_RX_CHAR_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  # RPi → app

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_FILE),
    ],
)
log = logging.getLogger("StemBosque-BLE")


def ensure_save_dir():
    os.makedirs(SAVE_DIR, exist_ok=True)


# ── Procesador de protocolo STB ───────────────────────────────────────────────
class StbReceiver:
    """Acumula chunks BLE y detecta el protocolo STB_START / STB_END."""

    def __init__(self):
        self._buf       = b""
        self._file_name = None
        self._expected  = None
        self._receiving = False

    def reset(self):
        self._buf       = b""
        self._file_name = None
        self._expected  = None
        self._receiving = False

    def feed(self, data: bytes):
        """
        Retorna (file_name, content) cuando la transferencia está completa,
        o (None, None) si aún está en progreso.
        """
        self._buf += data

        # Detectar cabecera STB_START
        if not self._receiving:
            nl = self._buf.find(b"\n")
            if nl != -1:
                header = self._buf[:nl].decode("utf-8", errors="replace").strip()
                self._buf = self._buf[nl + 1:]
                if header.startswith("STB_START:"):
                    parts = header.split(":")
                    if len(parts) >= 3:
                        raw_name = parts[1].strip() or "programa.stb"
                        self._file_name = "".join(
                            c for c in os.path.basename(raw_name)
                            if c.isalnum() or c in "._-"
                        ) or "programa.stb"
                        try:
                            self._expected = int(parts[2])
                        except ValueError:
                            self._expected = None
                        self._receiving = True
                        log.info(f"▶ Recibiendo '{self._file_name}' "
                                 f"({self._expected} bytes esperados)...")

        # Detectar fin STB_END
        if self._receiving and b"\nSTB_END\n" in self._buf:
            end_pos       = self._buf.find(b"\nSTB_END\n")
            content_bytes = self._buf[:end_pos]
            # Guardar nombre ANTES de hacer reset
            file_name     = self._file_name or "programa.stb"
            content       = content_bytes.decode("utf-8", errors="replace")
            self.reset()
            return file_name, content

        return None, None


# ── Servidor BLE ──────────────────────────────────────────────────────────────
try:
    from bless import (BlessServer, BlessGATTCharacteristic,
                       GATTCharacteristicProperties, GATTAttributePermissions)
    USE_BLESS = True
except ImportError:
    USE_BLESS = False


async def run_ble_server():
    receiver = StbReceiver()
    trigger  = asyncio.Event()

    # name= hace que bless incluya el nombre en el Advertisement Data
    # para que la app lo vea en el escaneo sin necesidad de conectarse.
    server = BlessServer(name=DEVICE_NAME, loop=asyncio.get_event_loop())
    server.read_request_func = lambda char, **kw: bytearray(b"OK")

    def on_write(characteristic: BlessGATTCharacteristic, value: bytearray, **kw):
        data = bytes(value)
        file_name, content = receiver.feed(data)
        if content is not None:
            save_file(file_name, content)

    server.write_request_func = on_write

    # Registrar servicio NUS
    await server.add_new_service(NUS_SERVICE_UUID)

    # TX (app → RPi): Write + WriteWithoutResponse
    await server.add_new_characteristic(
        NUS_SERVICE_UUID,
        NUS_TX_CHAR_UUID,
        GATTCharacteristicProperties.write |
        GATTCharacteristicProperties.write_without_response,
        None,
        GATTAttributePermissions.writeable,
    )

    # RX (RPi → app): Notify
    await server.add_new_characteristic(
        NUS_SERVICE_UUID,
        NUS_RX_CHAR_UUID,
        GATTCharacteristicProperties.notify,
        None,
        GATTAttributePermissions.readable,
    )

    await server.start()

    log.info("=" * 52)
    log.info(f"  StemBosque BLE Receiver  —  '{DEVICE_NAME}'")
    log.info("=" * 52)
    log.info(f"  Servicio NUS : {NUS_SERVICE_UUID}")
    log.info(f"  TX (escribir): {NUS_TX_CHAR_UUID}")
    log.info(f"  Guardando en : {SAVE_DIR}")
    log.info("  Esperando conexión desde StemBosque IDE...")
    log.info("  Ctrl+C para detener")
    log.info("-" * 52)

    loop = asyncio.get_event_loop()
    loop.add_signal_handler(signal.SIGINT,  lambda: trigger.set())
    loop.add_signal_handler(signal.SIGTERM, lambda: trigger.set())

    await trigger.wait()
    await server.stop()
    log.info("Servidor detenido.")


def save_file(file_name: str, content: str):
    ensure_save_dir()
    base, ext = os.path.splitext(file_name)
    ts   = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    path = os.path.join(SAVE_DIR, f"{base}_{ts}{ext}")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    log.info(f"✓ Guardado: {path}  ({len(content)} caracteres)")


# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if not USE_BLESS:
        print("ERROR: 'bless' no está instalado.")
        print("Ejecuta:  pip3 install bless")
        sys.exit(1)

    ensure_save_dir()
    try:
        asyncio.run(run_ble_server())
    except KeyboardInterrupt:
        log.info("Interrumpido por teclado.")

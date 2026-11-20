"""Tiny HTTP wrapper around BearDetector. Runs on a Docker network with no
internet access and only ever receives images the worker already re-encoded.

  GET  /health   -> {"ok": true, ...}
  POST /detect   -> body is the image bytes; returns detector.Result as JSON
"""
import json
import logging
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from detector import BearDetector

MAX_BYTES = 8 * 1024 * 1024  # re-encoded WebPs are well under this
MODEL_PATH = os.environ.get("MODEL_PATH", "/models/yolox_s.onnx")
THRESHOLD = float(os.environ.get("BEAR_CONFIDENCE_THRESHOLD", "0.85"))
PERSON_THRESHOLD = float(os.environ.get("PERSON_MAX_SCORE", "0.20"))
THREADS = int(os.environ.get("DETECTOR_THREADS", "2"))
# Free the model after this many idle seconds (0 = keep it loaded). Reloading
# takes about a second, which is fine for a site that would rather be slow than hungry.
IDLE_UNLOAD_SECONDS = int(os.environ.get("DETECTOR_IDLE_UNLOAD_SECONDS", "0"))

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("detector")
detector = BearDetector(MODEL_PATH, THRESHOLD, PERSON_THRESHOLD, threads=THREADS)
last_used = time.monotonic()


def unload_when_idle():
    while True:
        time.sleep(max(IDLE_UNLOAD_SECONDS // 4, 5))
        if detector.loaded and time.monotonic() - last_used >= IDLE_UNLOAD_SECONDS:
            detector.unload()
            log.info("model unloaded after %ss idle", IDLE_UNLOAD_SECONDS)


class Handler(BaseHTTPRequestHandler):
    server_version = "bear-detector"

    def do_GET(self):
        if self.path == "/health":
            return self._json(200, {"ok": True, "model": os.path.basename(MODEL_PATH), "threshold": THRESHOLD,
                                    "person_threshold": PERSON_THRESHOLD, "loaded": detector.loaded})
        self._json(404, {"error": "not_found"})

    def do_POST(self):
        if self.path != "/detect":
            return self._json(404, {"error": "not_found"})
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BYTES:
            return self._json(413, {"error": "bad_size"})
        body = self.rfile.read(length)
        global last_used
        last_used = time.monotonic()
        try:
            result = detector.detect(body)
        except Exception:  # unreadable image, never crash the server
            log.exception("detection failed")
            return self._json(422, {"error": "unreadable_image"})
        last_used = time.monotonic()
        log.info("detect %s", result.as_dict())
        self._json(200, result.as_dict())

    def _json(self, status, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):  # requests are logged in do_POST instead
        pass


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    log.info("bear detector listening on :%s (model=%s, bear>=%.2f, person<%.2f, threads=%s, idle unload=%ss)", port,
             MODEL_PATH, THRESHOLD, PERSON_THRESHOLD, THREADS, IDLE_UNLOAD_SECONDS)
    if IDLE_UNLOAD_SECONDS > 0:
        threading.Thread(target=unload_when_idle, daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()

"""Minimal local-only lab webhook receiver; logs payloads and shows recent events."""
import json
import os
from collections import deque
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

received = deque(maxlen=100)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/alerts":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length < 1 or length > 1_000_000:
            self.send_error(413)
            return
        try:
            payload = json.loads(self.rfile.read(length))
        except (ValueError, UnicodeDecodeError):
            self.send_error(400)
            return
        event = {"received_at": datetime.now(timezone.utc).isoformat(), "payload": payload}
        received.appendleft(event)
        print(json.dumps(event, ensure_ascii=False), flush=True)
        self._respond(200, {"ok": True})

    def do_GET(self):
        if self.path not in ("/", "/alerts"):
            self.send_error(404)
            return
        self._respond(200, {"received": list(received)})

    def _respond(self, code, obj):
        body = json.dumps(obj, indent=2, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.environ.get("ECHO_PORT", "8080"))
    print(f"Alert echo listening on port {port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()

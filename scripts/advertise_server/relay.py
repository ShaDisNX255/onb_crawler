#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.request
import urllib.error

UPSTREAM = "https://onb.keristero.com/server_list/"
HOST = "127.0.0.1"
PORT = 5055

class RelayHandler(BaseHTTPRequestHandler):
    def forward(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length) if length > 0 else None

        headers = {
            "Content-Type": self.headers.get("Content-Type", "application/json"),
            "User-Agent": "WCityOnline-ad-relay/1.0",
        }

        try:
            req = urllib.request.Request(
                UPSTREAM,
                data=body,
                headers=headers,
                method=self.command,
            )

            with urllib.request.urlopen(req, timeout=20) as resp:
                data = resp.read()

                self.send_response(resp.status)

                for key, value in resp.headers.items():
                    lower = key.lower()
                    if lower in ("connection", "transfer-encoding", "content-encoding"):
                        continue
                    self.send_header(key, value)

                self.end_headers()

                if self.command != "HEAD":
                    self.wfile.write(data)

                print(f"[ad-relay] {self.command} {self.path} -> {resp.status}", flush=True)

        except Exception as e:
            message = f"relay error: {e}\n".encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(message)))
            self.end_headers()
            self.wfile.write(message)
            print(f"[ad-relay] ERROR: {e}", flush=True)

    def do_GET(self):
        self.forward()

    def do_HEAD(self):
        self.forward()

    def do_POST(self):
        self.forward()

if __name__ == "__main__":
    print(f"[ad-relay] listening on http://{HOST}:{PORT}/ -> {UPSTREAM}", flush=True)
    HTTPServer((HOST, PORT), RelayHandler).serve_forever()

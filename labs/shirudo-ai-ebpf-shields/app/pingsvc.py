#!/usr/bin/env python3
# Deliberately vulnerable "network diagnostics" service: command injection via ?host=
# (the classic subprocess shell=True bug). Lab only, binds to 127.0.0.1.
import ctypes, http.server, subprocess, urllib.parse

ctypes.CDLL(None).prctl(15, b"pingsvc", 0, 0, 0)   # PR_SET_NAME: comm = "pingsvc"

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        host = qs.get("host", ["127.0.0.1"])[0]
        r = subprocess.run(f"ping -c1 -W1 {host}", shell=True, capture_output=True, text=True)
        body = (r.stdout + r.stderr).encode()
        self.send_response(200)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

http.server.ThreadingHTTPServer(("127.0.0.1", 8080), Handler).serve_forever()

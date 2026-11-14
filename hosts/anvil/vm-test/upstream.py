"""A stand-in for the services behind the credentials proxy in ./../vm-test.nix
(GitLab, Kagi, Grafana's Loki), which answers each request with the
credentials it came with, and logs them.

    python3 upstream.py <address> <port>
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        seen = {
            "path": self.path,
            "private-token": self.headers.get("PRIVATE-TOKEN"),
            "authorization": self.headers.get("Authorization"),
        }
        print(json.dumps(seen), flush=True)
        body = json.dumps(seen).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    do_POST = do_PUT = do_GET

    def log_message(self, *args):
        pass


ThreadingHTTPServer((sys.argv[1], int(sys.argv[2])), Handler).serve_forever()

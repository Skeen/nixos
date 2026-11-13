"""A GitLab for ./../vm-test.nix, which only tells whether requests came with
the credentials it is given: the API token, and the basic authentication git
uses. It answers each request with that, and logs it.

    python3 gitlab.py <address> <port> <token> <basic>
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ADDRESS, PORT, TOKEN, BASIC = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        seen = {
            "path": self.path,
            "token": self.headers.get("PRIVATE-TOKEN") == TOKEN,
            "basic": self.headers.get("Authorization") == f"Basic {BASIC}",
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


ThreadingHTTPServer((ADDRESS, PORT), Handler).serve_forever()

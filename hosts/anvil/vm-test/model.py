"""A model provider for ./../vm-test.nix: an OpenAI compatible API, scripted.

Answers requests carrying the API key it is given, others with 401:

- a message with a line `RUN: <command>` in it with a call of the shell tool,
  running the command;
- the result of a tool with `RESULT: <the result>`;
- anything else with `ECHO: <its last line>`.

    python3 model.py <address> <port> <API key>
"""

import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ADDRESS, PORT, KEY = sys.argv[1], int(sys.argv[2]), sys.argv[3]


def text(message):
    content = message.get("content") or ""
    if isinstance(content, list):
        return "\n".join(part.get("text", "") for part in content if isinstance(part, dict))
    return content


def answer(request):
    last = (request.get("messages") or [{}])[-1]
    if last.get("role") == "tool":
        return {"content": f"RESULT: {text(last).strip()}"}
    lines = [line for line in text(last).splitlines() if line.strip()]
    tools = [tool["function"]["name"] for tool in request.get("tools", [])]
    for line in lines:
        if line.startswith("RUN: ") and "shell" in tools:
            command = line.removeprefix("RUN: ")
            return {"tool": "shell", "arguments": {"command": command, "description": f"Run {command}"}}
    return {"content": f"ECHO: {lines[-1] if lines else ''}"}


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.reply(200, json.dumps({"object": "list", "data": [{"id": "fake", "object": "model"}]}).encode())

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        authorized = self.headers.get("Authorization") == f"Bearer {KEY}"
        last = text((request.get("messages") or [{}])[-1])
        print(f"{self.path} authorized={authorized} last={last[-200:]!r}", flush=True)
        if not authorized:
            self.reply(401, b'{"error": {"message": "invalid API key"}}')
            return
        reply = answer(request)
        if "tool" in reply:
            call = {"id": f"call_{time.time_ns()}", "type": "function",
                    "function": {"name": reply["tool"], "arguments": json.dumps(reply["arguments"])}}
            delta, message, finish = {"role": "assistant", "tool_calls": [{"index": 0, **call}]}, {"role": "assistant", "content": None, "tool_calls": [call]}, "tool_calls"
        else:
            delta = message = {"role": "assistant", "content": reply["content"]}
            finish = "stop"
        base = {"id": "fake", "created": int(time.time()), "model": request.get("model")}
        usage = {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        if not request.get("stream"):
            body = {**base, "object": "chat.completion", "choices": [{"index": 0, "message": message, "finish_reason": finish}], "usage": usage}
            self.reply(200, json.dumps(body).encode())
            return
        chunks = [
            {"choices": [{"index": 0, "delta": delta, "finish_reason": None}]},
            {"choices": [{"index": 0, "delta": {}, "finish_reason": finish}]},
            {"choices": [], "usage": usage},
        ]
        self.reply(200, b"".join(f"data: {json.dumps({**base, 'object': 'chat.completion.chunk', **chunk})}\n\n".encode() for chunk in chunks) + b"data: [DONE]\n\n", "text/event-stream")

    def log_message(self, *args):
        pass


ThreadingHTTPServer((ADDRESS, PORT), Handler).serve_forever()

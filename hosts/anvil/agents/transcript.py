"""Prints what the agent in a sandbox does, as it does it, to the pod's log.

Follows the events of the opencode server next to it: the messages the agent
is given, what it thinks and replies, and the tools it runs, with what they
return.

https://opencode.ai/docs/api/
"""

import base64
import json
import os
import time
import urllib.request

EVENTS = "http://127.0.0.1:4096/api/event"
# Lines of what a tool returns to show, and characters of what it is given
OUTPUT_LINES = 20
INPUT_CHARACTERS = 500


def events():
    """The events of the server, until it goes away."""
    password = os.environ["OPENCODE_SERVER_PASSWORD"].strip()
    token = base64.b64encode(f"opencode:{password}".encode()).decode()
    request = urllib.request.Request(EVENTS, headers={"Authorization": f"Basic {token}"})
    with urllib.request.urlopen(request) as stream:
        data = []
        for line in stream:
            line = line.decode().rstrip("\r\n")
            if line.startswith("data:"):
                data.append(line.removeprefix("data:").removeprefix(" "))
            elif not line and data:
                yield json.loads("\n".join(data))
                data = []


def show(heading=None, text="", limit=None, indent=""):
    lines = text.rstrip().splitlines()
    if limit is not None and len(lines) > limit:
        lines = lines[:limit] + [f"... ({len(lines) - limit} more lines)"]
    lines = [indent + line for line in lines]
    if heading is not None:
        lines.insert(0, heading)
    if lines:
        print("\n".join(lines), flush=True)


def shorten(text, characters=INPUT_CHARACTERS):
    return text if len(text) <= characters else text[:characters] + "..."


def main():
    tools = {}  # names of tool calls, by their id
    session = None
    while True:
        try:
            for event in events():
                kind, data = event.get("type"), event.get("data") or {}
                if kind == "server.connected":
                    show("--- connected to opencode")
                    continue
                if not kind.startswith("session.") or "sessionID" not in data:
                    continue
                if data["sessionID"] != session:
                    session = data["sessionID"]
                    show(f"=== session {session}")
                if kind == "session.inbox.enqueued" and data["item"]["type"] == "user":
                    show(">>> message", data["item"]["payload"]["text"])
                elif kind == "session.reasoning.ended":
                    show("... thinking", data.get("text", ""), indent="  ")
                elif kind == "session.text.ended":
                    show("<<< reply", data.get("text", ""))
                elif kind == "session.tool.input.started":
                    tools[data["id"]] = data.get("name", "tool")
                elif kind == "session.tool.called":
                    name, given = tools.get(data["id"], "tool"), data.get("input") or {}
                    if name == "shell" and "command" in given:
                        show(f"$ {given['command']}")
                    else:
                        show(f"[{name}] {shorten(json.dumps(given))}")
                elif kind == "session.tool.success":
                    output = "\n".join(part.get("text", "") for part in data.get("content", []))
                    show(text=output, limit=OUTPUT_LINES, indent="  | ")
                elif kind == "session.tool.failed":
                    show(f"  ! failed: {shorten(json.dumps(data.get('error', data)))}")
                elif kind == "session.retry.scheduled":
                    show(f"... retrying: {shorten(json.dumps(data))}")
                elif kind == "session.compaction.started":
                    show("... compacting the conversation")
                elif kind in ("session.execution.succeeded", "session.execution.failed", "session.execution.interrupted"):
                    error = data.get("error")
                    show(f"=== {kind.rsplit('.', 1)[1]}" + (f": {shorten(json.dumps(error))}" if error else ""))
        except (OSError, ValueError):
            # Not started yet, or restarting
            time.sleep(1)


if __name__ == "__main__":
    main()

"""A minimal MCP server over stdio, with no dependencies.

Tools are plain Python functions registered with @tool. Each message is one
line of JSON-RPC. Only what Claude Code and Codex need is implemented:
initialize, tools/list and tools/call.
"""
import json
import sys
import traceback

PROTOCOL_VERSION = "2025-06-18"
_tools = {}


def tool(name, description, params):
    """Register a function as a tool. `params` maps argument name to (json type, description)."""
    def wrap(fn):
        _tools[name] = {
            "fn": fn,
            "spec": {
                "name": name,
                "description": description,
                "inputSchema": {
                    "type": "object",
                    "properties": {k: {"type": t, "description": d} for k, (t, d) in params.items()},
                    "required": list(params),
                },
            },
        }
        return fn
    return wrap


def _reply(msg_id, result=None, error=None):
    out = {"jsonrpc": "2.0", "id": msg_id}
    if error is not None:
        out["error"] = error
    else:
        out["result"] = result
    sys.stdout.write(json.dumps(out) + "\n")
    sys.stdout.flush()


def serve(server_name="lab"):
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        msg = json.loads(line)
        method, msg_id = msg.get("method"), msg.get("id")
        if msg_id is None:
            continue  # notifications need no answer
        if method == "initialize":
            _reply(msg_id, {
                "protocolVersion": msg.get("params", {}).get("protocolVersion", PROTOCOL_VERSION),
                "capabilities": {"tools": {}},
                "serverInfo": {"name": server_name, "version": "0.1"},
            })
        elif method == "tools/list":
            _reply(msg_id, {"tools": [t["spec"] for t in _tools.values()]})
        elif method == "tools/call":
            p = msg.get("params", {})
            t = _tools.get(p.get("name"))
            if t is None:
                _reply(msg_id, error={"code": -32602, "message": f"unknown tool {p.get('name')}"})
                continue
            try:
                text = t["fn"](**(p.get("arguments") or {}))
                _reply(msg_id, {"content": [{"type": "text", "text": str(text)}], "isError": False})
            except Exception as e:  # the agent sees the error and can try something else
                _reply(msg_id, {"content": [{"type": "text", "text": f"error: {e}"}], "isError": True})
                traceback.print_exc(file=sys.stderr)
        elif method == "ping":
            _reply(msg_id, {})
        else:
            _reply(msg_id, error={"code": -32601, "message": f"method not found: {method}"})

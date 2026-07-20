"""Trigger Flutter hot restart via VM service WebSocket."""
import asyncio
import json
import sys

import websockets

WS = sys.argv[1] if len(sys.argv) > 1 else ""


async def rpc(ws, method, params=None, req_id=1):
    msg = {"jsonrpc": "2.0", "id": req_id, "method": method}
    if params is not None:
        msg["params"] = params
    await ws.send(json.dumps(msg))
    while True:
        raw = await asyncio.wait_for(ws.recv(), timeout=10)
        resp = json.loads(raw)
        if resp.get("id") == req_id:
            return resp


async def main():
    print("connecting", WS)
    async with websockets.connect(WS, open_timeout=8, close_timeout=3) as ws:
        vm = await rpc(ws, "getVM")
        isolates = vm["result"]["isolates"]
        isolate = isolates[0]["id"]
        for i in isolates:
            name = i.get("name", "")
            print(" found isolate", name, i["id"])
            if "main" in name.lower():
                isolate = i["id"]
        print("using", isolate)

        # List extensions
        iso = await rpc(ws, "getIsolate", {"isolateId": isolate}, 2)
        exts = iso.get("result", {}).get("extensionRPCs") or []
        print("extensions sample", [e for e in exts if "flutter" in e or "hot" in e][:20])

        for method, params, rid in [
            ("ext.flutter.hotRestart", {"isolateId": isolate}, 10),
            ("ext.ui.window.scheduleFrame", {"isolateId": isolate}, 11),
            ("ext.flutter.reassemble", {"isolateId": isolate}, 12),
        ]:
            if method.startswith("ext.") and method not in exts and method != "ext.flutter.reassemble":
                # still try reassemble even if listing incomplete
                pass
            r = await rpc(ws, method, params, rid)
            print(method, "=>", r.get("result") or r.get("error"))
            if method == "ext.flutter.hotRestart" and "error" not in r:
                print("HOT_RESTART_OK")
                return
            if method == "ext.flutter.reassemble" and "error" not in r:
                print("HOT_RELOAD_OK")
                return


if __name__ == "__main__":
    asyncio.run(main())

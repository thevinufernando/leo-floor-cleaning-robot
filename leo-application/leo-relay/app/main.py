"""Leo relay HTTP + WebSocket entrypoint."""

from __future__ import annotations

import base64
import io
import json
import logging
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from app.config import settings
from app.protocol import (
    ROLE_PHONE,
    ROLE_ROBOT,
    TYPE_ERROR,
    TYPE_HELLO,
    TYPE_MAP,
    TYPE_PING,
    TYPE_PONG,
    TYPE_SET_ARMED,
    TYPE_STATUS,
    TYPE_WELCOME,
)
from app.rooms import rooms

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("leo_relay")

app = FastAPI(title="Leo Relay", version="0.1.0")


def _error(message: str) -> dict[str, Any]:
    return {"type": TYPE_ERROR, "message": message}


def _mock_map_payload() -> dict[str, Any]:
    """Tiny synthetic occupancy PNG for UI testing without a robot."""
    try:
        from PIL import Image
    except ImportError:
        # 1x1 gray PNG
        png = base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        )
        return {
            "type": TYPE_MAP,
            "width": 1,
            "height": 1,
            "resolution": 0.05,
            "origin": {"x": 0.0, "y": 0.0, "yaw": 0.0},
            "png_base64": base64.b64encode(png).decode("ascii"),
            "stamp": 0.0,
        }

    w, h = 80, 60
    img = Image.new("L", (w, h), color=205)
    pixels = img.load()
    assert pixels is not None
    for x in range(w):
        pixels[x, 0] = 0
        pixels[x, h - 1] = 0
    for y in range(h):
        pixels[0, y] = 0
        pixels[w - 1, y] = 0
    for x in range(20, 60):
        for y in range(20, 40):
            pixels[x, y] = 254
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return {
        "type": TYPE_MAP,
        "width": w,
        "height": h,
        "resolution": 0.05,
        "origin": {"x": -2.0, "y": -1.5, "yaw": 0.0},
        "png_base64": base64.b64encode(buf.getvalue()).decode("ascii"),
        "stamp": 0.0,
    }


@app.get("/health")
async def health() -> JSONResponse:
    return JSONResponse({"ok": True, "service": "leo-relay"})


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await websocket.accept()
    role: str | None = None
    robot_id: str | None = None

    try:
        raw = await websocket.receive_text()
        try:
            hello = json.loads(raw)
        except json.JSONDecodeError:
            await websocket.send_text(json.dumps(_error("invalid json")))
            await websocket.close(code=4001)
            return

        if hello.get("type") != TYPE_HELLO:
            await websocket.send_text(json.dumps(_error("first message must be hello")))
            await websocket.close(code=4001)
            return

        token = hello.get("token", "")
        if token != settings.leo_relay_token:
            await websocket.send_text(json.dumps(_error("unauthorized")))
            await websocket.close(code=4003)
            return

        role = hello.get("role")
        robot_id = hello.get("robotId") or hello.get("robot_id") or "LEO_001"
        if role not in (ROLE_PHONE, ROLE_ROBOT):
            await websocket.send_text(json.dumps(_error("role must be phone or robot")))
            await websocket.close(code=4001)
            return

        if role == ROLE_ROBOT:
            room = await rooms.attach_robot(robot_id, websocket)
            # Notify phones already in the room immediately (don't wait for status tick).
            presence = {
                "type": TYPE_STATUS,
                "robotOnline": True,
                "connected": True,
            }
            if room.last_status:
                # Preserve last armed bit if we have it.
                if "armed" in room.last_status:
                    presence["armed"] = room.last_status["armed"]
                else:
                    presence["armed"] = False
            else:
                presence["armed"] = False
            room.last_status = {**(room.last_status or {}), **presence}
            await room.broadcast_phones(presence)
            logger.info("robot presence online robot_id=%s phones=%d", robot_id, len(room.phones))
        else:
            room = await rooms.attach_phone(robot_id, websocket)

        await websocket.send_text(
            json.dumps(
                {
                    "type": TYPE_WELCOME,
                    "role": role,
                    "robotId": robot_id,
                    "robotOnline": room.robot is not None,
                    "phoneCount": len(room.phones),
                }
            )
        )

        # Catch phones up with last known state from robot.
        if role == ROLE_PHONE:
            if room.last_status:
                await room.send_json(websocket, room.last_status)
            elif settings.mock_map:
                await room.send_json(
                    websocket,
                    {
                        "type": TYPE_STATUS,
                        "armed": False,
                        "connected": False,
                        "mock": True,
                    },
                )
            if room.last_map:
                await room.send_json(websocket, room.last_map)
            elif settings.mock_map:
                await room.send_json(websocket, _mock_map_payload())

        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_text(json.dumps(_error("invalid json")))
                continue

            msg_type = msg.get("type")

            if msg_type == TYPE_PING:
                await websocket.send_text(json.dumps({"type": TYPE_PONG}))
                continue

            if role == ROLE_PHONE and msg_type == TYPE_SET_ARMED:
                armed = bool(msg.get("armed", False))
                forwarded = {
                    "type": TYPE_SET_ARMED,
                    "armed": armed,
                }
                ok = await room.send_robot(forwarded)
                if not ok:
                    await websocket.send_text(
                        json.dumps(_error("robot offline; command not delivered"))
                    )
                    # Demo-friendly: still echo status so UI can flip when mock.
                    if settings.mock_map:
                        status = {
                            "type": TYPE_STATUS,
                            "armed": armed,
                            "connected": False,
                            "mock": True,
                        }
                        room.last_status = status
                        await room.broadcast_phones(status)
                continue

            if role == ROLE_ROBOT and msg_type == TYPE_STATUS:
                room.last_status = msg
                await room.broadcast_phones(msg)
                continue

            if role == ROLE_ROBOT and msg_type == TYPE_MAP:
                room.last_map = msg
                await room.broadcast_phones(msg)
                continue

            await websocket.send_text(
                json.dumps(_error(f"unsupported type for role {role}: {msg_type}"))
            )

    except WebSocketDisconnect:
        logger.info("disconnect role=%s robot_id=%s", role, robot_id)
    except Exception:
        logger.exception("websocket error role=%s robot_id=%s", role, robot_id)
    finally:
        if role and robot_id:
            await rooms.detach(robot_id, websocket, role)
            if role == ROLE_ROBOT:
                room = await rooms.get_or_create(robot_id)
                await room.broadcast_phones(
                    {
                        "type": TYPE_STATUS,
                        "armed": False,
                        "connected": False,
                        "robotOnline": False,
                    }
                )

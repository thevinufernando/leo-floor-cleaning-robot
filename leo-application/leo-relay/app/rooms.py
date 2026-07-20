"""In-memory robot rooms: one robot socket + many phone sockets."""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass, field
from typing import Any

from fastapi import WebSocket

logger = logging.getLogger("leo_relay.rooms")


@dataclass
class Room:
    robot_id: str
    robot: WebSocket | None = None
    phones: set[WebSocket] = field(default_factory=set)
    last_status: dict[str, Any] | None = None
    last_map: dict[str, Any] | None = None
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def send_json(self, ws: WebSocket, payload: dict[str, Any]) -> None:
        await ws.send_text(json.dumps(payload))

    async def broadcast_phones(self, payload: dict[str, Any]) -> None:
        dead: list[WebSocket] = []
        text = json.dumps(payload)
        for phone in list(self.phones):
            try:
                await phone.send_text(text)
            except Exception:
                dead.append(phone)
        for phone in dead:
            self.phones.discard(phone)

    async def send_robot(self, payload: dict[str, Any]) -> bool:
        if self.robot is None:
            return False
        try:
            await self.robot.send_text(json.dumps(payload))
            return True
        except Exception:
            self.robot = None
            return False


class RoomManager:
    def __init__(self) -> None:
        self._rooms: dict[str, Room] = {}
        self._lock = asyncio.Lock()

    async def get_or_create(self, robot_id: str) -> Room:
        async with self._lock:
            if robot_id not in self._rooms:
                self._rooms[robot_id] = Room(robot_id=robot_id)
            return self._rooms[robot_id]

    async def attach_robot(self, robot_id: str, ws: WebSocket) -> Room:
        room = await self.get_or_create(robot_id)
        async with room.lock:
            if room.robot is not None and room.robot is not ws:
                try:
                    await room.robot.close(code=4000, reason="replaced")
                except Exception:
                    pass
            room.robot = ws
        logger.info("robot attached robot_id=%s", robot_id)
        return room

    async def attach_phone(self, robot_id: str, ws: WebSocket) -> Room:
        room = await self.get_or_create(robot_id)
        async with room.lock:
            room.phones.add(ws)
        logger.info(
            "phone attached robot_id=%s phones=%d",
            robot_id,
            len(room.phones),
        )
        return room

    async def detach(self, robot_id: str, ws: WebSocket, role: str) -> None:
        room = await self.get_or_create(robot_id)
        async with room.lock:
            if role == "robot" and room.robot is ws:
                room.robot = None
                logger.info("robot detached robot_id=%s", robot_id)
            elif role == "phone":
                room.phones.discard(ws)
                logger.info(
                    "phone detached robot_id=%s phones=%d",
                    robot_id,
                    len(room.phones),
                )


rooms = RoomManager()

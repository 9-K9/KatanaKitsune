#!/usr/bin/env python3
"""Small, account-free allocator for the fixed KatanaKitsune room pool."""

from __future__ import annotations

import json
import os
import random
import re
import string
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = os.environ.get("KK_PUBLIC_HOST", "play.9-k9.io")
ROOM_COUNT = int(os.environ.get("KK_ROOM_COUNT", "12"))
EMPTY_TTL = int(os.environ.get("KK_EMPTY_TTL", "900"))
STATE_DIR = Path("/var/lib/katanakitsune-lobby")
STATE_FILE = STATE_DIR / "rooms.json"
LOCK = threading.RLock()
CODE_RE = re.compile(r"^[A-Z2-9]{6}$")


def _load() -> dict[str, dict]:
    try:
        raw = json.loads(STATE_FILE.read_text())
        return raw if isinstance(raw, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


ROOMS = _load()


def _save() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    temp = STATE_FILE.with_suffix(".tmp")
    temp.write_text(json.dumps(ROOMS, sort_keys=True))
    temp.replace(STATE_FILE)


def _connections(slot: int) -> int:
    port = 8910 + slot
    result = subprocess.run(
        ["ss", "-Htn", "state", "established", "sport", "=", f":{port}"],
        check=False, capture_output=True, text=True, timeout=3,
    )
    return sum(1 for line in result.stdout.splitlines() if line.strip())


def _unit(slot: int, verb: str) -> None:
    subprocess.run(
        ["systemctl", verb, f"katanakitsune-room@{slot}.service"],
        check=True, timeout=15,
    )


def _reap() -> None:
    now = time.time()
    changed = False
    for code, room in list(ROOMS.items()):
        slot = int(room["slot"])
        players = _connections(slot)
        if players:
            room["last_active"] = now
            changed = True
        elif now - float(room.get("last_active", room["created"])) > EMPTY_TTL:
            _unit(slot, "stop")
            del ROOMS[code]
            changed = True
    if changed:
        _save()


def _new_code() -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    while True:
        code = "".join(random.SystemRandom().choice(alphabet) for _ in range(6))
        if code not in ROOMS:
            return code


def _reaper_loop() -> None:
    while True:
        time.sleep(30)
        try:
            with LOCK:
                _reap()
        except Exception as error:  # Keep allocation available after a transient ss/systemd error.
            print("lobby: reaper error:", error, flush=True)


def _public(room: dict, code: str) -> dict:
    slot = int(room["slot"])
    return {
        "code": code,
        "address": f"{HOST}:443/rooms/r{slot:02d}",
        "players": min(4, _connections(slot)),
        "capacity": 4,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "KatanaLobby/1"

    def _json(self, status: int, body: dict) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        with LOCK:
            _reap()
            if self.path in ("/health", "/api/rooms/health"):
                self._json(200, {"ok": True, "rooms": len(ROOMS), "capacity": ROOM_COUNT})
                return
            prefix = "/api/rooms/"
            if self.path.startswith(prefix):
                code = self.path[len(prefix):].split("?", 1)[0].upper()
                room = ROOMS.get(code) if CODE_RE.fullmatch(code) else None
                if room is None:
                    self._json(404, {"error": "Room not found or expired"})
                    return
                room["last_active"] = time.time()
                _save()
                self._json(200, _public(room, code))
                return
            self._json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if self.path != "/api/rooms":
            self._json(404, {"error": "Not found"})
            return
        with LOCK:
            _reap()
            occupied = {int(room["slot"]) for room in ROOMS.values()}
            slot = next((number for number in range(1, ROOM_COUNT + 1)
                         if number not in occupied), None)
            if slot is None:
                self._json(503, {"error": "All rooms are busy; try again shortly"})
                return
            code = _new_code()
            now = time.time()
            ROOMS[code] = {"slot": slot, "created": now, "last_active": now}
            try:
                _unit(slot, "start")
            except subprocess.SubprocessError:
                del ROOMS[code]
                self._json(503, {"error": "Could not start a room"})
                return
            _save()
            self._json(201, _public(ROOMS[code], code))

    def log_message(self, fmt: str, *args: object) -> None:
        print("lobby:", fmt % args, flush=True)


if __name__ == "__main__":
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    threading.Thread(target=_reaper_loop, daemon=True).start()
    ThreadingHTTPServer(("127.0.0.1", 8909), Handler).serve_forever()

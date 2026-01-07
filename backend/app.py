"""Pomodoro backend bridge.

This module preserves existing timer logic by acting as a thin IPC wrapper.
The Tkinter UI remains untouched in history/, while this file defines the
migration boundary for the new Tauri frontend.
"""
from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass, asdict
from datetime import date
from typing import Any, Dict


DATA_FILE = os.path.join(os.path.dirname(__file__), "pomodoro_data.json")

# NOTE: Kept in sync with the existing UI presets. This is a temporary copy
# until the UI and backend share a single source of truth.
SESSION_PRESETS: Dict[str, Dict[str, int] | None] = {
    "Classic 25/5": {"work": 25, "break": 5, "long_break": 15, "interval": 4},
    "Quick 15/3": {"work": 15, "break": 3, "long_break": 10, "interval": 4},
    "Deep 50/10": {"work": 50, "break": 10, "long_break": 20, "interval": 3},
    "Gentle 20/5": {"work": 20, "break": 5, "long_break": 15, "interval": 4},
    "Custom": None,
}


@dataclass
class TimerState:
    """In-memory state for IPC responses.

    TODO: Replace with the existing PomodoroApp countdown logic once the
    migration is ready to wire the UI-less core into this bridge.
    """

    work_seconds: int = 25 * 60
    break_seconds: int = 5 * 60
    long_break_seconds: int = 15 * 60
    long_break_interval: int = 4
    remaining_seconds: int = 25 * 60
    running: bool = False
    is_break: bool = False
    break_kind: str = "short"
    cycle_progress: int = 0


class PomodoroBackend:
    """JSON IPC bridge for the Tauri frontend.

    The backend accepts one JSON object per line on stdin and returns a JSON
    response per line on stdout. Calls are stateless at the transport layer
    (no persistent sockets); state is maintained in-memory until the process
    exits.
    """

    def __init__(self) -> None:
        self.state = TimerState()
        self.stats = self._load_stats()

    def _load_stats(self) -> Dict[str, Any]:
        today = date.today().isoformat()
        defaults = {
            "date": today,
            "count": 0,
            "short_breaks": 0,
            "long_breaks": 0,
            "focus_seconds": 0,
            "break_seconds": 0,
        }
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE, "r", encoding="utf-8") as handle:
                    data = json.load(handle)
            except Exception:
                data = defaults.copy()
        else:
            data = defaults.copy()

        if data.get("date") != today:
            data = defaults.copy()

        return data

    def _save_stats(self) -> None:
        with open(DATA_FILE, "w", encoding="utf-8") as handle:
            json.dump(self.stats, handle)

    def _set_preset(self, preset_name: str) -> None:
        preset = SESSION_PRESETS.get(preset_name)
        if not preset:
            return
        self.state.work_seconds = preset["work"] * 60
        self.state.break_seconds = preset["break"] * 60
        self.state.long_break_seconds = preset["long_break"] * 60
        self.state.long_break_interval = preset["interval"]
        self.state.remaining_seconds = self.state.work_seconds

    def handle(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        action = payload.get("action")
        if action == "start_timer":
            if self.state.remaining_seconds <= 0:
                self.state.remaining_seconds = self.state.work_seconds
            self.state.running = True
            return {"ok": True, "state": self._state_payload()}
        if action == "pause_timer":
            self.state.running = False
            return {"ok": True, "state": self._state_payload()}
        if action == "reset_timer":
            self.state.running = False
            self.state.remaining_seconds = self.state.work_seconds
            return {"ok": True, "state": self._state_payload()}
        if action == "set_preset":
            self._set_preset(str(payload.get("preset", "")))
            return {"ok": True, "state": self._state_payload()}
        if action == "get_state":
            return {"ok": True, "state": self._state_payload()}
        if action == "read_stats":
            return {"ok": True, "stats": self.stats}
        if action == "write_stats":
            incoming = payload.get("stats")
            if isinstance(incoming, dict):
                self.stats.update(incoming)
                self._save_stats()
            return {"ok": True, "stats": self.stats}

        return {"ok": False, "error": f"Unknown action: {action}"}

    def _state_payload(self) -> Dict[str, Any]:
        return {
            **asdict(self.state),
            "presets": list(SESSION_PRESETS.keys()),
        }


def _iter_messages() -> Any:
    """Yield decoded JSON objects from stdin, one per line."""
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            yield {"action": "_invalid"}


def main() -> None:
    backend = PomodoroBackend()
    for message in _iter_messages():
        if message.get("action") == "_invalid":
            response = {"ok": False, "error": "Invalid JSON payload"}
        else:
            response = backend.handle(message)
        sys.stdout.write(json.dumps(response) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()

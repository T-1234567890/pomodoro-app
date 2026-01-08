"""Pomodoro backend bridge.

This module preserves existing timer logic by acting as a thin IPC wrapper.
The Tkinter UI remains in history/, while this file defines the
migration boundary for the new Tauri frontend.
"""
from __future__ import annotations

import json
import os
import sys
import threading
import time
from dataclasses import asdict, dataclass
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
    """In-memory state for IPC responses."""

    work_seconds: int = 25 * 60
    break_seconds: int = 5 * 60
    long_break_seconds: int = 15 * 60
    long_break_interval: int = 4
    remaining_seconds: int = 25 * 60
    running: bool = False
    is_break: bool = False
    break_kind: str = "short"
    cycle_progress: int = 0


class PomodoroEngine:
    """Timer logic extracted from the Tkinter app without UI dependencies."""

    def __init__(self) -> None:
        self.state = TimerState()
        self.stats = self._load_stats()
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._last_tick = time.monotonic()
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def shutdown(self) -> None:
        self._stop_event.set()

    def start_pomodoro(
        self,
        work_minutes: int | None = None,
        break_minutes: int | None = None,
        long_break_minutes: int | None = None,
        interval: int | None = None,
    ) -> None:
        with self._lock:
            self._apply_durations(work_minutes, break_minutes, long_break_minutes, interval)
            if self.state.remaining_seconds <= 0 or not self.state.running:
                if not self.state.is_break:
                    self.state.remaining_seconds = self.state.work_seconds
            self.state.running = True
            self._last_tick = time.monotonic()

    def pause_pomodoro(self) -> None:
        with self._lock:
            self.state.running = False
            self._last_tick = time.monotonic()

    def reset_pomodoro(self) -> None:
        with self._lock:
            self.state.running = False
            self.state.is_break = False
            self.state.break_kind = "short"
            self.state.cycle_progress = 0
            self.state.remaining_seconds = self.state.work_seconds
            self._last_tick = time.monotonic()

    def set_preset(self, preset_name: str) -> None:
        preset = SESSION_PRESETS.get(preset_name)
        if not preset:
            return
        with self._lock:
            self.state.work_seconds = preset["work"] * 60
            self.state.break_seconds = preset["break"] * 60
            self.state.long_break_seconds = preset["long_break"] * 60
            self.state.long_break_interval = preset["interval"]
            self.state.remaining_seconds = self.state.work_seconds
            self.state.is_break = False
            self.state.break_kind = "short"
            self.state.cycle_progress = 0

    def update_durations(
        self,
        work_minutes: int | None = None,
        break_minutes: int | None = None,
        long_break_minutes: int | None = None,
        interval: int | None = None,
    ) -> None:
        with self._lock:
            self._apply_durations(work_minutes, break_minutes, long_break_minutes, interval)
            if not self.state.running:
                self._refresh_remaining_seconds()

    def get_state(self) -> Dict[str, Any]:
        with self._lock:
            return self._state_payload()

    def get_stats(self) -> Dict[str, Any]:
        with self._lock:
            return self.stats.copy()

    def _apply_durations(
        self,
        work_minutes: int | None,
        break_minutes: int | None,
        long_break_minutes: int | None,
        interval: int | None,
    ) -> None:
        if work_minutes is not None and work_minutes > 0:
            self.state.work_seconds = int(work_minutes) * 60
        if break_minutes is not None and break_minutes > 0:
            self.state.break_seconds = int(break_minutes) * 60
        if long_break_minutes is not None and long_break_minutes > 0:
            self.state.long_break_seconds = int(long_break_minutes) * 60
        if interval is not None and interval > 0:
            self.state.long_break_interval = int(interval)

    def _run_loop(self) -> None:
        while not self._stop_event.is_set():
            time.sleep(0.25)
            with self._lock:
                if not self.state.running:
                    self._last_tick = time.monotonic()
                    continue
                now = time.monotonic()
                elapsed = int(now - self._last_tick)
                if elapsed <= 0:
                    continue
                self._last_tick += elapsed
                self._advance(elapsed)

    def _advance(self, seconds: int) -> None:
        while seconds > 0:
            if self.state.remaining_seconds > 0:
                self.state.remaining_seconds -= 1
                if self.state.is_break:
                    self.stats["break_seconds"] += 1
                else:
                    self.stats["focus_seconds"] += 1
                seconds -= 1
            if self.state.remaining_seconds <= 0:
                self._complete_session()

    def _refresh_remaining_seconds(self) -> None:
        if self.state.is_break:
            self.state.remaining_seconds = (
                self.state.long_break_seconds
                if self.state.break_kind == "long"
                else self.state.break_seconds
            )
        else:
            self.state.remaining_seconds = self.state.work_seconds

    def _complete_session(self) -> None:
        if self.state.is_break:
            if self.state.break_kind == "long":
                self.stats["long_breaks"] += 1
            else:
                self.stats["short_breaks"] += 1
            self.state.is_break = False
            self.state.break_kind = "short"
            self.state.remaining_seconds = self.state.work_seconds
        else:
            self.stats["count"] += 1
            self.state.cycle_progress += 1
            if self.state.long_break_interval > 0 and (
                self.state.cycle_progress % self.state.long_break_interval == 0
            ):
                self.state.is_break = True
                self.state.break_kind = "long"
                self.state.remaining_seconds = self.state.long_break_seconds
            else:
                self.state.is_break = True
                self.state.break_kind = "short"
                self.state.remaining_seconds = self.state.break_seconds
        self._save_stats()

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

    def _state_payload(self) -> Dict[str, Any]:
        mode = "Focus"
        if self.state.is_break:
            mode = "Long Break" if self.state.break_kind == "long" else "Break"
        return {
            **asdict(self.state),
            "mode": mode,
            "presets": list(SESSION_PRESETS.keys()),
        }


class PomodoroBackend:
    """JSON IPC bridge for the Tauri frontend."""

    def __init__(self) -> None:
        self.engine = PomodoroEngine()

    def handle(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        action = payload.get("action")
        if action in {"start_pomodoro", "start_timer"}:
            self.engine.start_pomodoro(
                work_minutes=_maybe_int(payload.get("work_minutes")),
                break_minutes=_maybe_int(payload.get("break_minutes")),
                long_break_minutes=_maybe_int(payload.get("long_break")),
                interval=_maybe_int(payload.get("interval")),
            )
            return {"ok": True, "state": self.engine.get_state()}
        if action in {"pause_pomodoro", "pause_timer"}:
            self.engine.pause_pomodoro()
            return {"ok": True, "state": self.engine.get_state()}
        if action in {"reset_pomodoro", "reset_timer"}:
            self.engine.reset_pomodoro()
            return {"ok": True, "state": self.engine.get_state()}
        if action == "set_preset":
            self.engine.set_preset(str(payload.get("preset", "")))
            return {"ok": True, "state": self.engine.get_state()}
        if action == "update_durations":
            self.engine.update_durations(
                work_minutes=_maybe_int(payload.get("work_minutes")),
                break_minutes=_maybe_int(payload.get("break_minutes")),
                long_break_minutes=_maybe_int(payload.get("long_break")),
                interval=_maybe_int(payload.get("interval")),
            )
            return {"ok": True, "state": self.engine.get_state()}
        if action in {"get_current_state", "get_state"}:
            return {"ok": True, "state": self.engine.get_state()}
        if action in {"get_stats", "read_stats"}:
            return {"ok": True, "stats": self.engine.get_stats()}

        return {"ok": False, "error": f"Unknown action: {action}"}


def _maybe_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


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

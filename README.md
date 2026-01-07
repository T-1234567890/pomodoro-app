# Pomodoro Timer

Pomodoro App — A modern, distraction-free Pomodoro & focus timer with session presets, long-break cycles, productivity statistics, and a minimal glass-style UI.

This app is built with Python + Tkinter and designed as a calm, structured focus companion rather than a gamified timer. It includes configurable work / break durations, long-break intervals, daily tracking, and optional sound notifications — all wrapped in a lightweight desktop UI.

The 0.4.x branch introduces a new glass-panel layout system with separate tiles for the timer, controls, and productivity summary, preparing the foundation for a more refined macOS-style “liquid glass” UI in future releases.

## Version status

- **Current version:** 0.4.2 fix — Liquid Glass UI redesign and contrast polish.
- **Update history:** see `history_versions/` for archived notes.

## Changelog (short)

- UI redesign with layered macOS 26-inspired glass tiles and a stronger hierarchy.
- New glass theme engine with rounded panels, gradients, and depth layering.
- Dark Mode contrast improved so text and disabled buttons remain readable.

## Features

- Customizable work and break durations
- Long-break interval support (configure duration and cadence)
- Session presets for quickly switching routines
- Start, pause/resume, and reset controls
- Popup notification when a session finishes
- Optional chime when sessions complete
- Tracks how many Pomodoros you have completed today
- Daily productivity summary (focus time, break counts)
- Displays remaining time
- Works offline on macOS (Python and tkinter are usually included)
- Optional dark mode for late-night sessions
- Pomodoro work & break timer
- Configurable long-break intervals
- Built-in session presets (25/5, 50/10, etc.)
- Daily statistics (focus time, breaks taken, sessions completed)
- Optional sound notification on completion
- Countdown mini-timer window
- Simple built-in music player window
- Auto-saves daily progress
- Glass-panel UI layout (0.4.x series)

## Current UI Direction

The current UI uses a structured glass tile system to improve layout consistency and grouping of elements.

Version 0.4.2-fix focuses on:

- improving panel spacing & hierarchy
- stabilizing the new layout engine
- preparing for a future visual refinement pass

The goal of upcoming versions is to transition toward a softer, macOS-inspired liquid glass look — with more subtle contrast, improved typography, and refined panel depth.

## Project Status

- Stable for daily use
- Design iterations in progress
- Codebase structured for UI refinement in upcoming versions

## Roadmap

Planned for future versions:

- 🎨 macOS-style liquid glass theme refinements
- 🌙 improved dark mode contrast & tone
- ⏳ optional auto-start next session
- 🪄 smoother button & timer animations
- 🎧 better media player integration

## Collaboration & Contributions

Contributions, ideas, and feedback are welcome — this project is actively evolving through design and feature iterations.

You’re welcome to help improve:

- 🎨 UI & visual refinement (macOS-style liquid glass direction)
- 🌓 Dark mode contrast & accessibility
- 🧩 Session logic & customization options
- 🧪 Bug fixes and stability improvements
- 📝 Documentation & usability polish
- ✅ Anything else

## Discussions & Suggestions

If you want to:

- propose a feature
- discuss UI / UX direction

You can open a Discussion or Issue instead of a PR.

Constructive feedback is especially welcome during the current 0.4.x UI refinement phase.

## Usage

Run the application with Python 3:

```bash
python3 pomodoro.py
```

The first time a work session completes, the count for the current day increases. The count is stored in `pomodoro_data.json` in the same directory.

## Countdown Timer


The repository also includes a countdown timer and a minimal music player.

### Countdown Timer
Run the simple timer or open it from the Pomodoro app with the "Open Countdown" button:

```bash
python3 countdown.py
```

### Music Player
You can open the player from the Pomodoro window using the "Open Music Player"
button, or run it standalone. The script lets you open a local audio file,
view its basic ID3v1 metadata, and play it using the operating system's default
utilities. Launch it with:

```bash
python3 music_player.py
```

Only basic playback commands (play/stop) are provided and the script falls back
on commands like `afplay` or `aplay` depending on your platform.
If you have `playerctl` on Linux or AppleScript support on macOS, the player
also displays the track currently playing in other music applications.


## ⚠️ 说明
本项目仍在持续改进中，部分功能或界面可能会发生变化。
如在使用过程中发现问题或有改进建议，欢迎提交 Issue 或 PR。


## ⚠️ Notice
This project is under active development and some features or UI elements may change over time.
If you encounter issues or have suggestions, feel free to open an issue or pull request.

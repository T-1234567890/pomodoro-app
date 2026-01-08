# Pomodoro Timer

Pomodoro App — A modern, distraction-free Pomodoro & focus timer with session presets, long-break cycles, productivity statistics, and a minimal glass-style UI.

The 0.5.x branch introduces a new glass-panel layout system with separate tiles for the timer, controls, and productivity summary, preparing the foundation for a more refined macOS-style “liquid glass” UI in future releases.

<img width="320" height="320" alt="Firefly_Gemini Flash_Make it in to normal white background 328819" src="https://github.com/user-attachments/assets/629e345e-5540-4439-8e47-30f3db8c6cad" />

## Version status

Current: Version 0.6.1<br>
Update history: see history_versions/ for archived notes.

### ✨ New Features
- Secondary “More Functions” panel
- Pop up reminder (when timer season ends)
- Built-in Music Player (local audio playback)
- Independent Countdown Timer
- UI layout cleanup and consolidation

### 🔄 Ongoing Work
- Feature iteration and refinement
- Code cleanup after 0.5.x migration
- Stability and performance improvements

### ⚠️ Beta Notes
- UI/UX is still evolving
- If there is any bugs, please add a issue

### 📌 Update Policy
- 0.6.0-beta will receive more updates
- Changes may occur without notice
- Feedback, PR, and issue reports are welcome


## Changelog (short)

## 0.6.1
- Added session-end pop-up reminder
- Improved session completion feedback
- No changes to existing timer behavior or settings

- UI redesign with layered macOS 26-inspired glass tiles and a stronger hierarchy.
- New glass theme engine with rounded panels, gradients, and depth layering.
- Dark Mode contrast improved so text and disabled buttons remain readable.

## Features

- Customizable work and break durations
- Long-break interval support (configure duration and cadence)
- Session presets for quickly switching routines
- Start, pause/resume, and reset controls
- Session-end pop-up reminder
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

## 🚀 Running the App (v0.5.0+ Migration Build)

This version introduces a new architecture:

- Python powers the Pomodoro engine (backend)
- Tauri provides the desktop shell
- Svelte is the frontend UI

The Python backend is launched automatically by Tauri through an IPC bridge — no manual scripts are required.

## ▶️ Start the App (Development Mode: Packaged app working on future generations)

Run these commands from the project root:

```bash
cd frontend
npm install
npm run tauri dev
```

or (If npm installed)

```bash
cd frontend
npm run tauri dev
```

---

### 🔧 Requirements

Install the following:

- Python 3.10+
- Node.js 18+
- Rust toolchain
- Tauri CLI

Install Tauri CLI:

```bash
npm install -g @tauri-apps/cli
```

---

## Current UI Direction

The current UI uses a structured glass tile system inspired by macOS 26 (liquid glass).

Version 0.6.x focuses on:

- improving animations
- improving the new UI

The goal of upcoming versions is to transition toward a softer, macOS-inspired liquid glass look — with more subtle contrast, improved typography, and refined panel depth.

## Project Status

- Stable for daily use
- Design iterations in progress
- New features in upcoming versions

## 🗺️ Roadmap (Post-0.6.0)

Planned for future versions beyond the 0.6.x beta cycle:

- 🎨 more macOS-style liquid glass theme refinements
- 🪄 Smoother button & timer animations
- 💡 better logic
- 🔔 Advanced reminder scheduling & customization
- 🛎️ issue requirements

---

## 🤝 Collaboration & Contributions

Contributions, ideas, and feedback are welcome — this project is actively evolving
through design and feature iteration during the 0.6.0 beta phase.

You’re welcome to help improve:

- 🎨 UI & visual refinement (macOS-style liquid glass direction)
- 🧩 Session logic & customization options
- 🔔 In-app reminder & notification
- 🧪 Bug fixes and stability improvements
- 📝 Documentation
- ✅ Anything else

## Discussions & Suggestions

If you want to:

- propose a feature
- discuss UI / UX direction
- any other things about this project

You can open a Discussion or Issue instead of a PR.

Constructive feedback is especially welcome during the current 0.4.x UI refinement phase.

## Usage

The Tauri shell launches the Svelte UI and starts the Python backend in `backend/app.py` automatically.

### Legacy Tkinter UI (manual fallback)

The Tkinter interface is archived in `history/ui-tkinter-0.4.x` and no longer launches by default. If you need it:

```bash
python3 history/ui-tkinter-0.4.x/pomodoro.py
```

The stats file format remains the same (`backend/pomodoro_data.json`).

### Migration note

- The Svelte + Tauri frontend is now the primary UI, and the Python backend provides timer/state/stats over a JSON IPC bridge.
- The Tkinter UI was preserved under `history/ui-tkinter-0.4.x` for rollback.

## 🏗️ Working on (0.6.0-beta)

### 🎧 Music Player (Improving)
A lightweight in-app music player designed for focus sessions using local audio.

Current functionality:
- Opened from the **More Functions** panel
- Select and play local audio files
- Basic playback controls (play / pause / stop)
- Volume adjustment and playback status display

Planned improvements:
- UI and layout refinements
- Better integration with system media state (where supported)
- Clearer playback feedback and status indicators
- Improved handling of file selection and edge cases

The music player will continue to evolve during the 0.6.x beta or later future cycle.

---

### 🔔 Reminders (In-App Feature — In Progress)
An upcoming in-app reminder system designed to gently notify users of important
events without breaking focus.

Current direction:
- Reminders
- Optional time-based reminders
- Native system notifications (if supported)
- Subtle, non-intrusive behavior by default
- Fully optional and configurable

The reminder system is intended to complement the Pomodoro workflow,
not replace it or become distracting.


## ⚠️ 说明
本项目仍在持续改进中，部分功能或界面可能会发生变化。
如在使用过程中发现问题或有改进建议，欢迎提交 Issue 或 PR。


## ⚠️ Notice
This project is under active development and some features or UI elements may change over time.
If you encounter issues or have suggestions, feel free to open an issue or pull request.

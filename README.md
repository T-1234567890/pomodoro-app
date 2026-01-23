# 🍅 Pomodoro Timer

**Pomodoro Timer** is a modern, distraction-free Pomodoro & focus timer designed for macOS.  
It features session presets, long-break cycles, productivity summaries, ambient audio, and a macOS-inspired **glass / liquid glass UI**.

Version **1.0.0** marks the first stable milestone after extensive UI, architecture, and workflow refinement.

<img width="320" height="320" alt="Firefly_Gemini Flash_Make it in to normal white background 328819" src="https://github.com/user-attachments/assets/629e345e-5540-4439-8e47-30f3db8c6cad" />

![License](https://img.shields.io/github/license/T-1234567890/pomodoro-app)
![Platform](https://img.shields.io/badge/platform-macOS-blue?logo=apple)
![Release](https://img.shields.io/github/v/release/T-1234567890/pomodoro-app)
![Downloads](https://img.shields.io/github/downloads/T-1234567890/pomodoro-app/total)

## Screenshot
<img width="1046" height="638" alt="Screenshot 2026-01-21 at 10 10 07 PM" src="https://github.com/user-attachments/assets/7135a578-4191-4aea-9629-cd7072180557" />

## Version status

Current Version: <br>
✅ 1.0.0

Update history: see history_versions/ for archived notes.

### ⚠️ Beta Notes
- UI/UX is still evolving
- If there is any bugs, please add a issue

### 📌 Update Policy
- Will receive more updates
- Changes may occur without notice
- Feedback, PR, and issue reports are welcome


## Changelog (short)

## 1.0.x
-fully migrated to Swift
- Major UI polish and layout refinement
- New sidebar-based navigation
- Improved glass / background blur rendering
- Stability improvements

## ✅ Features

- ⏱️ Customizable work, short break, and long break durations
- 🔁 Long-break interval configuration (e.g. every 4 sessions)
- ⚡ Presets for quick switching (25/5, 50/10, 90/15, Custom)
- ▶️ Start / Pause / Resume / Reset with clear state feedback
- ⏳ Dedicated countdown timer mode
- 🔔 Session-end pop-up reminder with optional sound
- 📊 Daily productivity summary (focus time, sessions, breaks)
- 💾 Automatic saving of daily stats
- 🎧 Ambient sound player (white noise, brown noise, rain, wind)
- 🎵 Simple music status support (Apple Music / Spotify)
- 🪟 Glass-panel UI with background blur and depth
- 🌙 macOS dark mode support
- 💻 Real time menubar support on MacBooks

## 🚀 Running the App (1.0.0+ Swift)

Using the official release or running with Xcode

---

### 🔧 Requirements for Developing

Install the following: Xcode

---

## Current UI Direction

The current UI uses a structured glass tile system inspired by macOS 26 (liquid glass).

Version 1.0.x+ focuses on:

- Clean up UI
- Updating macOS 15 style to macOS 26 liquid glass.

The goal of upcoming versions is to transition toward a softer, macOS-inspired liquid glass look — with more subtle contrast, improved typography, and refined panel depth.

## Project Status

- Stable for daily use
- Design iterations in progress
- New features in upcoming versions

>**🚧 Distribution Status**
>
>Pomodoro is currently under active development and not yet available on TestFlight or the Mac App Store.<br>
>
>Why?<br>
>The Apple Developer Program enrollment is in progress.<br>
>Once the developer account is active, TestFlight builds will be distributed immediately.<br>
>
>What this means for now<br>
>❌ No App Store / TestFlight builds yet<br>
>❌ No automatic updates<br>
>✅ Local development builds continue normally<br>
>✅ All core features are being actively built and tested<br>
>
>What’s coming next<br>
>🧪 TestFlight beta access (first priority)<br>
>🔄 Seamless updates via Apple’s official update system<br>
>📦 Mac App Store submission after stabilization<br>
>
>Timeline (estimated)<br>
>Apple Developer account: in a few weeks<br>
>TestFlight beta: shortly after account activation<br>
>Public App Store release: after feedback & polish<br>
>
>Follow progress<br>
>Development updates are posted regularly in this repository<br>
>Feature work continues during this waiting period — no downtime<br>
>
>Thank you for your patience and interest ❤️

## 🗺️ Roadmap (Post-1.0.0)

Planned for future versions:

- 🎨 More macOS-style liquid glass theme refinements
- 🪄 Smoother button & timer animations
- 💡 Better logic
- 🔔 Advanced reminder scheduling & customization
- ⌨️ More features
- 🛎️ Issue requirements

---

## 🤝 Collaboration & Contributions

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

Constructive feedback is especially welcome during the current 0.6.x UI refinement phase.

## 🕰️ Legacy Systems (Archived)

Pomodoro has gone through multiple architectural stages during its development.
All previous implementations are preserved **for reference only** and are no longer
part of the active product direction.

Legacy see: https://github.com/T-1234567890/Pomodoro-legacy

**Status**
- ❌ Deprecated
- ❌ Prototype only
- ❌ No longer representative of the project
- ❌ No longer maintained

The current mainline version of Pomodoro is **fully native Swift (macOS)**.

---

### Legacy System A — Tauri + Svelte + Python (0.5.x – 0.7.x)

This version introduced a modern desktop architecture before the move to native Swift.

**Stack**
- Frontend: Svelte
- Desktop shell: Tauri
- Backend: Python (Pomodoro engine)
- IPC: JSON-based bridge between frontend and backend

**Reason for deprecation**
While functional, this architecture:
- Added unnecessary complexity on macOS
- Limited deep system integration
- Did not fully match macOS performance and UX expectations

The project has since migrated to **native Swift** for clarity, performance, and long-term maintainability.

---

### Legacy System B — Python + Tkinter UI (≤ 0.4.x)

This was the **original prototype** used during the earliest stages of development.

**Stack**
- Python
- Tkinter UI
- Single-process desktop app

## 🏗️ Working on

### 🖥️ Native liquid glass UI/UX
An upcoming release for the native liquid glass support (currently macOS 15 style)

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

## 📈 Star History

[![Star History](https://api.star-history.com/svg?repos=T-1234567890/pomodoro-app&type=Date)](https://star-history.com/#T-1234567890/pomodoro-app)

## ⚠️ 说明
本项目仍在持续改进中，部分功能或界面可能会发生变化。
如在使用过程中发现问题或有改进建议，欢迎提交 Issue 或 PR。


## ⚠️ Notice
This project is under active development and some features or UI elements may change over time.
If you encounter issues or have suggestions, feel free to open an issue or pull request.

# 🍅 Pomodoro App
### Plan. Focus. Done.

**Pomodoro App** is a macOS productivity app that connects focus sessions, Tasks, Reminders, and Calendar into a single workflow.  
It is not just a timer — it links tasks, time, and focus, adapting to task-driven, time-blocking, or flow-based work styles. Pomodoro is built as a unified time system rather than a rigid productivity method, with a macOS-inspired **glass / liquid glass UI**.

Version **1.1.0** is a feature integration update that deepens system connections without a full redesign.

<p align="center">
  <img
    width="320"
    height="320"
    alt="Pomodoro App Logo"
    src="https://github.com/user-attachments/assets/629e345e-5540-4439-8e47-30f3db8c6cad"
  />
</p>

<p align="center">
  <img src="https://img.shields.io/github/license/T-1234567890/pomodoro-app" alt="License" />
  <img src="https://img.shields.io/badge/platform-macOS-blue?logo=apple" alt="Platform" />
  <img src="https://img.shields.io/github/v/release/T-1234567890/pomodoro-app" alt="Release" />
  <img src="https://img.shields.io/github/downloads/T-1234567890/pomodoro-app/total" alt="Downloads" />
</p>

>## ⚠️ Notice
> If the app still ask for calendar&reminders permissions after you activate, please quit and restart the app

## 🌐 Our official website

Explore the project website for design philosophies, documentation, and downloads:<br>
👉  https://pomodoro-app.tech

## 🚀 Try it now

Download the latest release from GitHub and run the app immediately: see Pomodoro v1.1.0 for the current build. Future releases will appear under Releases.

- **Gatekeeper warning**: macOS may warn that the app is from an unidentified developer. This is expected while the project awaits Apple Developer Program approval.
- **Bypass Gatekeeper safely**: follow the step‑by‑step guide in `docs/Gatekeeper.md` to open the downloaded app without compromising security.

Once the Apple developer account is active, signed TestFlight and App Store builds will be provided.

## Screenshot
<img width="1027" height="728" alt="Screenshot 2026-01-30 at 4 25 25 PM" src="https://github.com/user-attachments/assets/e04529ad-dacf-4675-bb06-88fdf5a2a7cf" />


## ✅ Features

- ⏱️ Customizable work, short break, and long break durations
- 🔁 Long-break interval configuration (e.g. every 4 sessions)
- ⚡ Presets for quick switching (25/5, 50/10, 90/15, Custom)
- ▶️ Start / Pause / Resume / Reset with clear state feedback
- ⏳ Dedicated countdown timer mode
- ✅ Tasks with optional Reminders integration and bidirectional sync foundations
- 📅 Calendar views (Day / Week / Month) as a visual layer for planning
- 🔔 Session-end pop-up reminder with optional sound
- 📊 Daily productivity summary (focus time, sessions, breaks)
- 💾 Automatic saving of daily stats
- 🎧 Ambient sound player (white noise, brown noise, rain, wind)
- 🎵 Simple music status support (Apple Music / Spotify)
- 🪟 Glass-panel UI with background blur and depth
- 🌙 macOS dark mode support
- 💻 Real time menubar support on MacBooks

## ✨ Why Pomodoro App is different

Pomodoro App is designed as a unified time system — not just a timer. It brings together focus sessions, tasks, reminders, and calendar blocks into **one single workflow**, so planning and execution live in the same place.

Instead of forcing a rigid productivity method, Pomodoro App **adapts to how you actually work — whether that’s time-blocking, task-driven planning, or flow-based focus**.

## 🧰 Running & Developing

### Running the app

If you prefer not to build from source, download the binary from the latest release (see “Try it now” above). On first launch, macOS may block the app; use the Gatekeeper guide linked above.

### Building from source

Requires Xcode on macOS 14.6 or later.
Clone this repository, open the project in Xcode, and build/run as usual.

**Requirements:** <br>
- GoogleSignIn (>= 7.1.0)
- AppAuth 1.7.6
- GTMAppAuth 4.1.1
- GTMSessionFetcher 3.5.0
- Xcode on macOS 14.6 or later

This project uses Swift Package Manager to manage dependencies. <br>
The current version is fully native Swift; legacy Tauri/Svelte/Python versions are archived.

## Version status

Current Version: <br>
✅ 1.5.0

Update history: see `History versions.md` for archived notes.

### 📌 Update Policy
- Will receive more updates
- Changes may occur without notice
- Feedback, PR, and issue reports are welcome

## Changelog (short)

### 1.5.0
- Add flow mode
- UI update for music and audio panel

## 🚀 Coming next: TestFlight

Apple TestFlight preview builds are launching soon. <br>
Pomodoro App is **transitioning** to Apple's distribution (TestFlight → App Store). <br>

Join the waitlist:
https://forms.gle/hQ7ubqxt39sXca4e9

Why join TestFlight waitlist? <br>
- Access to upcoming official builds
- Early access to the Apple release channel
- Smooth transition to the App Store version  
- Help shape the future direction before public launch

## Current UI Direction

The current UI uses a structured glass tile system inspired by macOS 26 (liquid glass).

Version 1.1.x focuses on:

- Deepening Calendar, Reminders, and Tasks integration across the UI
- Clean up UI
- Updating macOS 15 style to macOS 26 liquid glass.

The goal of upcoming versions is to transition toward a softer, macOS-inspired liquid glass look — with more subtle contrast, improved typography, and refined panel depth.

## 🛠️ Project status

- Stable for daily use
- Design iterations are ongoing
- New features are in development

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

Constructive feedback is especially welcome during the current 1.x.x integration and planning phase.

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

### 🔔 Reminders (Improvements)
Continuing to extend the in-app reminder system introduced in v1.1.0 to gently notify users of important
events without breaking focus.

Current direction:
- Feedback
- General update

The reminder system is intended to complement the Pomodoro workflow,
not replace it or become distracting.

## Docs

- Future planning: `docs/Future_Pro_Plan.md`
- Development roadmap: `docs/Roadmap_1.0-2.0.md`
- FAQ & design decisions: `docs/FAQ.md`
- Gatekeeper & installation notes: `docs/Gatekeeper.md`

### Long-term Future Directions

**Pomodoro App is free**.

A small number of long-term ideas (AI features, cloud sync, deeper analytics) are being brainstormed.  
**No paid plan exists at this stage.**

Details: `docs/Future_Pro_Plan.md`

## 📈 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=T-1234567890/pomodoro-app&type=date&legend=top-left)](https://www.star-history.com/#T-1234567890/pomodoro-app&type=date&legend=top-left)

## ⚠️ 说明
本项目仍在持续改进中，部分功能或界面可能会发生变化。
如在使用过程中发现问题或有改进建议，欢迎提交 Issue 或 PR。


## ⚠️ Notice
This project is under active development and some features or UI elements may change over time.
If you encounter issues or have suggestions, feel free to open an issue or pull request.

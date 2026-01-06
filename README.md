# Pomodoro Timer

This repository contains a simple Pomodoro desktop application written in Python using `tkinter`.

## Version status

- **Current version:** 0.4.1 Beta — Liquid Glass UI refresh and dark mode polish.
- **Update history (archived):**
  - 0.3.0 Beta — prior feature-complete release.

## Changelog (short)

- macOS 26-inspired liquid glass visuals with frosted cards and floating timer tile.
- Clearer hierarchy between header, controls, timer, and summary sections.
- Dark Mode contrast tuned for readability; buttons and disabled states remain legible.
- Countdown and music player pick up the refreshed theme tokens and borders.

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


## 免责声明
本仓库全部内容由 ChatGPT Xcode 制作。该代码可能含有错误，使用前请自行验证。


## Disclaimer
All content in this repository was produced by ChatGPT Xcode. The code may contain errors, so please verify it before use.

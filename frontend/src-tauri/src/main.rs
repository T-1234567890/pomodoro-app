#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::Mutex;

use tauri::{
    api::notification::Notification, AppHandle, CustomMenuItem, Env, GlobalWindowEvent, Icon,
    Manager, State, SystemTray, SystemTrayEvent, SystemTrayMenu, SystemTrayMenuItem,
    SystemTraySubmenu, WindowEvent,
};

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SystemMediaState {
    available: bool,
    title: String,
    artist: Option<String>,
    source: String,
    is_playing: bool,
    supports_play_pause: bool,
    supports_next: bool,
    supports_previous: bool,
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct PomodoroSnapshot {
    running: bool,
    active: bool,
    mode: String,
    remaining_seconds: u64,
    total_seconds: u64,
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CountdownSnapshot {
    running: bool,
    active: bool,
    remaining_seconds: u64,
    total_seconds: u64,
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct AudioSnapshot {
    active_source: String,
    is_playing: bool,
    play_pause_enabled: bool,
    previous_enabled: bool,
    next_enabled: bool,
    focus_sound: String,
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct MenuSyncPayload {
    pomodoro: PomodoroSnapshot,
    countdown: CountdownSnapshot,
    audio: AudioSnapshot,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum MenuMode {
    Pomodoro,
    Break,
    Countdown,
    Idle,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct MenuPresentation {
    mode: MenuMode,
    play_pause_label: String,
    play_pause_enabled: bool,
    previous_enabled: bool,
    next_enabled: bool,
    focus_sound: String,
    countdown_running: bool,
    countdown_active: bool,
}

#[derive(Default)]
struct TrayState {
    menu: Mutex<TraySnapshot>,
}

#[derive(Default)]
struct TraySnapshot {
    last_title: String,
    last_presentation: Option<MenuPresentation>,
}

#[cfg(target_os = "macos")]
fn run_applescript(script: &str) -> Result<String, String> {
    let output = Command::new("osascript")
        .arg("-e")
        .arg(script)
        .output()
        .map_err(|err| format!("Failed to run AppleScript: {err}"))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

#[cfg(not(target_os = "macos"))]
fn run_applescript(_script: &str) -> Result<String, String> {
    Ok(String::new())
}

#[tauri::command]
fn get_system_media_state() -> Result<SystemMediaState, String> {
    #[cfg(not(target_os = "macos"))]
    {
        return Ok(SystemMediaState {
            available: false,
            title: String::new(),
            artist: None,
            source: String::new(),
            is_playing: false,
            supports_play_pause: false,
            supports_next: false,
            supports_previous: false,
        });
    }

    #[cfg(target_os = "macos")]
    {
        let script = r#"
set output to ""
if application "Spotify" is running then
  tell application "Spotify"
    if player state is playing or player state is paused then
      set trackName to name of current track
      set artistName to artist of current track
      set stateName to player state as string
      set output to trackName & "||" & artistName & "||Spotify||" & stateName & "||true||true"
    end if
  end tell
end if

if output is "" then
  if application "Music" is running then
    tell application "Music"
      if player state is playing or player state is paused then
        set trackName to name of current track
        set artistName to artist of current track
        set stateName to player state as string
        set output to trackName & "||" & artistName & "||Music||" & stateName & "||true||true"
      end if
    end tell
  end if
end if

if output is "" then
  try
    if application "Safari" is running then
      tell application "Safari"
        set frontTab to current tab of front window
        set tabName to name of frontTab
        set isAudible to false
        try
          set isAudible to audible of frontTab
        end try
        if isAudible is true then
          set output to tabName & "||" & "" & "||Safari||playing||false||false"
        end if
      end tell
    end if
  end try
end if

return output
"#;

        let response = run_applescript(script)?;
        if response.is_empty() {
            return Ok(SystemMediaState {
                available: false,
                title: String::new(),
                artist: None,
                source: String::new(),
                is_playing: false,
                supports_play_pause: false,
                supports_next: false,
                supports_previous: false,
            });
        }

        let parts: Vec<&str> = response.split("||").collect();
        let title = parts.get(0).unwrap_or(&"").to_string();
        let artist = parts.get(1).map(|value| value.to_string()).filter(|value| !value.is_empty());
        let source = parts.get(2).unwrap_or(&"").to_string();
        let state = parts.get(3).unwrap_or(&"").to_string();
        let supports_next = parts.get(4).unwrap_or(&"false") == &"true";
        let supports_previous = parts.get(5).unwrap_or(&"false") == &"true";
        let is_playing = state == "playing";
        let supports_play_pause = source != "Safari";

        Ok(SystemMediaState {
            available: true,
            title,
            artist,
            source,
            is_playing,
            supports_play_pause,
            supports_next,
            supports_previous,
        })
    }
}

#[tauri::command]
fn control_system_media(action: String) -> Result<(), String> {
    #[cfg(not(target_os = "macos"))]
    {
        let _ = action;
        return Ok(());
    }

    #[cfg(target_os = "macos")]
    {
        let script = match action.as_str() {
            "play_pause" => r#"
if application "Spotify" is running then
  tell application "Spotify"
    if player state is playing or player state is paused then
      playpause
      return ""
    end if
  end tell
end if

if application "Music" is running then
  tell application "Music"
    if player state is playing or player state is paused then
      playpause
      return ""
    end if
  end tell
end if

return ""
"#,
            "next" => r#"
if application "Spotify" is running then
  tell application "Spotify"
    if player state is playing or player state is paused then
      next track
      return ""
    end if
  end tell
end if

if application "Music" is running then
  tell application "Music"
    if player state is playing or player state is paused then
      next track
      return ""
    end if
  end tell
end if

return ""
"#,
            "previous" => r#"
if application "Spotify" is running then
  tell application "Spotify"
    if player state is playing or player state is paused then
      previous track
      return ""
    end if
  end tell
end if

if application "Music" is running then
  tell application "Music"
    if player state is playing or player state is paused then
      previous track
      return ""
    end if
  end tell
end if

return ""
"#,
            _ => return Err("Unsupported action".to_string()),
        };

        run_applescript(script)?;
        Ok(())
    }
}

fn format_duration(total_seconds: u64) -> String {
    let minutes = total_seconds / 60;
    let seconds = total_seconds % 60;
    format!("{minutes:02}:{seconds:02}")
}

fn build_presentation(payload: &MenuSyncPayload) -> (MenuPresentation, String) {
    let pomodoro_active = payload.pomodoro.active;
    let is_break = payload.pomodoro.mode != "work";
    let countdown_running = payload.countdown.running;
    let menu_mode = if pomodoro_active {
        if is_break {
            MenuMode::Break
        } else {
            MenuMode::Pomodoro
        }
    } else if countdown_running {
        MenuMode::Countdown
    } else {
        MenuMode::Idle
    };

    let play_pause_label = if payload.audio.is_playing {
        "⏸ Pause"
    } else {
        "▶ Play"
    };

    let title = if pomodoro_active {
        if is_break {
            format!("☕ {}", format_duration(payload.pomodoro.remaining_seconds))
        } else {
            format!("🍅 {}", format_duration(payload.pomodoro.remaining_seconds))
        }
    } else if countdown_running {
        format!("⏱ {}", format_duration(payload.countdown.remaining_seconds))
    } else {
        "🍅 Ready".to_string()
    };

    (
        MenuPresentation {
            mode: menu_mode,
            play_pause_label: play_pause_label.to_string(),
            play_pause_enabled: payload.audio.play_pause_enabled,
            previous_enabled: payload.audio.previous_enabled,
            next_enabled: payload.audio.next_enabled,
            focus_sound: payload.audio.focus_sound.clone(),
            countdown_running: payload.countdown.running,
            countdown_active: payload.countdown.active,
        },
        title,
    )
}

fn build_music_submenu(presentation: &MenuPresentation) -> SystemTraySubmenu {
    let play_pause = if presentation.play_pause_enabled {
        CustomMenuItem::new("music_play_pause", &presentation.play_pause_label)
    } else {
        CustomMenuItem::new("music_play_pause", &presentation.play_pause_label).disabled()
    };
    let previous = if presentation.previous_enabled {
        CustomMenuItem::new("music_previous", "⏮ Previous")
    } else {
        CustomMenuItem::new("music_previous", "⏮ Previous").disabled()
    };
    let next = if presentation.next_enabled {
        CustomMenuItem::new("music_next", "⏭ Next")
    } else {
        CustomMenuItem::new("music_next", "⏭ Next").disabled()
    };

    let focus_off = if presentation.focus_sound == "off" {
        CustomMenuItem::new("focus_sound_off", "Off").selected()
    } else {
        CustomMenuItem::new("focus_sound_off", "Off")
    };
    let focus_white = if presentation.focus_sound == "white" {
        CustomMenuItem::new("focus_sound_white", "White").selected()
    } else {
        CustomMenuItem::new("focus_sound_white", "White")
    };
    let focus_rain = if presentation.focus_sound == "rain" {
        CustomMenuItem::new("focus_sound_rain", "Rain").selected()
    } else {
        CustomMenuItem::new("focus_sound_rain", "Rain")
    };
    let focus_brown = if presentation.focus_sound == "brown" {
        CustomMenuItem::new("focus_sound_brown", "Brown").selected()
    } else {
        CustomMenuItem::new("focus_sound_brown", "Brown")
    };

    let focus_menu = SystemTrayMenu::new()
        .add_item(focus_off)
        .add_item(focus_white)
        .add_item(focus_rain)
        .add_item(focus_brown);
    let focus_submenu = SystemTraySubmenu::new("Focus Sound", focus_menu);

    let menu = SystemTrayMenu::new()
        .add_item(play_pause)
        .add_item(previous)
        .add_item(next)
        .add_native_item(SystemTrayMenuItem::Separator)
        .add_submenu(focus_submenu)
        .add_native_item(SystemTrayMenuItem::Separator)
        .add_item(CustomMenuItem::new("open_music", "Open Music Tab"));

    SystemTraySubmenu::new("Music", menu)
}

fn build_countdown_submenu(presentation: &MenuPresentation) -> SystemTraySubmenu {
    let start = if presentation.countdown_running {
        CustomMenuItem::new("countdown_start", "Start").disabled()
    } else {
        CustomMenuItem::new("countdown_start", "Start")
    };
    let pause = if presentation.countdown_running {
        CustomMenuItem::new("countdown_pause", "Pause")
    } else {
        CustomMenuItem::new("countdown_pause", "Pause").disabled()
    };
    let reset = if presentation.countdown_active {
        CustomMenuItem::new("countdown_reset", "Reset")
    } else {
        CustomMenuItem::new("countdown_reset", "Reset").disabled()
    };

    let menu = SystemTrayMenu::new()
        .add_item(start)
        .add_item(pause)
        .add_item(reset)
        .add_native_item(SystemTrayMenuItem::Separator)
        .add_item(CustomMenuItem::new("open_countdown", "Open Countdown Tab"));

    SystemTraySubmenu::new("Countdown", menu)
}

fn build_tray_menu(presentation: &MenuPresentation) -> SystemTrayMenu {
    let music_submenu = build_music_submenu(presentation);
    let countdown_submenu = build_countdown_submenu(presentation);

    match presentation.mode {
        MenuMode::Pomodoro => SystemTrayMenu::new()
            .add_item(CustomMenuItem::new("header", "Pomodoro — Work").disabled())
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("pomodoro_pause", "⏸ Pause"))
            .add_item(CustomMenuItem::new("pomodoro_reset", "↺ Reset"))
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("break_start", "Start Break"))
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_submenu(music_submenu)
            .add_submenu(countdown_submenu)
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("open_app", "Open App"))
            .add_item(CustomMenuItem::new("quit", "Quit")),
        MenuMode::Break => SystemTrayMenu::new()
            .add_item(CustomMenuItem::new("header", "Break Time").disabled())
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("pomodoro_pause", "⏸ Pause"))
            .add_item(CustomMenuItem::new("pomodoro_reset", "↺ Reset"))
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("break_skip", "Skip Break"))
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_submenu(music_submenu)
            .add_submenu(countdown_submenu)
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("open_app", "Open App"))
            .add_item(CustomMenuItem::new("quit", "Quit")),
        MenuMode::Countdown => SystemTrayMenu::new()
            .add_item(CustomMenuItem::new("header", "Countdown Timer").disabled())
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(if presentation.countdown_running {
                CustomMenuItem::new("countdown_pause", "⏸ Pause")
            } else {
                CustomMenuItem::new("countdown_pause", "⏸ Pause").disabled()
            })
            .add_item(if presentation.countdown_active {
                CustomMenuItem::new("countdown_reset", "↺ Reset")
            } else {
                CustomMenuItem::new("countdown_reset", "↺ Reset").disabled()
            })
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_submenu(music_submenu)
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("open_countdown", "Open Countdown Tab"))
            .add_item(CustomMenuItem::new("open_app", "Open App"))
            .add_item(CustomMenuItem::new("quit", "Quit")),
        MenuMode::Idle => SystemTrayMenu::new()
            .add_item(CustomMenuItem::new("header", "Pomodoro Timer").disabled())
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("pomodoro_start", "Start Pomodoro"))
            .add_item(CustomMenuItem::new("countdown_start", "Start Countdown"))
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_submenu(music_submenu)
            .add_native_item(SystemTrayMenuItem::Separator)
            .add_item(CustomMenuItem::new("open_app", "Open App"))
            .add_item(CustomMenuItem::new("quit", "Quit")),
    }
}

fn sync_tray_state(
    app: &AppHandle,
    tray_state: &mut TraySnapshot,
    payload: &MenuSyncPayload,
) -> Result<(), String> {
    let (presentation, title) = build_presentation(payload);

    #[cfg(target_os = "macos")]
    if tray_state.last_title != title {
        app.tray_handle()
            .set_title(&title)
            .map_err(|err| format!("Failed to update tray title: {err}"))?;
        tray_state.last_title = title;
    }

    if tray_state
        .last_presentation
        .as_ref()
        .map(|last| last != &presentation)
        .unwrap_or(true)
    {
        let menu = build_tray_menu(&presentation);
        app.tray_handle()
            .set_menu(menu)
            .map_err(|err| format!("Failed to update tray menu: {err}"))?;
        tray_state.last_presentation = Some(presentation);
    }

    Ok(())
}

#[derive(Clone, serde::Serialize)]
struct TrayActionPayload {
    action: String,
    value: Option<String>,
}

fn emit_tray_action(app: &AppHandle, action: &str, value: Option<&str>) {
    let _ = app.emit_all(
        "tray-action",
        TrayActionPayload {
            action: action.to_string(),
            value: value.map(|value| value.to_string()),
        },
    );
}

fn show_main_window(app: &AppHandle, tab: Option<&str>) {
    if let Some(window) = app.get_window("main") {
        let _ = window.show();
        let _ = window.set_focus();
    }
    if let Some(tab) = tab {
        let _ = app.emit_all("select-tab", tab.to_string());
    }
}

fn handle_tray_menu_event(app: &AppHandle, id: &str) {
    match id {
        "open_app" => show_main_window(app, None),
        "open_music" => show_main_window(app, Some("music")),
        "open_countdown" => show_main_window(app, Some("countdown")),
        "quit" => app.exit(0),
        "pomodoro_start" => emit_tray_action(app, "pomodoro_start", None),
        "pomodoro_pause" => emit_tray_action(app, "pomodoro_pause", None),
        "pomodoro_reset" => emit_tray_action(app, "pomodoro_reset", None),
        "break_start" => emit_tray_action(app, "break_start", None),
        "break_skip" => emit_tray_action(app, "break_skip", None),
        "countdown_start" => emit_tray_action(app, "countdown_start", None),
        "countdown_pause" => emit_tray_action(app, "countdown_pause", None),
        "countdown_reset" => emit_tray_action(app, "countdown_reset", None),
        "music_play_pause" => emit_tray_action(app, "music_play_pause", None),
        "music_previous" => emit_tray_action(app, "music_previous", None),
        "music_next" => emit_tray_action(app, "music_next", None),
        "focus_sound_off" => emit_tray_action(app, "focus_sound", Some("off")),
        "focus_sound_white" => emit_tray_action(app, "focus_sound", Some("white")),
        "focus_sound_rain" => emit_tray_action(app, "focus_sound", Some("rain")),
        "focus_sound_brown" => emit_tray_action(app, "focus_sound", Some("brown")),
        _ => {}
    }
}

struct BackendProcess {
    _child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

impl BackendProcess {
    fn spawn(resource_dir: Option<PathBuf>) -> Result<Self, String> {
        let script_path = locate_backend_script(resource_dir)?;

        let mut child = Command::new("python3")
            .arg("-u")
            .arg(script_path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .map_err(|err| format!("Failed to spawn backend: {err}"))?;

        let stdin = child.stdin.take().ok_or("Failed to open backend stdin")?;
        let stdout = child.stdout.take().ok_or("Failed to open backend stdout")?;

        Ok(Self {
            _child: child,
            stdin,
            stdout: BufReader::new(stdout),
        })
    }

    fn send(&mut self, payload: serde_json::Value) -> Result<serde_json::Value, String> {
        let payload = serde_json::to_string(&payload)
            .map_err(|err| format!("Failed to serialize payload: {err}"))?;

        writeln!(self.stdin, "{payload}")
            .map_err(|err| format!("Failed to write to backend: {err}"))?;

        self.stdin
            .flush()
            .map_err(|err| format!("Failed to flush backend stdin: {err}"))?;

        let mut response = String::new();
        let bytes = self
            .stdout
            .read_line(&mut response)
            .map_err(|err| format!("Failed to read backend response: {err}"))?;

        if bytes == 0 {
            return Err("Backend closed stdout".to_string());
        }

        serde_json::from_str(response.trim())
            .map_err(|err| format!("Failed to decode backend response: {err}"))
    }
}

struct BackendState {
    process: Mutex<BackendProcess>,
    resource_dir: Option<PathBuf>,
}

impl BackendState {
    fn new(resource_dir: Option<PathBuf>) -> Result<Self, String> {
        Ok(Self {
            process: Mutex::new(BackendProcess::spawn(resource_dir.clone())?),
            resource_dir,
        })
    }
}

#[tauri::command]
fn backend_request(
    payload: serde_json::Value,
    state: tauri::State<'_, BackendState>,
) -> Result<serde_json::Value, String> {
    let mut process = state
        .process
        .lock()
        .map_err(|_| "Backend process lock poisoned".to_string())?;

    match process.send(payload.clone()) {
        Ok(res) => Ok(res),
        Err(_) => {
            // restart backend automatically
            *process = BackendProcess::spawn(state.resource_dir.clone())?;
            process.send(payload)
        }
    }
}

#[tauri::command]
fn sync_menu_state(
    payload: MenuSyncPayload,
    app: AppHandle,
    tray_state: State<'_, TrayState>,
) -> Result<(), String> {
    let mut state = tray_state
        .menu
        .lock()
        .map_err(|_| "Tray state lock poisoned".to_string())?;
    sync_tray_state(&app, &mut state, &payload)
}

#[tauri::command]
fn notify_session_complete(mode: String, app: AppHandle) -> Result<(), String> {
    let (title, body) = match mode.as_str() {
        "work" => ("🍅 Work session complete", "Time to take a break."),
        "break" => ("☕ Break finished", "Ready to focus again?"),
        _ => return Err("Unsupported session mode".to_string()),
    };

    Notification::new(&app.config().tauri.bundle.identifier)
        .title(title)
        .body(body)
        .show()
        .map_err(|err| format!("Failed to send notification: {err}"))
}

/// Resolve backend/app.py path for:
///  - dev mode
///  - packaged builds
fn locate_backend_script(resource_dir: Option<PathBuf>) -> Result<PathBuf, String> {
    // try relative paths walking upward
    let mut current = std::env::current_dir()
        .map_err(|err| format!("Failed to resolve working directory: {err}"))?;

    loop {
        let candidate = current.join("backend").join("app.py");
        if candidate.exists() {
            return Ok(candidate);
        }
        if !current.pop() {
            break;
        }
    }

    // fallback to bundled resource dir
    if let Some(resource_dir) = resource_dir {
        let packaged = resource_dir.join("backend").join("app.py");
        if packaged.exists() {
            return Ok(packaged);
        }
    }

    Err("Unable to locate backend/app.py".to_string())
}

fn main() {
    let context = tauri::generate_context!();

    // Tauri 1.x: Env is NOT stored in Context
    let env = Env::default();
    let resource_dir = tauri::api::path::resource_dir(
        context.package_info(),
        &env,
    );
    let initial_presentation = MenuPresentation {
        mode: MenuMode::Idle,
        play_pause_label: "▶ Play".to_string(),
        play_pause_enabled: false,
        previous_enabled: false,
        next_enabled: false,
        focus_sound: "off".to_string(),
        countdown_running: false,
        countdown_active: false,
    };
    let tray_menu = build_tray_menu(&initial_presentation);
    let tray_icon = Icon::Rgba {
        rgba: vec![0, 0, 0, 0],
        width: 1,
        height: 1,
    };
    let mut tray = SystemTray::new()
        .with_icon(tray_icon)
        .with_menu(tray_menu);
    #[cfg(target_os = "macos")]
    {
        tray = tray.with_title("🍅 Ready").with_menu_on_left_click(true);
    }

    tauri::Builder::default()
        .setup(|app| {
            #[cfg(target_os = "macos")]
            {
                // Ensure the macOS window stays transparent and frameless-style while
                // keeping native traffic lights available via the config settings.
                if let Some(window) = app.get_window("main") {
                    let _ = window.set_decorations(true);
                }
            }
            Ok(())
        })
        .manage(BackendState::new(resource_dir).expect("Unable to start backend"))
        .manage(TrayState::default())
        .invoke_handler(tauri::generate_handler![
            backend_request,
            get_system_media_state,
            control_system_media,
            sync_menu_state,
            notify_session_complete
        ])
        .system_tray(tray)
        .on_system_tray_event(|app, event| {
            if let SystemTrayEvent::MenuItemClick { id, .. } = event {
                handle_tray_menu_event(app, id.as_ref());
            }
        })
        .on_window_event(|event: GlobalWindowEvent| {
            if let WindowEvent::CloseRequested { api, .. } = event.event() {
                if let Some(window) = event.window().app_handle().get_window("main") {
                    let _ = window.hide();
                }
                api.prevent_close();
            }
        })
        .run(context)
        .expect("error while running tauri application");
}

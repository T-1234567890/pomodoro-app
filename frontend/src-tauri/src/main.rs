#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::Mutex;

use tauri::Env;

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

    tauri::Builder::default()
        .manage(BackendState::new(resource_dir).expect("Unable to start backend"))
        .invoke_handler(tauri::generate_handler![
            backend_request,
            get_system_media_state,
            control_system_media
        ])
        .run(context)
        .expect("error while running tauri application");
}

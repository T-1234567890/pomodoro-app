use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemMediaState {
    pub available: bool,
    pub title: String,
    pub artist: Option<String>,
    pub source: String,
    pub is_playing: bool,
    pub supports_play_pause: bool,
    pub supports_next: bool,
    pub supports_previous: bool,
}

#[tauri::command]
pub fn get_system_media_state() -> SystemMediaState {
    #[cfg(target_os = "macos")]
    {
        if let Some(player) = resolve_media_player() {
            let (title, artist, is_playing) = query_player_metadata(&player)
                .unwrap_or_else(|| ("".to_string(), None, false));
            return SystemMediaState {
                available: true,
                title,
                artist,
                source: player,
                is_playing,
                supports_play_pause: true,
                supports_next: true,
                supports_previous: true,
            };
        }
    }
    SystemMediaState {
        available: false,
        title: String::new(),
        artist: None,
        source: String::new(),
        is_playing: false,
        supports_play_pause: false,
        supports_next: false,
        supports_previous: false,
    }
}

#[tauri::command]
pub fn control_system_media(action: String) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        return control_media_action(&action).ok_or_else(|| "Media control unavailable".to_string());
    }
    Err("Media control not supported on this platform".to_string())
}

#[cfg(target_os = "macos")]
pub fn resolve_media_player() -> Option<String> {
    if is_process_running("Music") {
        Some("Music".to_string())
    } else if is_process_running("Spotify") {
        Some("Spotify".to_string())
    } else {
        None
    }
}

#[cfg(target_os = "macos")]
fn query_player_metadata(player: &str) -> Option<(String, Option<String>, bool)> {
    let script = format!(
        "tell application \"{}\" to return (name of current track) & \"||\" & (artist of current track) & \"||\" & (player state as string)",
        player
    );
    let output = run_osascript(&script)?;
    let parts: Vec<&str> = output.split("||").collect();
    let title = parts.get(0).unwrap_or(&"").to_string();
    let artist = parts.get(1).map(|value| value.to_string()).filter(|value| !value.is_empty());
    let is_playing = parts
        .get(2)
        .map(|state| state.trim().eq_ignore_ascii_case("playing"))
        .unwrap_or(false);
    Some((title, artist, is_playing))
}

#[cfg(target_os = "macos")]
pub fn control_media_action(action: &str) -> Option<()> {
    let player = resolve_media_player()?;
    let command = match action {
        "play_pause" => "playpause",
        "previous" => "previous track",
        "next" => "next track",
        _ => return None,
    };
    let script = format!("tell application \"{}\" to {}", player, command);
    run_osascript(&script).map(|_| ())
}

#[cfg(target_os = "macos")]
fn is_process_running(process_name: &str) -> bool {
    let script = format!(
        "tell application \"System Events\" to (name of processes) contains \"{}\"",
        process_name
    );
    run_osascript(&script)
        .map(|output| output.trim().eq_ignore_ascii_case("true"))
        .unwrap_or(false)
}

#[cfg(target_os = "macos")]
fn run_osascript(script: &str) -> Option<String> {
    let output = std::process::Command::new("osascript")
        .args(["-e", script])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod status_bar;
mod system_media;
mod timer;

use tauri::{AppHandle, Manager, WindowEvent};
use tauri_plugin_notification::NotificationExt;

use system_media::{control_system_media, get_system_media_state};
use timer::{
    countdown_pause, countdown_reset, countdown_set_duration, countdown_start, focus_sound_set,
    pomodoro_pause, pomodoro_reset, pomodoro_skip_break, pomodoro_start, pomodoro_start_break,
    pomodoro_update_settings, timer_get_state, TimerEngine, TimerHandle,
};

#[tauri::command]
fn notify_session_complete(mode: String, app: AppHandle) -> Result<(), String> {
    let (title, body) = match mode.as_str() {
        "work" => ("🍅 Work session complete", "Time to take a break."),
        "break" => ("☕ Break finished", "Ready to focus again?"),
        _ => return Err("Unsupported session mode".into()),
    };

    app.notification()
        .builder()
        .title(title)
        .body(body)
        .show()
        .map_err(|e| e.to_string())
}

pub(crate) fn notify_session_complete_for_engine(
    mode: String,
    app: AppHandle,
) -> Result<(), String> {
    notify_session_complete(mode, app)
}

fn main() {
    let context = tauri::generate_context!();
    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        .setup(|app| {
            let engine = TimerEngine::new(app.handle().clone());
            TimerEngine::start(engine.clone());
            app.manage(TimerHandle(engine.clone()));
            #[cfg(target_os = "macos")]
            {
                status_bar::init(app.handle().clone(), engine);
            }
            engine.emit_snapshot();
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            notify_session_complete,
            timer_get_state,
            pomodoro_update_settings,
            pomodoro_start,
            pomodoro_pause,
            pomodoro_reset,
            pomodoro_start_break,
            pomodoro_skip_break,
            countdown_start,
            countdown_pause,
            countdown_reset,
            countdown_set_duration,
            focus_sound_set,
            get_system_media_state,
            control_system_media,
        ])
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                window.hide().ok();
                api.prevent_close();
            }
        })
        .run(context)
        .expect("error while running tauri application");
}

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::Mutex;

use tauri::{
    api::notification::Notification,
    AppHandle, CustomMenuItem, Env, GlobalWindowEvent, Manager,
    SystemTray, SystemTrayEvent, SystemTrayMenu, SystemTrayMenuItem, WindowEvent,
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

#[derive(Default)]
struct TrayState {
    menu: Mutex<()>,
}

#[tauri::command]
fn notify_session_complete(mode: String, app: AppHandle) -> Result<(), String> {
    let (title, body) = match mode.as_str() {
        "work" => ("🍅 Work session complete", "Time to take a break."),
        "break" => ("☕ Break finished", "Ready to focus again?"),
        _ => return Err("Unsupported session mode".into()),
    };

    Notification::new(&app.config().tauri.bundle.identifier)
        .title(title)
        .body(body)
        .show()
        .map_err(|e| e.to_string())
}

#[cfg(target_os = "macos")]
use window_vibrancy::{apply_vibrancy, NSVisualEffectMaterial};

fn main() {
    let context = tauri::generate_context!();
    let env = Env::default();
    let resource_dir = tauri::api::path::resource_dir(context.package_info(), &env);

    let tray_menu = SystemTrayMenu::new()
        .add_item(CustomMenuItem::new("open", "Open App"))
        .add_native_item(SystemTrayMenuItem::Separator)
        .add_item(CustomMenuItem::new("quit", "Quit"));

    let tray = SystemTray::new()
        // .with_icon(tauri::Icon::Raw(vec![0, 0, 0, 0]))
        .with_menu(tray_menu);

    tauri::Builder::default()
        .setup(|app| {
            #[cfg(target_os = "macos")]
            {
                if let Some(window) = app.get_window("main") {
                    #[cfg(target_os = "macos")]
                    apply_vibrancy(&window, NSVisualEffectMaterial::UnderWindowBackground, None, None)
                        .expect("Unsupported platform! 'apply_vibrancy' is only supported on macOS");
                }
            }
            Ok(())
        })
        .manage(TrayState::default())
        .invoke_handler(tauri::generate_handler![notify_session_complete])
        .system_tray(tray)
        .on_system_tray_event(|app, event| {
            if let SystemTrayEvent::MenuItemClick { id, .. } = event {
                match id.as_str() {
                    "open" => {
                        if let Some(w) = app.get_window("main") {
                            let _ = w.show();
                            let _ = w.set_focus();
                        }
                    }
                    "quit" => app.exit(0),
                    _ => {}
                }
            }
        })
        .on_window_event(|event: GlobalWindowEvent| {
            if let WindowEvent::CloseRequested { api, .. } = event.event() {
                event.window().hide().ok();
                api.prevent_close();
            }
        })
        .run(context)
        .expect("error while running tauri application");
}

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

// Migration boundary: this Tauri shell is intentionally minimal while the
// Python backend bridge stabilizes. Commands will be added once the IPC
// contract is finalized.

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::Mutex;

use tauri::Env;

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
        .invoke_handler(tauri::generate_handler![backend_request])
        .run(context)
        .expect("error while running tauri application");
}

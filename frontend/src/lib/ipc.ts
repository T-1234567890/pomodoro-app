export type BackendRequest = {
  action: string;
  [key: string]: unknown;
};

export type BackendResponse = {
  ok: boolean;
  error?: string;
  [key: string]: unknown;
};

// NOTE: This is a stub for the JSON IPC bridge. The Tauri shell will spawn
// backend/app.py as a child process and exchange JSON lines.
export async function send(request: BackendRequest): Promise<BackendResponse> {
  // TODO: Replace with @tauri-apps/api/shell or a custom command to run
  // the Python backend and stream JSON messages.
  console.info('IPC stub ->', request);
  return { ok: false, error: 'IPC bridge not wired yet.' };
}

export async function getState(): Promise<BackendResponse> {
  return send({ action: 'get_state' });
}

export async function startTimer(): Promise<BackendResponse> {
  return send({ action: 'start_timer' });
}

export async function pauseTimer(): Promise<BackendResponse> {
  return send({ action: 'pause_timer' });
}

export async function resetTimer(): Promise<BackendResponse> {
  return send({ action: 'reset_timer' });
}

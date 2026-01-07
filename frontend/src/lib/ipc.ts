import { invoke } from '@tauri-apps/api/tauri';

export type BackendRequest = {
  action: string;
  [key: string]: unknown;
};

export type BackendResponse = {
  ok: boolean;
  error?: string;
  [key: string]: unknown;
};

export async function send(request: BackendRequest): Promise<BackendResponse> {
  return invoke('backend_request', { payload: request });
}

export async function getState(): Promise<BackendResponse> {
  return send({ action: 'get_current_state' });
}

export async function getStats(): Promise<BackendResponse> {
  return send({ action: 'get_stats' });
}

export async function startPomodoro(payload: {
  workMinutes?: number;
  breakMinutes?: number;
  longBreakMinutes?: number;
  interval?: number;
}): Promise<BackendResponse> {
  return send({
    action: 'start_pomodoro',
    work_minutes: payload.workMinutes,
    break_minutes: payload.breakMinutes,
    long_break: payload.longBreakMinutes,
    interval: payload.interval
  });
}

export async function pausePomodoro(): Promise<BackendResponse> {
  return send({ action: 'pause_pomodoro' });
}

export async function resetPomodoro(): Promise<BackendResponse> {
  return send({ action: 'reset_pomodoro' });
}

export async function setPreset(preset: string): Promise<BackendResponse> {
  return send({ action: 'set_preset', preset });
}

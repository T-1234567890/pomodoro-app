import { safeInvoke } from './tauri';

export type SystemMediaState = {
  available: boolean;
  title: string;
  artist: string | null;
  source: string;
  isPlaying: boolean;
  supportsPlayPause: boolean;
  supportsNext: boolean;
  supportsPrevious: boolean;
};

export async function getSystemMediaState(): Promise<SystemMediaState> {
  const state = await safeInvoke<SystemMediaState>('get_system_media_state');
  if (!state) {
    throw new Error('System media state unavailable');
  }
  return state;
}

export async function controlSystemMedia(action: 'play_pause' | 'next' | 'previous') {
  return safeInvoke('control_system_media', { action });
}

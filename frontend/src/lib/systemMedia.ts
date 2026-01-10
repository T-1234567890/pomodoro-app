import { invoke } from '@tauri-apps/api/tauri';

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
  return invoke('get_system_media_state');
}

export async function controlSystemMedia(action: 'play_pause' | 'next' | 'previous') {
  return invoke('control_system_media', { action });
}

import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';

const getTauriGlobal = () => {
  if (typeof window === 'undefined') {
    return undefined;
  }

  const tauriWindow = window as Window & {
    __TAURI__?: unknown;
    __TAURI_INTERNALS__?: unknown;
  };

  return tauriWindow.__TAURI__ ?? tauriWindow.__TAURI_INTERNALS__;
};

const isTauriAvailable = () => getTauriGlobal() !== undefined;

export const safeInvoke = async <T>(
  command: string,
  args?: Record<string, unknown>
): Promise<T | undefined> => {
  if (!isTauriAvailable()) {
    return undefined;
  }

  return invoke<T>(command, args);
};

export const safeListen = async <T>(
  event: string,
  handler: Parameters<typeof listen<T>>[1]
): Promise<() => void> => {
  if (!isTauriAvailable()) {
    return () => undefined;
  }

  return listen<T>(event, handler);
};

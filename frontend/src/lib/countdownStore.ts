import { writable } from 'svelte/store';
import { safeInvoke } from './tauri';

const STORAGE_KEY = 'countdown_duration_minutes';
const MINUTES_MIN = 1;
const MINUTES_MAX = 180;

export type CountdownState = {
  durationMinutes: number;
  remainingSeconds: number;
  running: boolean;
};

const clampMinutes = (value: number, fallback: number) => {
  if (!Number.isFinite(value)) {
    return fallback;
  }

  return Math.min(MINUTES_MAX, Math.max(MINUTES_MIN, Math.round(value)));
};

const createCountdownStore = () => {
  const initialMinutes = 25;
  let durationMinutes = initialMinutes;
  let remainingSeconds = initialMinutes * 60;
  let running = false;
  let initialized = false;

  const { subscribe, set } = writable<CountdownState>({
    durationMinutes,
    remainingSeconds,
    running
  });

  const publish = () => {
    set({ durationMinutes, remainingSeconds, running });
  };

  const startCountdown = async () => {
    await safeInvoke('countdown_start');
  };

  const pauseCountdown = async () => {
    await safeInvoke('countdown_pause');
  };

  const resetCountdown = async () => {
    await safeInvoke('countdown_reset');
  };

  const setDurationMinutes = (value: number) => {
    durationMinutes = clampMinutes(value, durationMinutes);
    remainingSeconds = durationMinutes * 60;
    running = false;
    localStorage.setItem(STORAGE_KEY, String(durationMinutes));
    void safeInvoke('countdown_set_duration', { minutes: durationMinutes });
    publish();
  };

  const initializeCountdown = (defaultMinutes = initialMinutes) => {
    if (initialized) {
      return;
    }

    initialized = true;
    const storedValue = localStorage.getItem(STORAGE_KEY);
    if (storedValue) {
      const parsedValue = Number.parseInt(storedValue, 10);
      if (Number.isFinite(parsedValue)) {
        durationMinutes = clampMinutes(parsedValue, defaultMinutes);
        remainingSeconds = durationMinutes * 60;
      }
    } else {
      durationMinutes = clampMinutes(defaultMinutes, defaultMinutes);
      remainingSeconds = durationMinutes * 60;
    }
    void safeInvoke('countdown_set_duration', { minutes: durationMinutes });
    publish();
  };

  return {
    subscribe,
    startCountdown,
    pauseCountdown,
    resetCountdown,
    setDurationMinutes,
    initializeCountdown,
    applyBackendState: (state: CountdownState) => {
      durationMinutes = state.durationMinutes;
      remainingSeconds = state.remainingSeconds;
      running = state.running;
      publish();
    },
    getSnapshot: () => ({ durationMinutes, remainingSeconds, running })
  };
};

export const countdownState = createCountdownStore();

export const startCountdown = countdownState.startCountdown;
export const pauseCountdown = countdownState.pauseCountdown;
export const resetCountdown = countdownState.resetCountdown;
export const setCountdownDuration = countdownState.setDurationMinutes;
export const initializeCountdown = countdownState.initializeCountdown;
export const applyCountdownState = countdownState.applyBackendState;
export const getCountdownSnapshot = countdownState.getSnapshot;

export const COUNTDOWN_MINUTES_MIN = MINUTES_MIN;
export const COUNTDOWN_MINUTES_MAX = MINUTES_MAX;

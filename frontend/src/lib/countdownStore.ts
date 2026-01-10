import { writable } from 'svelte/store';

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
  let intervalId: ReturnType<typeof setInterval> | null = null;
  let initialized = false;

  const { subscribe, set } = writable<CountdownState>({
    durationMinutes,
    remainingSeconds,
    running
  });

  const publish = () => {
    set({ durationMinutes, remainingSeconds, running });
  };

  const stopInterval = () => {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
  };

  const tick = () => {
    if (remainingSeconds <= 0) {
      remainingSeconds = 0;
      running = false;
      stopInterval();
      publish();
      return;
    }

    remainingSeconds -= 1;
    if (remainingSeconds <= 0) {
      remainingSeconds = 0;
      running = false;
      stopInterval();
    }
    publish();
  };

  const startCountdown = () => {
    if (running) {
      return;
    }

    if (remainingSeconds <= 0) {
      remainingSeconds = durationMinutes * 60;
    }

    running = true;
    stopInterval();
    intervalId = setInterval(tick, 1000);
    publish();
  };

  const pauseCountdown = () => {
    if (!running) {
      return;
    }

    running = false;
    stopInterval();
    publish();
  };

  const resetCountdown = () => {
    running = false;
    stopInterval();
    remainingSeconds = durationMinutes * 60;
    publish();
  };

  const setDurationMinutes = (value: number) => {
    durationMinutes = clampMinutes(value, durationMinutes);
    remainingSeconds = durationMinutes * 60;
    running = false;
    stopInterval();
    localStorage.setItem(STORAGE_KEY, String(durationMinutes));
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
    publish();
  };

  return {
    subscribe,
    startCountdown,
    pauseCountdown,
    resetCountdown,
    setDurationMinutes,
    initializeCountdown,
    getSnapshot: () => ({ durationMinutes, remainingSeconds, running })
  };
};

export const countdownState = createCountdownStore();

export const startCountdown = countdownState.startCountdown;
export const pauseCountdown = countdownState.pauseCountdown;
export const resetCountdown = countdownState.resetCountdown;
export const setCountdownDuration = countdownState.setDurationMinutes;
export const initializeCountdown = countdownState.initializeCountdown;
export const getCountdownSnapshot = countdownState.getSnapshot;

export const COUNTDOWN_MINUTES_MIN = MINUTES_MIN;
export const COUNTDOWN_MINUTES_MAX = MINUTES_MAX;

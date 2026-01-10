<script>
  import { onDestroy, onMount } from 'svelte';

  const STORAGE_KEY = 'countdown_duration_minutes';
  const MINUTES_MIN = 1;
  const MINUTES_MAX = 180;

  export let defaultMinutes = 25;

  let durationMinutes = defaultMinutes;
  let durationInput = String(defaultMinutes);
  let remainingSeconds = durationMinutes * 60;
  let intervalId = null;

  const formatTime = (totalSeconds) => {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;

    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  };

  const clampMinutes = (value) => {
    if (!Number.isFinite(value)) {
      return defaultMinutes;
    }

    return Math.min(MINUTES_MAX, Math.max(MINUTES_MIN, Math.round(value)));
  };

  const applyDurationMinutes = (value) => {
    durationMinutes = clampMinutes(value);
    durationInput = String(durationMinutes);
    pauseCountdown();
    remainingSeconds = durationMinutes * 60;
    localStorage.setItem(STORAGE_KEY, String(durationMinutes));
  };

  const handleDurationChange = (event) => {
    const nextValue = Number.parseInt(event.currentTarget.value, 10);

    if (!Number.isFinite(nextValue)) {
      durationInput = String(durationMinutes);
      return;
    }

    applyDurationMinutes(nextValue);
  };

  const tick = () => {
    if (remainingSeconds <= 0) {
      remainingSeconds = 0;
      pauseCountdown();
      return;
    }

    remainingSeconds -= 1;

    if (remainingSeconds <= 0) {
      remainingSeconds = 0;
      pauseCountdown();
    }
  };

  function startCountdown() {
    if (intervalId !== null) {
      return;
    }

    if (remainingSeconds <= 0) {
      remainingSeconds = 0;
    }

    intervalId = setInterval(tick, 1000);
  }

  function pauseCountdown() {
    if (intervalId === null) {
      return;
    }

    clearInterval(intervalId);
    intervalId = null;
  }

  function resetCountdown() {
    pauseCountdown();
    remainingSeconds = durationMinutes * 60;
  }

  onMount(() => {
    const storedValue = localStorage.getItem(STORAGE_KEY);
    if (storedValue) {
      const parsedValue = Number.parseInt(storedValue, 10);
      if (Number.isFinite(parsedValue)) {
        durationMinutes = clampMinutes(parsedValue);
        durationInput = String(durationMinutes);
        remainingSeconds = durationMinutes * 60;
      }
    }
  });

  onDestroy(() => {
    pauseCountdown();
  });
</script>

<div class="countdown-timer">
  <label class="duration-input">
    <span>Duration (minutes)</span>
    <input
      type="number"
      min={MINUTES_MIN}
      max={MINUTES_MAX}
      step="1"
      inputmode="numeric"
      class="duration-field"
      bind:value={durationInput}
      on:change={handleDurationChange}
      aria-label="Countdown duration in minutes"
    />
  </label>
  <div class="countdown-display">{formatTime(remainingSeconds)}</div>
  <div class="countdown-actions">
    <button type="button" on:click={startCountdown}>Start</button>
    <button type="button" on:click={pauseCountdown}>Pause</button>
    <button type="button" on:click={resetCountdown}>Reset</button>
  </div>
</div>

<style>
  .countdown-timer {
    display: grid;
    gap: 0.75rem;
  }

  .duration-input {
    display: grid;
    gap: 0.35rem;
    font-size: 0.85rem;
    color: rgba(255, 255, 255, 0.7);
  }

  :global(body.light) .duration-input {
    color: rgba(15, 23, 42, 0.7);
  }

  .duration-field {
    width: 100%;
    padding: 0.5rem 0.75rem;
    border-radius: 0.75rem;
    border: 1px solid rgba(255, 255, 255, 0.18);
    background: rgba(255, 255, 255, 0.08);
    color: inherit;
  }

  :global(body.light) .duration-field {
    border: 1px solid rgba(15, 23, 42, 0.12);
    background: rgba(15, 23, 42, 0.04);
  }

  .countdown-display {
    font-size: 2rem;
    font-variant-numeric: tabular-nums;
  }

  .countdown-actions {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }
</style>

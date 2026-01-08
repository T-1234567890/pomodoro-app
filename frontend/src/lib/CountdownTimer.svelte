<script>
  import { onDestroy } from 'svelte';

  export let duration = 25 * 60;

  let remainingSeconds = duration;
  let intervalId = null;

  const formatTime = (totalSeconds) => {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;

    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
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
    remainingSeconds = duration;
  }

  onDestroy(() => {
    pauseCountdown();
  });
</script>

<div class="countdown-timer">
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

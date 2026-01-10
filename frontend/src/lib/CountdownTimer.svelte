<script>
  import {
    COUNTDOWN_MINUTES_MAX,
    COUNTDOWN_MINUTES_MIN,
    countdownState,
    pauseCountdown,
    resetCountdown,
    setCountdownDuration,
    startCountdown
  } from './countdownStore';

  const RING_RADIUS = 96;
  const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;

  let durationInput = '25';

  const formatTime = (totalSeconds) => {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;

    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
  };

  const handleDurationChange = (event) => {
    const nextValue = Number.parseInt(event.currentTarget.value, 10);

    if (!Number.isFinite(nextValue)) {
      durationInput = String($countdownState.durationMinutes);
      return;
    }

    setCountdownDuration(nextValue);
  };

  $: durationInput = String($countdownState.durationMinutes);
  $: totalSeconds = $countdownState.durationMinutes * 60;
  $: progressRatio = totalSeconds > 0 ? $countdownState.remainingSeconds / totalSeconds : 0;
  $: ringOffset = RING_CIRCUMFERENCE * (1 - progressRatio);
</script>

<div class="countdown-timer">
  <div class="countdown-ring">
    <svg viewBox="0 0 220 220" class="ring-graphic" aria-hidden="true">
      <circle class="ring-track" cx="110" cy="110" r={RING_RADIUS} />
      <circle
        class="ring-progress"
        cx="110"
        cy="110"
        r={RING_RADIUS}
        stroke-dasharray={RING_CIRCUMFERENCE}
        stroke-dashoffset={ringOffset}
      />
    </svg>
    <div class="countdown-center">
      <span class="countdown-label">Remaining</span>
      <span class="countdown-display">{formatTime($countdownState.remainingSeconds)}</span>
    </div>
  </div>

  <div class="countdown-actions" role="group" aria-label="Countdown controls">
    <button type="button" on:click={startCountdown}>Start</button>
    <button type="button" on:click={pauseCountdown}>Pause</button>
    <button type="button" on:click={resetCountdown}>Reset</button>
  </div>

  <label class="duration-input">
    <span>Duration (minutes)</span>
    <input
      type="number"
      min={COUNTDOWN_MINUTES_MIN}
      max={COUNTDOWN_MINUTES_MAX}
      step="1"
      inputmode="numeric"
      class="duration-field"
      bind:value={durationInput}
      on:change={handleDurationChange}
      aria-label="Countdown duration in minutes"
    />
  </label>
</div>

<style>
  .countdown-timer {
    display: grid;
    gap: 1.5rem;
    justify-items: center;
  }

  .countdown-ring {
    position: relative;
    width: min(380px, 78vw);
    aspect-ratio: 1;
    display: grid;
    place-items: center;
  }

  .ring-graphic {
    width: 100%;
    height: 100%;
    transform: rotate(-90deg);
  }

  .ring-track {
    fill: none;
    stroke: rgba(255, 255, 255, 0.45);
    stroke-width: 16;
    stroke-linecap: round;
  }

  :global(html[data-theme='dark']) .ring-track {
    stroke: rgba(15, 24, 40, 0.55);
  }

  .ring-progress {
    fill: none;
    stroke: rgba(90, 140, 245, 0.85);
    stroke-width: 16;
    stroke-linecap: round;
    transition: stroke-dashoffset 1s linear;
  }

  :global(html[data-theme='dark']) .ring-progress {
    stroke: rgba(122, 164, 255, 0.9);
  }

  .countdown-center {
    position: absolute;
    inset: 0;
    display: grid;
    align-content: center;
    justify-items: center;
    gap: 0.35rem;
    text-align: center;
    padding: 1rem;
  }

  .countdown-label {
    font-size: 0.75rem;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    color: var(--card-note-text);
  }

  .countdown-display {
    font-size: clamp(2.4rem, 6vw, 3.5rem);
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    letter-spacing: 0.08em;
    color: var(--app-text);
  }

  .countdown-actions {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
    justify-content: center;
  }

  .countdown-actions button {
    border-radius: 12px;
    padding: 0.75rem 2rem;
    border: 1px solid var(--secondary-border);
    background: var(--secondary-bg);
    color: var(--secondary-text);
    font-size: 1rem;
    cursor: pointer;
  }

  .countdown-actions button:first-child {
    background: var(--primary-bg);
    border-color: var(--primary-border);
    color: var(--primary-text);
  }

  .duration-field {
    width: 100%;
    padding: 0.65rem 2.5rem 0.65rem 1rem;
    border-radius: 999px;
    border: 1px solid var(--input-border);
    background: var(--input-bg);
    color: var(--input-text);
    font-size: 1rem;
    line-height: 1.2;
    min-height: 48px;
    box-sizing: border-box;
    caret-color: var(--input-text);
  }

  .duration-field::placeholder {
    color: var(--card-note-text);
    opacity: 1;
  }

  .duration-input {
    display: grid;
    gap: 0.35rem;
    font-size: 0.9rem;
    color: var(--form-row-text);
    width: min(300px, 84vw);
    text-align: center;
  }
</style>

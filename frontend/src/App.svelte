<script lang="ts">
  import { onMount } from 'svelte';
  import styles from './App.module.css';

  const DEFAULT_MINUTES = 25;

  let durationMinutes = DEFAULT_MINUTES;
  let totalSeconds = DEFAULT_MINUTES * 60;
  let remainingSeconds = totalSeconds;
  let running = false;
  let intervalId: ReturnType<typeof setInterval> | null = null;

  const formatSeconds = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs
      .toString()
      .padStart(2, '0')}`;
  };

  const updateDurationFromInput = () => {
    if (!durationMinutes || durationMinutes < 1) {
      durationMinutes = 1;
    }
    totalSeconds = durationMinutes * 60;
    if (!running) {
      remainingSeconds = totalSeconds;
    } else if (remainingSeconds > totalSeconds) {
      remainingSeconds = totalSeconds;
    }
  };

  const tick = () => {
    remainingSeconds = Math.max(0, remainingSeconds - 1);
    if (remainingSeconds === 0) {
      pauseTimer();
    }
  };

  const startTimer = () => {
    if (running) {
      return;
    }
    if (remainingSeconds === 0) {
      remainingSeconds = totalSeconds;
    }
    running = true;
    intervalId = setInterval(tick, 1000);
  };

  const pauseTimer = () => {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
    running = false;
  };

  const resetTimer = () => {
    pauseTimer();
    totalSeconds = durationMinutes * 60;
    remainingSeconds = totalSeconds;
  };

  onMount(() => {
    return () => pauseTimer();
  });
</script>

<main class={styles.app}>
  <section class={styles.window}>
    <header class={styles.header}>
      <div>
        <p class={styles.kicker}>Pomodoro</p>
        <h1 class={styles.title}>Stay in flow</h1>
        <p class={styles.subtitle}>A calm space for focused sessions.</p>
      </div>

      <div class={styles.statusPill}>
        {running ? 'Live' : 'Ready'} · Pomodoro
      </div>
    </header>

    <!-- TIMER CARD -->
    <section class={styles.timerCard}>
      <div class={styles.timerMeta}>
        <p class={styles.timerLabel}>Focus timer</p>
        <p class={styles.timerCycle}>{durationMinutes} minute session</p>
      </div>

      <div class={styles.timerValue}>{formatSeconds(remainingSeconds)}</div>

      <div class={styles.timerActions}>
        <button class={styles.primaryButton} type="button" on:click={startTimer}>
          {running ? 'Running' : remainingSeconds === 0 ? 'Restart' : 'Start'}
        </button>

        <button class={styles.secondaryButton} type="button" on:click={pauseTimer}>
          Pause
        </button>

        <button class={styles.ghostButton} type="button" on:click={resetTimer}>
          Reset
        </button>
      </div>
    </section>

    <!-- SETTINGS + STATS GRID -->
    <section class={styles.grid}>

      <!-- PRESETS CARD -->
      <div class={styles.glassCard}>
        <h2 class={styles.cardTitle}>Timer settings</h2>

        <div class={styles.cardBody}>
          <label class={styles.formRow}>
            <span>Duration (minutes)</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={durationMinutes}
              on:input={updateDurationFromInput}
            />
          </label>
        </div>

        <p class={styles.cardNote}>
          Adjusting the duration updates the timer state in memory.
        </p>
      </div>

      <div class={styles.glassCard}>
        <h2 class={styles.cardTitle}>Session details</h2>

        <div class={styles.cardBody}>
          <p>Total session length: {formatSeconds(totalSeconds)}</p>
          <p>Time remaining: {formatSeconds(remainingSeconds)}</p>
          <p>Status: {running ? 'Counting down' : 'Paused'}</p>
        </div>

        <p class={styles.cardNote}>Timer updates every second while running.</p>
      </div>
    </section>
  </section>
</main>

<script lang="ts">
  import { onMount } from 'svelte';
  import styles from './App.module.css';
  import {
    getState,
    getStats,
    pausePomodoro,
    resetPomodoro,
    setPreset,
    startPomodoro,
    updateDurations
  } from './lib/ipc';

  //
  // ---- Types ----
  //
  type TimerState = {
    work_seconds: number;
    break_seconds: number;
    long_break_seconds: number;
    long_break_interval: number;
    remaining_seconds: number;
    running: boolean;
    is_break: boolean;
    break_kind: string;
    cycle_progress: number;
    mode: string;
    presets: string[];
  };

  type StatsState = {
    count: number;
    short_breaks: number;
    long_breaks: number;
    focus_seconds: number;
    break_seconds: number;
  };

  //
  // ---- Default UI State ----
  //
  let timerState: TimerState = {
    work_seconds: 25 * 60,
    break_seconds: 5 * 60,
    long_break_seconds: 15 * 60,
    long_break_interval: 4,
    remaining_seconds: 25 * 60,
    running: false,
    is_break: false,
    break_kind: 'short',
    cycle_progress: 0,
    mode: 'Focus',
    presets: []
  };

  let statsState: StatsState = {
    count: 0,
    short_breaks: 0,
    long_breaks: 0,
    focus_seconds: 0,
    break_seconds: 0
  };

  let presetChoice = 'Classic 25/5';
  let workMinutes = 25;
  let breakMinutes = 5;
  let longBreakMinutes = 15;
  let interval = 4;
  let isEditingDurations = false;

  //
  // ---- Helpers ----
  //
  const updateFromState = (state: TimerState, syncInputs = !isEditingDurations) => {
    timerState = state;
    if (syncInputs) {
      workMinutes = Math.round(state.work_seconds / 60);
      breakMinutes = Math.round(state.break_seconds / 60);
      longBreakMinutes = Math.round(state.long_break_seconds / 60);
      interval = state.long_break_interval;
    }
  };

  const refreshState = async () => {
    const response = await getState();
    if (response.ok && response.state) {
      updateFromState(response.state as TimerState);

      // ensure preset dropdown stays valid
      presetChoice = timerState.presets.includes(presetChoice)
        ? presetChoice
        : timerState.presets[0] ?? presetChoice;
    }
  };

  const refreshStats = async () => {
    const response = await getStats();
    if (response.ok && response.stats) {
      statsState = response.stats as StatsState;
    }
  };

  //
  // ---- Actions ----
  //
  const handleStart = async () => {
    isEditingDurations = false;
    const response = await startPomodoro({
      workMinutes,
      breakMinutes,
      longBreakMinutes,
      interval
    });
    if (response.ok && response.state) {
      updateFromState(response.state as TimerState, true);
    }
  };

  const handlePause = async () => {
    const response = await pausePomodoro();
    if (response.ok && response.state) {
      updateFromState(response.state as TimerState, true);
    }
  };

  const handleReset = async () => {
    const response = await resetPomodoro();
    if (response.ok && response.state) {
      updateFromState(response.state as TimerState, true);
    }
    await refreshStats();
  };

  const handlePreset = async (value: string) => {
    isEditingDurations = false;
    presetChoice = value;
    const response = await setPreset(value);
    if (response.ok && response.state) {
      updateFromState(response.state as TimerState, true);
    }
  };

  const commitDurations = async () => {
    if (!workMinutes || !breakMinutes || !longBreakMinutes || !interval) {
      return;
    }
    presetChoice = 'Custom';
    const response = await updateDurations({
      workMinutes,
      breakMinutes,
      longBreakMinutes,
      interval
    });
    if (response.ok && response.state) {
      updateFromState(response.state as TimerState, true);
    }
  };

  const handleDurationFocus = () => {
    isEditingDurations = true;
  };

  const handleDurationBlur = async () => {
    await commitDurations();
    isEditingDurations = false;
  };

  //
  // ---- Formatting ----
  //
  const formatSeconds = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs
      .toString()
      .padStart(2, '0')}`;
  };

  const formatMinutes = (seconds: number) => Math.floor(seconds / 60);

  const cycleLabel = () => {
    const total = timerState.long_break_interval;
    const current = (timerState.cycle_progress % total) + 1;
    return `Session ${current} of ${total}`;
  };

  //
  // ---- Poll Backend ----
  //
  onMount(() => {
    refreshState();
    refreshStats();

    const intervalId = setInterval(() => {
      refreshState();
      if (!timerState.running) {
        refreshStats();
      }
    }, 1000);

    return () => clearInterval(intervalId);
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
        {timerState.running ? 'Live' : 'Ready'} · {timerState.mode}
      </div>
    </header>

    <!-- TIMER CARD -->
    <section class={styles.timerCard}>
      <div class={styles.timerMeta}>
        <p class={styles.timerLabel}>{timerState.mode}</p>
        <p class={styles.timerCycle}>{cycleLabel()}</p>
      </div>

      <div class={styles.timerValue}>
        {formatSeconds(timerState.remaining_seconds)}
      </div>

      <div class={styles.timerActions}>
        <button class={styles.primaryButton} type="button" on:click={handleStart}>
          {timerState.running ? 'Resume' : 'Start'}
        </button>

        <button class={styles.secondaryButton} type="button" on:click={handlePause}>
          Pause
        </button>

        <button class={styles.ghostButton} type="button" on:click={handleReset}>
          Reset
        </button>
      </div>
    </section>

    <!-- SETTINGS + STATS GRID -->
    <section class={styles.grid}>

      <!-- PRESETS CARD -->
      <div class={styles.glassCard}>
        <h2 class={styles.cardTitle}>Session presets</h2>

        <div class={styles.cardBody}>
          <label class={styles.formRow}>
            <span>Preset</span>

            <select
              class={styles.select}
              bind:value={presetChoice}
              on:change={(event) => handlePreset(event.target.value)}
            >
              {#each (timerState?.presets ?? []) as preset}
                <option value={preset}>{preset}</option>
              {/each}
            </select>
          </label>

          <label class={styles.formRow}>
            <span>Work minutes</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={workMinutes}
              on:focus={handleDurationFocus}
              on:blur={handleDurationBlur}
            />
          </label>

          <label class={styles.formRow}>
            <span>Break minutes</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={breakMinutes}
              on:focus={handleDurationFocus}
              on:blur={handleDurationBlur}
            />
          </label>

          <label class={styles.formRow}>
            <span>Long break minutes</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={longBreakMinutes}
              on:focus={handleDurationFocus}
              on:blur={handleDurationBlur}
            />
          </label>

          <label class={styles.formRow}>
            <span>Long break every</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={interval}
              on:focus={handleDurationFocus}
              on:blur={handleDurationBlur}
            />
          </label>
        </div>

        <p class={styles.cardNote}>Changes sync with the Python backend.</p>
      </div>

      <!-- STATS CARD -->
      <div class={styles.glassCard}>
        <h2 class={styles.cardTitle}>Productivity summary</h2>

        <div class={styles.cardBody}>
          <p>Focus sessions: {statsState.count}</p>
          <p>Focus time: {formatMinutes(statsState.focus_seconds)}m</p>
          <p>Break time: {formatMinutes(statsState.break_seconds)}m</p>
          <p>
            Breaks: {statsState.short_breaks} short /
            {statsState.long_breaks} long
          </p>
        </div>

        <p class={styles.cardNote}>Stats update after each session.</p>
      </div>
    </section>
  </section>
</main>

<script lang="ts">
  import styles from './App.module.css';
  import { getState } from './lib/ipc';

  // Migration boundary: this UI is a shell only. Real data will come from the
  // Python backend once the IPC bridge is fully wired.
  const placeholderState = {
    mode: 'Focus',
    remaining: '25:00',
    cycle: 'Session 1 of 4',
    completed: 3,
    breaks: '2 short / 1 long'
  };

  void getState();
</script>

<main class={styles.app}>
  <section class={styles.window}>
    <header class={styles.header}>
      <div>
        <p class={styles.kicker}>Pomodoro</p>
        <h1 class={styles.title}>Stay in flow</h1>
        <p class={styles.subtitle}>A calm space for focused sessions.</p>
      </div>
      <div class={styles.statusPill}>Live · {placeholderState.mode}</div>
    </header>

    <section class={styles.timerCard}>
      <div class={styles.timerMeta}>
        <p class={styles.timerLabel}>{placeholderState.mode}</p>
        <p class={styles.timerCycle}>{placeholderState.cycle}</p>
      </div>
      <div class={styles.timerValue}>{placeholderState.remaining}</div>
      <div class={styles.timerActions}>
        <button class={styles.primaryButton} type="button">Start</button>
        <button class={styles.secondaryButton} type="button">Pause</button>
        <button class={styles.ghostButton} type="button">Reset</button>
      </div>
    </section>

    <section class={styles.grid}>
      <div class={styles.glassCard}>
        <h2 class={styles.cardTitle}>Session presets</h2>
        <div class={styles.cardBody}>
          <p>Classic 25/5</p>
          <p>Quick 15/3</p>
          <p>Deep 50/10</p>
        </div>
        <p class={styles.cardNote}>Preset selection will sync from Python.</p>
      </div>
      <div class={styles.glassCard}>
        <h2 class={styles.cardTitle}>Productivity summary</h2>
        <div class={styles.cardBody}>
          <p>Focus sessions: {placeholderState.completed}</p>
          <p>Breaks taken: {placeholderState.breaks}</p>
        </div>
        <p class={styles.cardNote}>Stats are placeholders until IPC wiring.</p>
      </div>
    </section>
  </section>
</main>

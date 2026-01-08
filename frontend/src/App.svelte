<script lang="ts">
  import { onMount } from 'svelte';
  import styles from './App.module.css';

  const DEFAULT_MINUTES = 25;
  const THEME_STORAGE_KEY = 'theme';

  type Theme = 'light' | 'dark';

  let durationMinutes = DEFAULT_MINUTES;
  let totalSeconds = DEFAULT_MINUTES * 60;
  let remainingSeconds = totalSeconds;
  let running = false;
  let intervalId: ReturnType<typeof setInterval> | null = null;
  let theme: Theme = 'light';
  let preferSystemTheme = true;
  let systemThemeMedia: MediaQueryList | null = null;
  let showMoreFunctions = false;

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

  const applyTheme = (value: Theme) => {
    theme = value;
    document.documentElement.dataset.theme = value;
  };

  const setTheme = (value: Theme, persist = false) => {
    applyTheme(value);
    if (persist) {
      localStorage.setItem(THEME_STORAGE_KEY, value);
    }
  };

  const toggleTheme = () => {
    preferSystemTheme = false;
    const nextTheme = theme === 'dark' ? 'light' : 'dark';
    setTheme(nextTheme, true);
  };

  onMount(() => {
    const storedTheme = localStorage.getItem(THEME_STORAGE_KEY);
    systemThemeMedia = window.matchMedia('(prefers-color-scheme: dark)');

    if (storedTheme === 'light' || storedTheme === 'dark') {
      preferSystemTheme = false;
      applyTheme(storedTheme);
    } else {
      applyTheme(systemThemeMedia.matches ? 'dark' : 'light');
    }

    const handleSystemThemeChange = (event: MediaQueryListEvent) => {
      if (preferSystemTheme) {
        applyTheme(event.matches ? 'dark' : 'light');
      }
    };

    systemThemeMedia.addEventListener('change', handleSystemThemeChange);

    return () => {
      pauseTimer();
      systemThemeMedia?.removeEventListener('change', handleSystemThemeChange);
    };
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

      <div class={styles.headerActions}>
        <div class={styles.statusPill}>
          {running ? 'Live' : 'Ready'} · Pomodoro
        </div>
        <button class={styles.themeToggle} type="button" on:click={toggleTheme}>
          {theme === 'dark' ? 'Light mode' : 'Dark mode'}
        </button>
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

    <div class={styles.moreFunctionsSection}>
      <button
        class={styles.moreFunctionsButton}
        type="button"
        aria-expanded={showMoreFunctions}
        aria-controls="more-functions-panel"
        on:click={() => (showMoreFunctions = true)}
      >
        More Functions
      </button>
    </div>

    {#if showMoreFunctions}
      <section
        id="more-functions-panel"
        class={`${styles.glassCard} ${styles.moreFunctionsPanel}`}
      >
        <div class={styles.moreFunctionsHeader}>
          <div>
            <h2 class={styles.cardTitle}>More functions</h2>
            <p class={styles.moreFunctionsSubtitle}>
              Future tools like music, analytics, and shortcuts will appear here.
            </p>
          </div>
          <button
            class={styles.moreFunctionsClose}
            type="button"
            on:click={() => (showMoreFunctions = false)}
          >
            Close
          </button>
        </div>

        <div class={styles.cardBody}>
          <p>Placeholder panel ready for upcoming features.</p>
        </div>
      </section>
    {/if}
  </section>
</main>

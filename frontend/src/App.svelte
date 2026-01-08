<script lang="ts">
  import { onMount } from 'svelte';
  import styles from './App.module.css';

  const SETTINGS_STORAGE_KEY = 'pomodoro_settings';
  const THEME_STORAGE_KEY = 'theme';

  type Theme = 'light' | 'dark';
  type SessionMode = 'work' | 'short_break' | 'long_break';

  type PomodoroSettings = {
    workMinutes: number;
    shortBreakMinutes: number;
    longBreakMinutes: number;
    sessionsBeforeLongBreak: number;
    autoLongBreak: boolean;
  };

  const defaultSettings: PomodoroSettings = {
    workMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
    autoLongBreak: true
  };

  let settings: PomodoroSettings = { ...defaultSettings };
  let mode: SessionMode = 'work';
  let totalSeconds = settings.workMinutes * 60;
  let remainingSeconds = totalSeconds;
  let running = false;
  let intervalId: ReturnType<typeof setInterval> | null = null;
  let theme: Theme = 'light';
  let preferSystemTheme = true;
  let systemThemeMedia: MediaQueryList | null = null;
  let cycleWorkSessions = 0;
  let totalWorkSessions = 0;
  let totalSessionsCompleted = 0;

  const modeLabels: Record<SessionMode, string> = {
    work: 'Work session',
    short_break: 'Short break',
    long_break: 'Long break'
  };

  const getDurationForMode = (targetMode: SessionMode) => {
    if (targetMode === 'work') {
      return settings.workMinutes;
    }
    if (targetMode === 'short_break') {
      return settings.shortBreakMinutes;
    }
    return settings.longBreakMinutes;
  };

  const formatSeconds = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs
      .toString()
      .padStart(2, '0')}`;
  };

  const sanitizeMinutes = (value: number, fallback: number) => {
    if (!value || Number.isNaN(value) || value < 1) {
      return fallback;
    }
    return Math.round(value);
  };

  const sanitizeSessionCount = (value: number, fallback: number) => {
    if (!value || Number.isNaN(value) || value < 1) {
      return fallback;
    }
    return Math.round(value);
  };

  const persistSettings = () => {
    localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(settings));
  };

  const applyCurrentSessionDuration = () => {
    totalSeconds = getDurationForMode(mode) * 60;
    if (!running) {
      remainingSeconds = totalSeconds;
    } else if (remainingSeconds > totalSeconds) {
      remainingSeconds = totalSeconds;
    }
  };

  const updateSettings = () => {
    settings = {
      ...settings,
      workMinutes: sanitizeMinutes(settings.workMinutes, defaultSettings.workMinutes),
      shortBreakMinutes: sanitizeMinutes(
        settings.shortBreakMinutes,
        defaultSettings.shortBreakMinutes
      ),
      longBreakMinutes: sanitizeMinutes(
        settings.longBreakMinutes,
        defaultSettings.longBreakMinutes
      ),
      sessionsBeforeLongBreak: sanitizeSessionCount(
        settings.sessionsBeforeLongBreak,
        defaultSettings.sessionsBeforeLongBreak
      )
    };
    persistSettings();
    applyCurrentSessionDuration();
  };

  const setMode = (nextMode: SessionMode) => {
    mode = nextMode;
    applyCurrentSessionDuration();
  };

  const handleSessionComplete = () => {
    totalSessionsCompleted += 1;
    if (mode === 'work') {
      totalWorkSessions += 1;
      cycleWorkSessions += 1;
      const shouldLongBreak =
        settings.autoLongBreak &&
        cycleWorkSessions >= settings.sessionsBeforeLongBreak;
      setMode(shouldLongBreak ? 'long_break' : 'short_break');
    } else {
      if (mode === 'long_break') {
        cycleWorkSessions = 0;
      }
      setMode('work');
    }
  };

  const tick = () => {
    remainingSeconds = Math.max(0, remainingSeconds - 1);
    if (remainingSeconds === 0) {
      pauseTimer();
      handleSessionComplete();
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
    applyCurrentSessionDuration();
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
    const storedSettings = localStorage.getItem(SETTINGS_STORAGE_KEY);
    systemThemeMedia = window.matchMedia('(prefers-color-scheme: dark)');

    if (storedTheme === 'light' || storedTheme === 'dark') {
      preferSystemTheme = false;
      applyTheme(storedTheme);
    } else {
      applyTheme(systemThemeMedia.matches ? 'dark' : 'light');
    }

    if (storedSettings) {
      try {
        const parsed = JSON.parse(storedSettings) as Partial<PomodoroSettings>;
        settings = {
          ...defaultSettings,
          ...parsed
        };
      } catch (error) {
        console.error('Failed to load pomodoro settings', error);
        settings = { ...defaultSettings };
      }
    }

    updateSettings();

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
          {running ? 'Live' : 'Ready'} · {modeLabels[mode]}
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
        <p class={styles.timerCycle}>
          {modeLabels[mode]} · {getDurationForMode(mode)} minutes
        </p>
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
            <span>Work duration (minutes)</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={settings.workMinutes}
              on:input={updateSettings}
            />
          </label>
          <label class={styles.formRow}>
            <span>Short break duration (minutes)</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={settings.shortBreakMinutes}
              on:input={updateSettings}
            />
          </label>
          <label class={styles.formRow}>
            <span>Long break duration (minutes)</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={settings.longBreakMinutes}
              on:input={updateSettings}
            />
          </label>
          <label class={styles.formRow}>
            <span>Sessions before long break</span>
            <input
              class={styles.input}
              type="number"
              min="1"
              bind:value={settings.sessionsBeforeLongBreak}
              on:input={updateSettings}
            />
          </label>
          <label class={styles.formRow}>
            <span>Automatic long break trigger</span>
            <input
              class={styles.checkbox}
              type="checkbox"
              bind:checked={settings.autoLongBreak}
              on:change={updateSettings}
            />
          </label>
        </div>

        <p class={styles.cardNote}>
          Settings persist locally and only update the active timer if needed.
        </p>
      </div>

      <div class={styles.glassCard}>
        <h2 class={styles.cardTitle}>Session details</h2>

        <div class={styles.cardBody}>
          <p>Current mode: {modeLabels[mode]}</p>
          <p>Total session length: {formatSeconds(totalSeconds)}</p>
          <p>Time remaining: {formatSeconds(remainingSeconds)}</p>
          <p>Status: {running ? 'Counting down' : 'Paused'}</p>
          <p>Work sessions this cycle: {cycleWorkSessions}</p>
          <p>Total work sessions: {totalWorkSessions}</p>
          <p>Total sessions completed: {totalSessionsCompleted}</p>
        </div>

        <p class={styles.cardNote}>Timer updates every second while running.</p>
      </div>
    </section>
  </section>
</main>

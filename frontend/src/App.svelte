<script lang="ts">
  import { onMount } from 'svelte';
  import CountdownTimer from './lib/CountdownTimer.svelte';
  import { controlSystemMedia, getSystemMediaState, type SystemMediaState } from './lib/systemMedia';
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
    enableSessionReminder: boolean;
    pauseMusicOnBreak: boolean;
  };

  const defaultSettings: PomodoroSettings = {
    workMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
    autoLongBreak: true,
    enableSessionReminder: true,
    pauseMusicOnBreak: false
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
  let fileInput: HTMLInputElement | null = null;
  let audioElement: HTMLAudioElement | null = null;
  let audioUrl: string | null = null;
  let playbackStatus = 'No file selected';
  let volume = 0.7;
  let reminderOpen = false;
  let reminderTitle = '';
  let reminderMessage = '';
  let focusSoundMode: 'off' | 'white' | 'rain' | 'brown' = 'off';
  let focusAudioContext: AudioContext | null = null;
  let focusNoiseSource: AudioBufferSourceNode | null = null;
  let focusGainNode: GainNode | null = null;
  let focusSoundPlaying = false;
  let localAudioPlaying = false;
  let systemMediaState: SystemMediaState = {
    available: false,
    title: '',
    artist: null,
    source: '',
    isPlaying: false,
    supportsPlayPause: false,
    supportsNext: false,
    supportsPrevious: false
  };
  let currentAudioSource = 'None';
  let systemMediaDescription = 'No system media detected';
  let systemMediaPollId: ReturnType<typeof setInterval> | null = null;
  let lastMode: SessionMode | null = null;
  let resumeAudioState = {
    focusSound: false,
    localAudio: false,
    systemAudio: false
  };
  type AppTab = 'pomodoro' | 'music' | 'countdown' | 'settings';
  const tabs: { id: AppTab; label: string; icon: string; description: string }[] = [
    { id: 'pomodoro', label: 'Pomodoro', icon: '⏱', description: 'Focus timer' },
    { id: 'music', label: 'Music', icon: '🎧', description: 'Focus sounds and music' },
    { id: 'countdown', label: 'Countdown', icon: '⏳', description: 'Independent countdown' },
    { id: 'settings', label: 'More', icon: '⚙️', description: 'Settings and preferences' }
  ];
  let activeTab: AppTab = 'pomodoro';

  const handleAudioPlay = () => {
    playbackStatus = 'Playing';
    localAudioPlaying = true;
  };

  const handleAudioPause = () => {
    if (!audioElement) {
      return;
    }
    playbackStatus = audioElement.currentTime === 0 || audioElement.ended ? 'Stopped' : 'Paused';
    localAudioPlaying = false;
  };

  const handleAudioEnded = () => {
    playbackStatus = 'Stopped';
    localAudioPlaying = false;
  };

  const createAudioElement = () => {
    if (audioElement) {
      return;
    }
    audioElement = new Audio();
    audioElement.volume = volume;
    audioElement.addEventListener('play', handleAudioPlay);
    audioElement.addEventListener('pause', handleAudioPause);
    audioElement.addEventListener('ended', handleAudioEnded);
  };

  const clearAudioUrl = () => {
    if (audioUrl) {
      URL.revokeObjectURL(audioUrl);
      audioUrl = null;
    }
  };

  const selectAudioFile = () => {
    fileInput?.click();
  };

  const handleAudioFileChange = (event: Event) => {
    const target = event.currentTarget as HTMLInputElement;
    const file = target.files?.[0];
    if (!file) {
      return;
    }
    createAudioElement();
    clearAudioUrl();
    audioUrl = URL.createObjectURL(file);
    if (audioElement) {
      audioElement.src = audioUrl;
      audioElement.load();
      audioElement.volume = volume;
    }
    playbackStatus = 'Stopped';
  };

  const playAudio = async () => {
    if (!audioElement) {
      return;
    }
    stopFocusSound();
    await pauseSystemMediaIfPlaying();
    await audioElement.play();
  };

  const pauseAudio = () => {
    audioElement?.pause();
  };

  const stopAudio = () => {
    if (!audioElement) {
      return;
    }
    audioElement.pause();
    audioElement.currentTime = 0;
    playbackStatus = 'Stopped';
    localAudioPlaying = false;
  };

  const ensureFocusAudio = () => {
    if (!focusAudioContext) {
      focusAudioContext = new AudioContext();
      focusGainNode = focusAudioContext.createGain();
      focusGainNode.gain.value = volume;
      focusGainNode.connect(focusAudioContext.destination);
    }
  };

  const createNoiseBuffer = (
    context: AudioContext,
    mode: Exclude<typeof focusSoundMode, 'off'>
  ) => {
    const durationSeconds = 2;
    const frameCount = context.sampleRate * durationSeconds;
    const buffer = context.createBuffer(1, frameCount, context.sampleRate);
    const channelData = buffer.getChannelData(0);
    let lastValue = 0;
    for (let index = 0; index < frameCount; index += 1) {
      const whiteSample = Math.random() * 2 - 1;
      if (mode === 'brown') {
        lastValue = (lastValue + whiteSample * 0.02) / 1.02;
        channelData[index] = lastValue * 3.5;
      } else if (mode === 'rain') {
        lastValue = lastValue + (whiteSample - lastValue) * 0.08;
        channelData[index] = lastValue;
      } else {
        channelData[index] = whiteSample;
      }
    }
    return buffer;
  };

  const startFocusSound = async (mode: Exclude<typeof focusSoundMode, 'off'>) => {
    ensureFocusAudio();
    focusSoundMode = mode;
    stopAudio();
    await pauseSystemMediaIfPlaying();
    if (!focusAudioContext || !focusGainNode) {
      return;
    }
    if (focusAudioContext.state === 'suspended') {
      await focusAudioContext.resume();
    }
    focusNoiseSource?.stop();
    focusNoiseSource?.disconnect();
    focusNoiseSource = focusAudioContext.createBufferSource();
    focusNoiseSource.buffer = createNoiseBuffer(focusAudioContext, mode);
    focusNoiseSource.loop = true;
    focusNoiseSource.connect(focusGainNode);
    focusNoiseSource.start();
    focusSoundPlaying = true;
  };

  const pauseFocusSound = () => {
    focusNoiseSource?.stop();
    focusNoiseSource?.disconnect();
    focusNoiseSource = null;
    focusAudioContext?.suspend().catch(() => null);
    focusSoundPlaying = false;
  };

  const stopFocusSound = () => {
    pauseFocusSound();
    focusSoundMode = 'off';
  };

  const toggleFocusSound = async (mode: typeof focusSoundMode) => {
    if (mode !== 'off') {
      await startFocusSound(mode);
      return;
    }
    stopFocusSound();
  };

  const handleFocusSoundChange = (event: Event) => {
    const target = event.currentTarget as HTMLSelectElement;
    void toggleFocusSound(target.value as typeof focusSoundMode);
  };

  const pauseSystemMediaIfPlaying = async () => {
    if (systemMediaState.isPlaying && systemMediaState.supportsPlayPause) {
      try {
        await controlSystemMedia('play_pause');
      } catch (error) {
        console.error('Failed to control system media', error);
      }
    }
  };
  let cycleWorkSessions = 0;
  let totalWorkSessions = 0;
  let totalSessionsCompleted = 0;

  const modeLabels: Record<SessionMode, string> = {
    work: 'Work session',
    short_break: 'Short break',
    long_break: 'Long break'
  };

  const reminderMessages: Record<SessionMode, string> = {
    work: 'Session complete. Time to take a break.',
    short_break: 'Break finished. Ready to focus again?',
    long_break: 'Break finished. Ready to focus again?'
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

  const closeReminder = () => {
    reminderOpen = false;
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
      ),
      enableSessionReminder:
        settings.enableSessionReminder ?? defaultSettings.enableSessionReminder,
      pauseMusicOnBreak: settings.pauseMusicOnBreak ?? defaultSettings.pauseMusicOnBreak
    };
    persistSettings();
    applyCurrentSessionDuration();
    if (!settings.enableSessionReminder) {
      closeReminder();
    }
  };

  const setMode = (nextMode: SessionMode) => {
    mode = nextMode;
    applyCurrentSessionDuration();
  };

  const showReminder = (completedMode: SessionMode) => {
    if (!settings.enableSessionReminder) {
      return;
    }
    reminderTitle = modeLabels[completedMode];
    reminderMessage = reminderMessages[completedMode];
    reminderOpen = true;

    if (!('Notification' in window)) {
      return;
    }

    const sendNotification = () => {
      new Notification(reminderTitle, {
        body: reminderMessage
      });
    };

    if (Notification.permission === 'granted') {
      sendNotification();
    } else if (Notification.permission === 'default') {
      Notification.requestPermission().then((permission) => {
        if (permission === 'granted') {
          sendNotification();
        }
      });
    }
  };

  const handleSessionComplete = () => {
    const completedMode = mode;
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
    showReminder(completedMode);
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
    closeReminder();
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

  const startNextSession = () => {
    startTimer();
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

  const updateSystemMediaState = async () => {
    try {
      const state = await getSystemMediaState();
      systemMediaState = state;
      if ((focusSoundPlaying || localAudioPlaying) && state.isPlaying) {
        await pauseSystemMediaIfPlaying();
      }
    } catch (error) {
      console.error('Failed to read system media state', error);
      systemMediaState = {
        available: false,
        title: '',
        artist: null,
        source: '',
        isPlaying: false,
        supportsPlayPause: false,
        supportsNext: false,
        supportsPrevious: false
      };
    }
  };

  const handleModeTransition = async (previous: SessionMode, next: SessionMode) => {
    if (!settings.pauseMusicOnBreak) {
      return;
    }

    const isBreak = next === 'short_break' || next === 'long_break';
    const wasBreak = previous === 'short_break' || previous === 'long_break';

    if (isBreak && !wasBreak) {
      resumeAudioState = {
        focusSound: focusSoundPlaying || focusSoundMode !== 'off',
        localAudio: localAudioPlaying,
        systemAudio: systemMediaState.isPlaying
      };
      if (focusSoundPlaying) {
        pauseFocusSound();
      }
      if (localAudioPlaying) {
        audioElement?.pause();
      }
      if (systemMediaState.isPlaying) {
        await pauseSystemMediaIfPlaying();
      }
    }

    if (!isBreak && wasBreak) {
      if (resumeAudioState.focusSound && focusSoundMode !== 'off') {
        await startFocusSound(focusSoundMode);
      } else if (resumeAudioState.localAudio) {
        await playAudio();
      } else if (resumeAudioState.systemAudio) {
        try {
          await controlSystemMedia('play_pause');
        } catch (error) {
          console.error('Failed to resume system media', error);
        }
      }
      resumeAudioState = {
        focusSound: false,
        localAudio: false,
        systemAudio: false
      };
    }
  };

  onMount(() => {
    const storedTheme = localStorage.getItem(THEME_STORAGE_KEY);
    const storedSettings = localStorage.getItem(SETTINGS_STORAGE_KEY);
    systemThemeMedia = window.matchMedia('(prefers-color-scheme: dark)');
    lastMode = mode;

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
    void updateSystemMediaState();
    systemMediaPollId = setInterval(updateSystemMediaState, 4000);

    const handleSystemThemeChange = (event: MediaQueryListEvent) => {
      if (preferSystemTheme) {
        applyTheme(event.matches ? 'dark' : 'light');
      }
    };

    systemThemeMedia.addEventListener('change', handleSystemThemeChange);

    return () => {
      pauseTimer();
      systemThemeMedia?.removeEventListener('change', handleSystemThemeChange);
      if (systemMediaPollId) {
        clearInterval(systemMediaPollId);
      }
      if (audioElement) {
        audioElement.pause();
        audioElement.removeEventListener('play', handleAudioPlay);
        audioElement.removeEventListener('pause', handleAudioPause);
        audioElement.removeEventListener('ended', handleAudioEnded);
        audioElement.src = '';
      }
      focusNoiseSource?.stop();
      focusNoiseSource?.disconnect();
      focusNoiseSource = null;
      focusGainNode?.disconnect();
      focusGainNode = null;
      if (focusAudioContext) {
        focusAudioContext.close().catch(() => null);
        focusAudioContext = null;
      }
      clearAudioUrl();
    };
  });

  $: if (audioElement) {
    audioElement.volume = volume;
  }

  $: if (focusGainNode) {
    focusGainNode.gain.value = volume;
  }

  $: currentAudioSource =
    focusSoundPlaying
      ? 'Focus Sound'
      : localAudioPlaying
        ? 'Local File'
        : systemMediaState.isPlaying
          ? 'System Audio'
          : 'None';

  $: systemMediaDescription = systemMediaState.available
    ? `${systemMediaState.isPlaying ? 'Now playing from system' : 'System media paused'}: ${
        systemMediaState.title
      }${systemMediaState.artist ? ` — ${systemMediaState.artist}` : ''} (${
        systemMediaState.source
      })`
    : 'No system media detected';

  $: if (lastMode && mode !== lastMode) {
    void handleModeTransition(lastMode, mode);
    lastMode = mode;
  }
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

    <div class={styles.content}>
      <section
        class={`${styles.view} ${activeTab === 'pomodoro' ? styles.viewActive : ''}`}
        id="view-pomodoro"
        aria-hidden={activeTab !== 'pomodoro'}
      >
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

        <section class={styles.grid}>
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

      <section
        class={`${styles.view} ${activeTab === 'music' ? styles.viewActive : ''}`}
        id="view-music"
        aria-hidden={activeTab !== 'music'}
      >
        <div class={styles.glassCard}>
          <h2 class={styles.cardTitle}>Music player</h2>
          <p class={styles.cardNote}>
            Pick a local track or focus sound to stay in the zone.
          </p>
          <div class={styles.cardBody}>
            <input
              class={styles.fileInput}
              type="file"
              accept="audio/*"
              bind:this={fileInput}
              on:change={handleAudioFileChange}
            />

            <div class={styles.audioControls}>
              <div class={styles.audioSection}>
                <div>
                  <p class={styles.moreFunctionsLabel}>System media</p>
                  <p class={styles.moreFunctionsNote}>{systemMediaDescription}</p>
                </div>
                <div class={styles.audioButtonRow}>
                  <button
                    class={styles.ghostButton}
                    type="button"
                    disabled={!systemMediaState.supportsPrevious}
                    on:click={() => void controlSystemMedia('previous')}
                  >
                    Previous
                  </button>
                  <button
                    class={styles.secondaryButton}
                    type="button"
                    disabled={!systemMediaState.supportsPlayPause}
                    on:click={() => void controlSystemMedia('play_pause')}
                  >
                    {systemMediaState.isPlaying ? 'Pause' : 'Play'}
                  </button>
                  <button
                    class={styles.ghostButton}
                    type="button"
                    disabled={!systemMediaState.supportsNext}
                    on:click={() => void controlSystemMedia('next')}
                  >
                    Next
                  </button>
                </div>
              </div>

              <div class={styles.audioSection}>
                <div>
                  <p class={styles.moreFunctionsLabel}>Focus sounds</p>
                  <p class={styles.moreFunctionsNote}>
                    Built-in focus soundscapes (white, rain, brown) that stay inside the app.
                  </p>
                </div>
                <label class={styles.formRow}>
                  <span>Focus sound</span>
                  <select
                    class={styles.input}
                    bind:value={focusSoundMode}
                    on:change={handleFocusSoundChange}
                  >
                    <option value="off">Off</option>
                    <option value="white">White noise</option>
                    <option value="rain">Rain</option>
                    <option value="brown">Brown noise</option>
                  </select>
                </label>
              </div>

              <div class={styles.audioSection}>
                <div>
                  <p class={styles.moreFunctionsLabel}>Local audio file</p>
                  <p class={styles.moreFunctionsNote}>
                    Select a file to play alongside your focus session.
                  </p>
                </div>
                <button class={styles.secondaryButton} type="button" on:click={selectAudioFile}>
                  Select Audio File
                </button>

                <div class={styles.audioButtonRow}>
                  <button class={styles.primaryButton} type="button" on:click={playAudio}>
                    Play
                  </button>
                  <button class={styles.secondaryButton} type="button" on:click={pauseAudio}>
                    Pause
                  </button>
                  <button class={styles.ghostButton} type="button" on:click={stopAudio}>
                    Stop
                  </button>
                </div>
              </div>

              <label class={styles.formRow}>
                <span>Volume ({volume.toFixed(2)})</span>
                <input
                  class={styles.input}
                  type="range"
                  min="0"
                  max="1"
                  step="0.01"
                  bind:value={volume}
                />
              </label>

              <label class={styles.formRow}>
                <span>Pause music on break</span>
                <input
                  class={styles.checkbox}
                  type="checkbox"
                  bind:checked={settings.pauseMusicOnBreak}
                  on:change={updateSettings}
                />
              </label>

              <p class={styles.playbackStatus}>Status: {playbackStatus}</p>
              <p class={styles.playbackStatus}>Active source: {currentAudioSource}</p>
            </div>
          </div>
        </div>
      </section>

      <section
        class={`${styles.view} ${activeTab === 'countdown' ? styles.viewActive : ''}`}
        id="view-countdown"
        aria-hidden={activeTab !== 'countdown'}
      >
        <div class={styles.glassCard}>
          <h2 class={styles.cardTitle}>Countdown timer</h2>
          <p class={styles.cardNote}>
            An optional countdown that runs independently from your Pomodoro session.
          </p>
          <CountdownTimer />
        </div>
      </section>

      <section
        class={`${styles.view} ${activeTab === 'settings' ? styles.viewActive : ''}`}
        id="view-settings"
        aria-hidden={activeTab !== 'settings'}
      >
        <section class={styles.grid}>
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
              <label class={styles.formRow}>
                <span>Enable session-end pop-up reminder</span>
                <input
                  class={styles.checkbox}
                  type="checkbox"
                  bind:checked={settings.enableSessionReminder}
                  on:change={updateSettings}
                />
              </label>
            </div>

            <p class={styles.cardNote}>
              Settings persist locally and only update the active timer if needed.
            </p>
          </div>
        </section>
      </section>
    </div>

    <nav class={styles.bottomNav} aria-label="Primary">
      <div class={styles.navRow} role="tablist">
        {#each tabs as tab}
          <button
            class={`${styles.navButton} ${activeTab === tab.id ? styles.navButtonActive : ''}`}
            type="button"
            role="tab"
            aria-selected={activeTab === tab.id}
            aria-controls={`view-${tab.id}`}
            title={tab.description}
            on:click={() => (activeTab = tab.id)}
          >
            <span class={styles.navIcon} aria-hidden="true">{tab.icon}</span>
            <span class={styles.navLabel}>{tab.label}</span>
          </button>
        {/each}
      </div>
    </nav>
  </section>
</main>

{#if reminderOpen}
  <section class={styles.reminderToast} aria-live="polite">
    <div>
      <p class={styles.reminderTitle}>{reminderTitle}</p>
      <p class={styles.reminderMessage}>{reminderMessage}</p>
    </div>
    <div class={styles.reminderActions}>
      <button class={styles.primaryButton} type="button" on:click={startNextSession}>
        Start Next Session
      </button>
      <button class={styles.ghostButton} type="button" on:click={closeReminder}>
        Dismiss
      </button>
    </div>
  </section>
{/if}

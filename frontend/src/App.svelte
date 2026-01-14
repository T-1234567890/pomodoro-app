<script lang="ts">
  import { onMount } from 'svelte';
  import CountdownTimer from './lib/CountdownTimer.svelte';
  import {
    countdownState,
    applyCountdownState,
    getCountdownSnapshot,
    initializeCountdown,
    pauseCountdown,
    resetCountdown,
    startCountdown
  } from './lib/countdownStore';
  import { controlSystemMedia, getSystemMediaState, type SystemMediaState } from './lib/systemMedia';
  import { safeInvoke, safeListen } from './lib/tauri';
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
    pauseMusicOnBreak: boolean;
  };

  const defaultSettings: PomodoroSettings = {
    workMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
    autoLongBreak: true,
    pauseMusicOnBreak: false
  };

  type TimerStatePayload = {
    pomodoro: {
      mode: SessionMode;
      running: boolean;
      remainingSeconds: number;
      totalSeconds: number;
      awaitingNextSession: boolean;
      autoStartRemaining: number;
      cycleWorkSessions: number;
      totalWorkSessions: number;
      totalSessionsCompleted: number;
      settings: PomodoroSettings;
    };
    countdown: {
      durationMinutes: number;
      remainingSeconds: number;
      running: boolean;
    };
    focusSound: FocusSoundType;
  };

  let settings: PomodoroSettings = { ...defaultSettings };
  let mode: SessionMode = 'work';
  let totalSeconds = settings.workMinutes * 60;
  let remainingSeconds = totalSeconds;
  let running = false;
  let autoStartRemaining = 0;
  let awaitingNextSession = false;
  let theme: Theme = 'light';
  let preferSystemTheme = true;
  let systemThemeMedia: MediaQueryList | null = null;
  let fileInput: HTMLInputElement | null = null;
  let audioElement: HTMLAudioElement | null = null;
  let audioUrl: string | null = null;
  let localAudioStatus = 'No file selected';
  let volume = 0.7;
  type FocusSoundType = 'off' | 'white' | 'rain' | 'brown';
  let focusSoundSelection: FocusSoundType = 'off';
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
  type AudioSource = 'system' | 'local' | 'focus';
  let activeAudioSource: AudioSource = 'system';
  let localAudioName = 'No file selected';
  let playbackStatus = 'Idle';
  let activeSourceLabel = 'System media';
  let systemMediaTitle = 'No system media detected';
  let systemMediaApp = '';
  let systemMediaArtist = '';
  let previousDisabled = true;
  let playPauseDisabled = true;
  let stopDisabled = true;
  let volumeDisabled = true;
  let playPauseLabel = 'Play';
  let systemMediaPollId: ReturnType<typeof setInterval> | null = null;
  let lastMode: SessionMode | null = null;
  let resumeAudioState = {
    focusSound: false,
    localAudio: false,
    systemAudio: false
  };
  type AppTab = 'music' | 'pomodoro' | 'countdown';
  const tabs: { id: AppTab; label: string; icon: string; description: string }[] = [
    { id: 'music', label: 'Music', icon: '🎧', description: 'Focus sounds and music' },
    { id: 'pomodoro', label: 'Pomodoro', icon: '🍅', description: 'Focus timer' },
    { id: 'countdown', label: 'Countdown', icon: '⏳', description: 'Independent countdown' }
  ];
  let activeTab: AppTab = 'pomodoro';
  let countdownSnapshot = getCountdownSnapshot();
  let countdownUnsubscribe: (() => void) | null = null;
  let menuListenerCleanup: (() => void) | null = null;
  type PomodoroTemplate = {
    id: string;
    label: string;
    description: string;
    settings: Pick<
      PomodoroSettings,
      'workMinutes' | 'shortBreakMinutes' | 'longBreakMinutes' | 'sessionsBeforeLongBreak'
    >;
  };
  const pomodoroTemplates: PomodoroTemplate[] = [
    {
      id: 'classic',
      label: 'Classic Focus',
      description: '25 / 5 with a longer break every 4 sessions.',
      settings: {
        workMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        sessionsBeforeLongBreak: 4
      }
    },
    {
      id: 'deep-work',
      label: 'Deep Work',
      description: '50 / 10 with a longer break every 2 sessions.',
      settings: {
        workMinutes: 50,
        shortBreakMinutes: 10,
        longBreakMinutes: 20,
        sessionsBeforeLongBreak: 2
      }
    },
    {
      id: 'sprint',
      label: 'Sprint',
      description: '90 / 20 with a longer reset every session.',
      settings: {
        workMinutes: 90,
        shortBreakMinutes: 20,
        longBreakMinutes: 30,
        sessionsBeforeLongBreak: 1
      }
    },
    {
      id: 'flow',
      label: 'Flow',
      description: '40 / 8 with a longer break every 3 sessions.',
      settings: {
        workMinutes: 40,
        shortBreakMinutes: 8,
        longBreakMinutes: 20,
        sessionsBeforeLongBreak: 3
      }
    },
    {
      id: 'steady',
      label: 'Steady',
      description: '60 / 15 with a longer break every 2 sessions.',
      settings: {
        workMinutes: 60,
        shortBreakMinutes: 15,
        longBreakMinutes: 30,
        sessionsBeforeLongBreak: 2
      }
    }
  ];

  const handleAudioPlay = () => {
    localAudioStatus = 'Playing';
    localAudioPlaying = true;
  };

  const handleAudioPause = () => {
    if (!audioElement) {
      return;
    }
    localAudioStatus = audioElement.currentTime === 0 || audioElement.ended ? 'Stopped' : 'Paused';
    localAudioPlaying = false;
  };

  const handleAudioEnded = () => {
    localAudioStatus = 'Stopped';
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
    localAudioStatus = 'Stopped';
    localAudioName = file.name;
    void setActiveAudioSource('local');
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
    localAudioStatus = 'Stopped';
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

  const createNoiseBuffer = (context: AudioContext, mode: Exclude<FocusSoundType, 'off'>) => {
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

  const startFocusSound = async (mode: FocusSoundType) => {
    if (mode === 'off') {
      return;
    }
    ensureFocusAudio();
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
  };

  const handleFocusSoundChange = async (event: Event) => {
    const target = event.currentTarget as HTMLSelectElement;
    focusSoundSelection = target.value as FocusSoundType;
    void safeInvoke('focus_sound_set', { sound: focusSoundSelection });
    if (focusSoundSelection === 'off') {
      stopFocusSound();
      return;
    }
    if (activeAudioSource === 'focus' && focusSoundPlaying) {
      await startFocusSound(focusSoundSelection);
    }
  };

  const stopActiveSource = async (source: AudioSource) => {
    if (source === 'local') {
      stopAudio();
      return;
    }
    if (source === 'focus') {
      stopFocusSound();
      return;
    }
    if (source === 'system' && systemMediaState.isPlaying && systemMediaState.supportsPlayPause) {
      try {
        await controlSystemMedia('play_pause');
      } catch (error) {
        console.error('Failed to pause system media', error);
      }
    }
  };

  const setActiveAudioSource = async (source: AudioSource) => {
    if (source === activeAudioSource) {
      return;
    }
    await stopActiveSource(activeAudioSource);
    activeAudioSource = source;
  };

  const handlePlayPause = async () => {
    if (activeAudioSource === 'system') {
      if (!systemMediaState.available || !systemMediaState.supportsPlayPause) {
        return;
      }
      await controlSystemMedia('play_pause');
      return;
    }
    if (activeAudioSource === 'local') {
      if (!audioUrl) {
        return;
      }
      if (localAudioPlaying) {
        pauseAudio();
      } else {
        await playAudio();
      }
      return;
    }
    if (focusSoundSelection === 'off') {
      focusSoundSelection = 'white';
      void safeInvoke('focus_sound_set', { sound: focusSoundSelection });
    }
    if (focusSoundPlaying) {
      pauseFocusSound();
    } else {
      await startFocusSound(focusSoundSelection);
    }
  };

  const handleStop = () => {
    if (activeAudioSource === 'local') {
      stopAudio();
      return;
    }
    if (activeAudioSource === 'focus') {
      stopFocusSound();
    }
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

  const handleFocusSoundMenuSelection = async (
    selection: FocusSoundType,
    notifyBackend = true
  ) => {
    focusSoundSelection = selection;
    if (notifyBackend) {
      void safeInvoke('focus_sound_set', { sound: selection });
    }
    if (selection === 'off') {
      stopFocusSound();
      return;
    }
    if (activeAudioSource !== 'focus') {
      await setActiveAudioSource('focus');
    }
    await startFocusSound(selection);
  };
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

  const applyTimerSnapshot = (snapshot: TimerStatePayload) => {
    mode = snapshot.pomodoro.mode;
    running = snapshot.pomodoro.running;
    remainingSeconds = snapshot.pomodoro.remainingSeconds;
    totalSeconds = snapshot.pomodoro.totalSeconds;
    awaitingNextSession = snapshot.pomodoro.awaitingNextSession;
    autoStartRemaining = snapshot.pomodoro.autoStartRemaining;
    cycleWorkSessions = snapshot.pomodoro.cycleWorkSessions;
    totalWorkSessions = snapshot.pomodoro.totalWorkSessions;
    totalSessionsCompleted = snapshot.pomodoro.totalSessionsCompleted;
    settings = {
      ...settings,
      ...snapshot.pomodoro.settings
    };
    applyCountdownState({
      durationMinutes: snapshot.countdown.durationMinutes,
      remainingSeconds: snapshot.countdown.remainingSeconds,
      running: snapshot.countdown.running
    });
    if (focusSoundSelection !== snapshot.focusSound) {
      void handleFocusSoundMenuSelection(snapshot.focusSound, false);
    }
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
      pauseMusicOnBreak: settings.pauseMusicOnBreak ?? defaultSettings.pauseMusicOnBreak
    };
    persistSettings();
    void safeInvoke('pomodoro_update_settings', {
      workMinutes: settings.workMinutes,
      shortBreakMinutes: settings.shortBreakMinutes,
      longBreakMinutes: settings.longBreakMinutes,
      sessionsBeforeLongBreak: settings.sessionsBeforeLongBreak,
      autoLongBreak: settings.autoLongBreak,
      pauseMusicOnBreak: settings.pauseMusicOnBreak
    });
  };

  const applyTemplate = (template: PomodoroTemplate) => {
    settings = {
      ...settings,
      ...template.settings
    };
    updateSettings();
  };

  const startTimer = () => {
    void safeInvoke('pomodoro_start');
  };

  const pauseTimer = () => {
    void safeInvoke('pomodoro_pause');
  };

  const resetTimer = () => {
    void safeInvoke('pomodoro_reset');
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
        focusSound: focusSoundPlaying,
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
      if (resumeAudioState.focusSound) {
        await startFocusSound(focusSoundSelection);
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

    initializeCountdown(25);
    countdownUnsubscribe = countdownState.subscribe((state) => {
      countdownSnapshot = state;
    });

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
    void (async () => {
      try {
        const initialState = await safeInvoke('timer_get_state');
        if (initialState) {
          applyTimerSnapshot(initialState as TimerStatePayload);
        }
      } catch (error) {
        console.error('Failed to load timer state', error);
      }
    })();

    void (async () => {
      const unlistenTimer = await safeListen('timer_state', (event) => {
        applyTimerSnapshot(event.payload as TimerStatePayload);
      });

      const unlistenFocus = await safeListen('focus_sound', (event) => {
        void handleFocusSoundMenuSelection(event.payload as FocusSoundType, false);
      });

      const unlistenTab = await safeListen('select-tab', (event) => {
        activeTab = event.payload as AppTab;
      });

      menuListenerCleanup = () => {
        unlistenTimer();
        unlistenFocus();
        unlistenTab();
      };
    })();

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
      if (menuListenerCleanup) {
        menuListenerCleanup();
      }
      if (countdownUnsubscribe) {
        countdownUnsubscribe();
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

  $: activeSourceLabel =
    activeAudioSource === 'system'
      ? 'System media'
      : activeAudioSource === 'local'
        ? 'Local audio file'
        : 'Focus sounds';

  $: systemMediaTitle = systemMediaState.available
    ? systemMediaState.title || 'Unknown track'
    : 'No system media detected';

  $: systemMediaArtist = systemMediaState.available && systemMediaState.artist
    ? `— ${systemMediaState.artist}`
    : '';

  $: systemMediaApp = systemMediaState.available ? systemMediaState.source || 'Unknown app' : '';

  $: playbackStatus =
    activeAudioSource === 'local'
      ? localAudioStatus
      : activeAudioSource === 'focus'
        ? focusSoundPlaying
          ? `Playing ${focusSoundSelection} noise`
          : 'Stopped'
        : systemMediaState.available
          ? systemMediaState.isPlaying
            ? 'Playing'
            : 'Paused'
          : 'No system media detected';

  $: previousDisabled =
    activeAudioSource !== 'system' ||
    !systemMediaState.available ||
    !systemMediaState.supportsPrevious;

  $: playPauseDisabled =
    (activeAudioSource === 'system' &&
      (!systemMediaState.available || !systemMediaState.supportsPlayPause)) ||
    (activeAudioSource === 'local' && !audioUrl);

  $: stopDisabled = activeAudioSource === 'system' || (activeAudioSource === 'local' && !audioUrl);

  $: volumeDisabled = activeAudioSource === 'system';

  $: playPauseLabel =
    activeAudioSource === 'system'
      ? systemMediaState.isPlaying
        ? 'Pause'
        : 'Play'
      : activeAudioSource === 'local'
        ? localAudioPlaying
          ? 'Pause'
          : 'Play'
        : focusSoundPlaying
          ? 'Pause'
          : 'Play';

  $: if (lastMode && mode !== lastMode) {
    void handleModeTransition(lastMode, mode);
    lastMode = mode;
  }
</script>

<main class={styles.app}>
  <div class={styles.glassBackground} aria-hidden="true"></div>
  <div class={styles.dragRegion} data-tauri-drag-region aria-hidden="true"></div>
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
            <div class={styles.templateChips} aria-label="Timer templates">
              {#each pomodoroTemplates as template}
                <button
                  class={styles.templateChip}
                  type="button"
                  on:click={() => applyTemplate(template)}
                >
                  {template.label}
                </button>
              {/each}
            </div>
          </div>

          <div class={styles.glassCard}>
            <h2 class={styles.cardTitle}>Timer templates</h2>
            <p class={styles.cardNote}>
              Quick starting points for different focus styles. Apply anytime without stopping the
              timer.
            </p>
            <div class={styles.templateList}>
              {#each pomodoroTemplates as template}
                <button
                  class={styles.templateButton}
                  type="button"
                  on:click={() => applyTemplate(template)}
                >
                  <div>
                    <p class={styles.templateLabel}>{template.label}</p>
                    <p class={styles.templateMeta}>{template.description}</p>
                  </div>
                  <span class={styles.templateTime}>
                    {template.settings.workMinutes} / {template.settings.shortBreakMinutes}
                  </span>
                </button>
              {/each}
            </div>
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

      <section
        class={`${styles.view} ${activeTab === 'music' ? styles.viewActive : ''}`}
        id="view-music"
        aria-hidden={activeTab !== 'music'}
      >
        <div class={styles.glassCard}>
          <div class={styles.musicHeader}>
            <h2 class={styles.cardTitle}>Music player</h2>
            <p class={styles.cardNote}>
              Pick a local track or focus sound to stay in the zone.
            </p>
          </div>
          <div class={styles.cardBody}>
            <input
              class={styles.fileInput}
              type="file"
              accept="audio/*"
              bind:this={fileInput}
              on:change={handleAudioFileChange}
            />

            <div class={styles.audioControls}>
              <div class={styles.audioSourceSelector}>
                <div>
                  <p class={styles.moreFunctionsLabel}>Audio source</p>
                  <p class={styles.moreFunctionsNote}>
                    Switch the source to control system media, a local file, or built-in focus
                    sounds.
                  </p>
                </div>
                <div class={styles.sourceToggleRow} role="tablist" aria-label="Audio sources">
                  <button
                    class={`${styles.sourceToggleButton} ${
                      activeAudioSource === 'system' ? styles.sourceToggleActive : ''
                    }`}
                    type="button"
                    role="tab"
                    aria-selected={activeAudioSource === 'system'}
                    on:click={() => void setActiveAudioSource('system')}
                  >
                    🖥 System media
                  </button>
                  <button
                    class={`${styles.sourceToggleButton} ${
                      activeAudioSource === 'local' ? styles.sourceToggleActive : ''
                    }`}
                    type="button"
                    role="tab"
                    aria-selected={activeAudioSource === 'local'}
                    on:click={() => void setActiveAudioSource('local')}
                  >
                    🎵 Local audio file
                  </button>
                  <button
                    class={`${styles.sourceToggleButton} ${
                      activeAudioSource === 'focus' ? styles.sourceToggleActive : ''
                    }`}
                    type="button"
                    role="tab"
                    aria-selected={activeAudioSource === 'focus'}
                    on:click={() => void setActiveAudioSource('focus')}
                  >
                    🌊 Focus sounds
                  </button>
                </div>
              </div>

              <div class={styles.audioSection}>
                {#if activeAudioSource === 'system'}
                  <div>
                    <p class={styles.sourceTitle}>
                      {systemMediaTitle} {systemMediaArtist}
                    </p>
                    <p class={styles.moreFunctionsNote}>
                      {systemMediaState.available
                        ? `App: ${systemMediaApp}`
                        : 'No system media detected.'}
                    </p>
                  </div>
                {:else if activeAudioSource === 'local'}
                  <div>
                    <p class={styles.sourceTitle}>{localAudioName}</p>
                    <p class={styles.moreFunctionsNote}>
                      Select a file to play directly inside the app.
                    </p>
                  </div>
                  <button class={styles.secondaryButton} type="button" on:click={selectAudioFile}>
                    Select Audio File
                  </button>
                {:else}
                  <div>
                    <p class={styles.sourceTitle}>Focus soundscape</p>
                    <p class={styles.moreFunctionsNote}>
                      Choose a looping ambience tailored for calm concentration.
                    </p>
                  </div>
                  <label class={styles.formRow}>
                    <span>Focus sound</span>
                    <select
                      class={styles.input}
                      bind:value={focusSoundSelection}
                      on:change={handleFocusSoundChange}
                    >
                      <option value="off">Off</option>
                      <option value="white">White noise</option>
                      <option value="rain">Rain</option>
                      <option value="brown">Brown noise</option>
                    </select>
                  </label>
                {/if}
              </div>

              <div class={styles.playbackBar}>
                <div class={styles.audioButtonRow}>
                  <button
                    class={styles.ghostButton}
                    type="button"
                    disabled={previousDisabled}
                    on:click={() => void controlSystemMedia('previous')}
                  >
                    Previous
                  </button>
                  <button
                    class={styles.primaryButton}
                    type="button"
                    disabled={playPauseDisabled}
                    on:click={() => void handlePlayPause()}
                  >
                    {playPauseLabel}
                  </button>
                  <button
                    class={styles.ghostButton}
                    type="button"
                    disabled={stopDisabled}
                    on:click={handleStop}
                  >
                    Stop
                  </button>
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
                    disabled={volumeDisabled}
                  />
                </label>
              </div>

              <label class={styles.formRow}>
                <span>Pause music on break</span>
                <input
                  class={styles.checkbox}
                  type="checkbox"
                  bind:checked={settings.pauseMusicOnBreak}
                  on:change={updateSettings}
                />
              </label>

              <div class={styles.audioMeta}>
                <p class={styles.playbackStatus}>Status: {playbackStatus}</p>
                <p class={styles.playbackStatus}>Active source: {activeSourceLabel}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        class={`${styles.view} ${activeTab === 'countdown' ? styles.viewActive : ''}`}
        id="view-countdown"
        aria-hidden={activeTab !== 'countdown'}
      >
        <section class={styles.countdownView}>
          <header class={styles.countdownHeader}>
            <p class={styles.countdownKicker}>Independent timer</p>
            <h2 class={styles.countdownTitle}>Countdown</h2>
            <p class={styles.countdownNote}>
              A lightweight timer for quick focus blocks and short reminders.
            </p>
          </header>
          <CountdownTimer />
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

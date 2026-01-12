use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Emitter};

use crate::notify_session_complete_for_engine;

#[derive(Clone, Copy, Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PomodoroMode {
    Work,
    ShortBreak,
    LongBreak,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FocusSound {
    Off,
    White,
    Rain,
    Brown,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PomodoroSettings {
    pub work_minutes: u32,
    pub short_break_minutes: u32,
    pub long_break_minutes: u32,
    pub sessions_before_long_break: u32,
    pub auto_long_break: bool,
    pub pause_music_on_break: bool,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PomodoroSnapshot {
    pub mode: PomodoroMode,
    pub running: bool,
    pub remaining_seconds: u32,
    pub total_seconds: u32,
    pub awaiting_next_session: bool,
    pub auto_start_remaining: u32,
    pub cycle_work_sessions: u32,
    pub total_work_sessions: u32,
    pub total_sessions_completed: u32,
    pub settings: PomodoroSettings,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CountdownSnapshot {
    pub duration_minutes: u32,
    pub remaining_seconds: u32,
    pub running: bool,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TimerSnapshot {
    pub pomodoro: PomodoroSnapshot,
    pub countdown: CountdownSnapshot,
    pub focus_sound: FocusSound,
}

#[derive(Clone)]
pub struct TimerHandle(pub Arc<TimerEngine>);

pub struct TimerEngine {
    app: AppHandle,
    state: Mutex<TimerState>,
}

#[derive(Debug)]
struct TimerState {
    pomodoro: PomodoroState,
    countdown: CountdownState,
    focus_sound: FocusSound,
}

#[derive(Debug)]
struct PomodoroState {
    mode: PomodoroMode,
    running: bool,
    remaining_seconds: u32,
    total_seconds: u32,
    awaiting_next_session: bool,
    auto_start_remaining: u32,
    cycle_work_sessions: u32,
    total_work_sessions: u32,
    total_sessions_completed: u32,
    settings: PomodoroSettings,
}

#[derive(Debug)]
struct CountdownState {
    duration_minutes: u32,
    remaining_seconds: u32,
    running: bool,
}

const AUTO_START_DELAY_SECONDS: u32 = 5;

impl TimerEngine {
    pub fn new(app: AppHandle) -> Arc<Self> {
        let settings = PomodoroSettings {
            work_minutes: 25,
            short_break_minutes: 5,
            long_break_minutes: 15,
            sessions_before_long_break: 4,
            auto_long_break: true,
            pause_music_on_break: false,
        };
        let total_seconds = settings.work_minutes * 60;
        let state = TimerState {
            pomodoro: PomodoroState {
                mode: PomodoroMode::Work,
                running: false,
                remaining_seconds: total_seconds,
                total_seconds,
                awaiting_next_session: false,
                auto_start_remaining: 0,
                cycle_work_sessions: 0,
                total_work_sessions: 0,
                total_sessions_completed: 0,
                settings,
            },
            countdown: CountdownState {
                duration_minutes: 25,
                remaining_seconds: 25 * 60,
                running: false,
            },
            focus_sound: FocusSound::Off,
        };
        Arc::new(Self {
            app,
            state: Mutex::new(state),
        })
    }

    pub fn start(engine: Arc<Self>) {
        thread::spawn(move || loop {
            thread::sleep(Duration::from_secs(1));
            engine.tick();
        });
    }

    pub fn snapshot(&self) -> TimerSnapshot {
        let state = self.state.lock().expect("timer state lock");
        TimerSnapshot {
            pomodoro: PomodoroSnapshot {
                mode: state.pomodoro.mode,
                running: state.pomodoro.running,
                remaining_seconds: state.pomodoro.remaining_seconds,
                total_seconds: state.pomodoro.total_seconds,
                awaiting_next_session: state.pomodoro.awaiting_next_session,
                auto_start_remaining: state.pomodoro.auto_start_remaining,
                cycle_work_sessions: state.pomodoro.cycle_work_sessions,
                total_work_sessions: state.pomodoro.total_work_sessions,
                total_sessions_completed: state.pomodoro.total_sessions_completed,
                settings: state.pomodoro.settings.clone(),
            },
            countdown: CountdownSnapshot {
                duration_minutes: state.countdown.duration_minutes,
                remaining_seconds: state.countdown.remaining_seconds,
                running: state.countdown.running,
            },
            focus_sound: state.focus_sound,
        }
    }

    pub fn emit_snapshot(&self) {
        let snapshot = self.snapshot();
        let _ = self.app.emit("timer_state", &snapshot);
        #[cfg(target_os = "macos")]
        {
            crate::status_bar::update_status_bar(&self.app, &snapshot);
        }
    }

    fn tick(&self) {
        let mut completed_session: Option<PomodoroMode> = None;
        {
            let mut state = self.state.lock().expect("timer state lock");
            let pomodoro = &mut state.pomodoro;
            if pomodoro.running {
                if pomodoro.remaining_seconds > 0 {
                    pomodoro.remaining_seconds = pomodoro.remaining_seconds.saturating_sub(1);
                }
                if pomodoro.remaining_seconds == 0 {
                    pomodoro.running = false;
                    pomodoro.awaiting_next_session = true;
                    pomodoro.auto_start_remaining = AUTO_START_DELAY_SECONDS;
                    completed_session = Some(pomodoro.mode);
                    pomodoro.total_sessions_completed += 1;
                    match pomodoro.mode {
                        PomodoroMode::Work => {
                            pomodoro.total_work_sessions += 1;
                            pomodoro.cycle_work_sessions += 1;
                            let should_long_break = pomodoro.settings.auto_long_break
                                && pomodoro.cycle_work_sessions
                                    >= pomodoro.settings.sessions_before_long_break;
                            pomodoro.mode = if should_long_break {
                                PomodoroMode::LongBreak
                            } else {
                                PomodoroMode::ShortBreak
                            };
                        }
                        PomodoroMode::ShortBreak => {
                            pomodoro.mode = PomodoroMode::Work;
                        }
                        PomodoroMode::LongBreak => {
                            pomodoro.mode = PomodoroMode::Work;
                            pomodoro.cycle_work_sessions = 0;
                        }
                    }
                    pomodoro.total_seconds =
                        self.duration_for_mode(pomodoro.mode, &pomodoro.settings) * 60;
                    pomodoro.remaining_seconds = pomodoro.total_seconds;
                }
            } else if pomodoro.awaiting_next_session {
                if pomodoro.auto_start_remaining > 0 {
                    pomodoro.auto_start_remaining = pomodoro.auto_start_remaining.saturating_sub(1);
                }
                if pomodoro.auto_start_remaining == 0 {
                    pomodoro.awaiting_next_session = false;
                    pomodoro.running = true;
                }
            }

            let countdown = &mut state.countdown;
            if countdown.running {
                countdown.remaining_seconds = countdown.remaining_seconds.saturating_sub(1);
                if countdown.remaining_seconds == 0 {
                    countdown.running = false;
                }
            }
        }

        if let Some(completed) = completed_session {
            let mode_label = match completed {
                PomodoroMode::Work => "work",
                PomodoroMode::ShortBreak | PomodoroMode::LongBreak => "break",
            };
            let _ = notify_session_complete_for_engine(mode_label.to_string(), self.app.clone());
        }

        self.emit_snapshot();
    }

    fn duration_for_mode(&self, mode: PomodoroMode, settings: &PomodoroSettings) -> u32 {
        match mode {
            PomodoroMode::Work => settings.work_minutes,
            PomodoroMode::ShortBreak => settings.short_break_minutes,
            PomodoroMode::LongBreak => settings.long_break_minutes,
        }
    }

    pub fn update_settings(&self, settings: PomodoroSettings) {
        let mut state = self.state.lock().expect("timer state lock");
        state.pomodoro.settings = settings.clone();
        let total_seconds = self.duration_for_mode(state.pomodoro.mode, &settings) * 60;
        state.pomodoro.total_seconds = total_seconds;
        if !state.pomodoro.running && !state.pomodoro.awaiting_next_session {
            state.pomodoro.remaining_seconds = total_seconds;
        } else if state.pomodoro.remaining_seconds > total_seconds {
            state.pomodoro.remaining_seconds = total_seconds;
        }
        self.emit_snapshot();
    }

    pub fn start_pomodoro(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        let pomodoro = &mut state.pomodoro;
        pomodoro.mode = PomodoroMode::Work;
        pomodoro.total_seconds =
            self.duration_for_mode(pomodoro.mode, &pomodoro.settings) * 60;
        if pomodoro.remaining_seconds == 0 {
            pomodoro.remaining_seconds = pomodoro.total_seconds;
        }
        pomodoro.awaiting_next_session = false;
        pomodoro.auto_start_remaining = 0;
        pomodoro.running = true;
        self.emit_snapshot();
    }

    pub fn start_break(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        let pomodoro = &mut state.pomodoro;
        pomodoro.mode = PomodoroMode::ShortBreak;
        pomodoro.total_seconds =
            self.duration_for_mode(pomodoro.mode, &pomodoro.settings) * 60;
        pomodoro.remaining_seconds = pomodoro.total_seconds;
        pomodoro.awaiting_next_session = false;
        pomodoro.auto_start_remaining = 0;
        pomodoro.running = true;
        self.emit_snapshot();
    }

    pub fn skip_break(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        let pomodoro = &mut state.pomodoro;
        pomodoro.mode = PomodoroMode::Work;
        pomodoro.total_seconds =
            self.duration_for_mode(pomodoro.mode, &pomodoro.settings) * 60;
        pomodoro.remaining_seconds = pomodoro.total_seconds;
        pomodoro.awaiting_next_session = false;
        pomodoro.auto_start_remaining = 0;
        pomodoro.running = true;
        self.emit_snapshot();
    }

    pub fn pause_pomodoro(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        state.pomodoro.running = false;
        state.pomodoro.awaiting_next_session = false;
        state.pomodoro.auto_start_remaining = 0;
        self.emit_snapshot();
    }

    pub fn reset_pomodoro(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        let pomodoro = &mut state.pomodoro;
        pomodoro.running = false;
        pomodoro.awaiting_next_session = false;
        pomodoro.auto_start_remaining = 0;
        pomodoro.total_seconds =
            self.duration_for_mode(pomodoro.mode, &pomodoro.settings) * 60;
        pomodoro.remaining_seconds = pomodoro.total_seconds;
        self.emit_snapshot();
    }

    pub fn start_countdown(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        let countdown = &mut state.countdown;
        if countdown.remaining_seconds == 0 {
            countdown.remaining_seconds = countdown.duration_minutes * 60;
        }
        countdown.running = true;
        self.emit_snapshot();
    }

    pub fn pause_countdown(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        state.countdown.running = false;
        self.emit_snapshot();
    }

    pub fn reset_countdown(&self) {
        let mut state = self.state.lock().expect("timer state lock");
        let countdown = &mut state.countdown;
        countdown.running = false;
        countdown.remaining_seconds = countdown.duration_minutes * 60;
        self.emit_snapshot();
    }

    pub fn set_countdown_duration(&self, minutes: u32) {
        let mut state = self.state.lock().expect("timer state lock");
        let countdown = &mut state.countdown;
        countdown.duration_minutes = minutes;
        countdown.remaining_seconds = minutes * 60;
        countdown.running = false;
        self.emit_snapshot();
    }

    pub fn set_focus_sound(&self, sound: FocusSound) {
        let mut state = self.state.lock().expect("timer state lock");
        state.focus_sound = sound;
        self.emit_snapshot();
    }
}

#[tauri::command]
pub fn timer_get_state(state: tauri::State<'_, TimerHandle>) -> TimerSnapshot {
    state.0.snapshot()
}

#[tauri::command]
pub fn pomodoro_update_settings(
    payload: PomodoroSettings,
    state: tauri::State<'_, TimerHandle>,
) {
    state.0.update_settings(payload);
}

#[tauri::command]
pub fn pomodoro_start(state: tauri::State<'_, TimerHandle>) {
    state.0.start_pomodoro();
}

#[tauri::command]
pub fn pomodoro_pause(state: tauri::State<'_, TimerHandle>) {
    state.0.pause_pomodoro();
}

#[tauri::command]
pub fn pomodoro_reset(state: tauri::State<'_, TimerHandle>) {
    state.0.reset_pomodoro();
}

#[tauri::command]
pub fn pomodoro_start_break(state: tauri::State<'_, TimerHandle>) {
    state.0.start_break();
}

#[tauri::command]
pub fn pomodoro_skip_break(state: tauri::State<'_, TimerHandle>) {
    state.0.skip_break();
}

#[tauri::command]
pub fn countdown_start(state: tauri::State<'_, TimerHandle>) {
    state.0.start_countdown();
}

#[tauri::command]
pub fn countdown_pause(state: tauri::State<'_, TimerHandle>) {
    state.0.pause_countdown();
}

#[tauri::command]
pub fn countdown_reset(state: tauri::State<'_, TimerHandle>) {
    state.0.reset_countdown();
}

#[tauri::command]
pub fn countdown_set_duration(minutes: u32, state: tauri::State<'_, TimerHandle>) {
    state.0.set_countdown_duration(minutes);
}

#[tauri::command]
pub fn focus_sound_set(sound: FocusSound, state: tauri::State<'_, TimerHandle>) {
    state.0.set_focus_sound(sound);
}

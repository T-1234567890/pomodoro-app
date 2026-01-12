#[cfg(all(target_os = "macos", feature = "status-bar"))]
mod macos {
#[cfg(target_os = "macos")]
use std::sync::{Arc, Mutex};

#[cfg(target_os = "macos")]
use objc2::declare::ClassDecl;
#[cfg(target_os = "macos")]
use objc2::rc::Id;
#[cfg(target_os = "macos")]
use objc2::runtime::{Class, Object, Sel};
#[cfg(target_os = "macos")]
use objc2::{class, msg_send, sel};
#[cfg(target_os = "macos")]
use objc2_app_kit::{
    NSAttributedString, NSControlStateValue, NSFont, NSMenu, NSMenuItem, NSStatusBar,
    NSStatusItem, NSStatusItemLength,
};
#[cfg(target_os = "macos")]
use objc2_foundation::{NSDictionary, NSString};
#[cfg(target_os = "macos")]
use once_cell::sync::OnceCell;
#[cfg(target_os = "macos")]
use tauri::{AppHandle, Emitter, Manager};

#[cfg(target_os = "macos")]
use crate::system_media::{control_media_action, get_system_media_state, SystemMediaState};
use crate::timer::{FocusSound, PomodoroMode, TimerEngine, TimerSnapshot};

#[cfg(target_os = "macos")]
static TIMER_ENGINE: OnceCell<Arc<TimerEngine>> = OnceCell::new();
#[cfg(target_os = "macos")]
static APP_HANDLE: OnceCell<AppHandle> = OnceCell::new();
#[cfg(target_os = "macos")]
static STATUS_BAR: OnceCell<StatusBarController> = OnceCell::new();

#[cfg(target_os = "macos")]
#[derive(Clone, Copy, PartialEq, Eq)]
enum MenuMode {
    PomodoroRunning,
    BreakRunning,
    CountdownRunning,
    Idle,
}

#[cfg(target_os = "macos")]
#[derive(Clone, PartialEq, Eq)]
struct MenuSignature {
    mode: MenuMode,
    countdown_running: bool,
    music_available: bool,
    music_playing: bool,
    supports_play_pause: bool,
    supports_previous: bool,
    supports_next: bool,
    focus_sound: FocusSound,
}

#[cfg(target_os = "macos")]
pub struct StatusBarController {
    status_item: Id<NSStatusItem>,
    menu: Id<NSMenu>,
    handler: Id<Object>,
    last_title: Mutex<String>,
    last_signature: Mutex<Option<MenuSignature>>,
}

#[cfg(target_os = "macos")]
#[cfg(target_os = "macos")]
impl StatusBarController {
    pub fn new(app: AppHandle, engine: Arc<TimerEngine>) -> Self {
        let _ = TIMER_ENGINE.set(engine);
        let _ = APP_HANDLE.set(app);
        let handler = create_handler();
        let status_bar = NSStatusBar::system_status_bar();
        let status_item =
            unsafe { status_bar.status_item_with_length(NSStatusItemLength::Variable) };
        let menu = NSMenu::new();
        unsafe {
            status_item.set_menu(Some(&menu));
        }
        Self {
            status_item,
            menu,
            handler,
            last_title: Mutex::new(String::new()),
            last_signature: Mutex::new(None),
        }
    }

    pub fn update(&self, snapshot: &TimerSnapshot) {
        let title = build_title(snapshot);
        if title != *self.last_title.lock().expect("status title lock") {
            self.set_title(&title);
            *self.last_title.lock().expect("status title lock") = title;
        }

        let media_state = get_system_media_state();
        let signature = MenuSignature {
            mode: menu_mode(snapshot),
            countdown_running: snapshot.countdown.running,
            music_available: media_state.available,
            music_playing: media_state.is_playing,
            supports_play_pause: media_state.supports_play_pause,
            supports_previous: media_state.supports_previous,
            supports_next: media_state.supports_next,
            focus_sound: snapshot.focus_sound,
        };

        let mut last_signature = self.last_signature.lock().expect("menu signature lock");
        if last_signature.as_ref() != Some(&signature) {
            self.rebuild_menu(snapshot, &media_state);
            *last_signature = Some(signature);
        }
    }

    fn set_title(&self, title: &str) {
        if let Some(button) = unsafe { self.status_item.button() } {
            let font: Id<NSFont> = unsafe {
                let font: *mut NSFont = msg_send![class!(NSFont), monospacedDigitSystemFontOfSize: 0.0 weight: 0.0];
                Id::from_retained_ptr(font)
            };
            let ns_title = NSString::from_str(title);
            let attributes = NSDictionary::from_keys_and_objects(
                &[NSString::from_str("NSFontAttributeName")],
                &[font],
            );
            let attributed =
                NSAttributedString::alloc().init_with_string_attributes(&ns_title, &attributes);
            unsafe {
                button.set_attributed_title(&attributed);
            }
        }
    }

    fn rebuild_menu(&self, snapshot: &TimerSnapshot, media_state: &SystemMediaState) {
        unsafe {
            self.menu.remove_all_items();
        }
        match menu_mode(snapshot) {
            MenuMode::PomodoroRunning => {
                self.add_section_title("Pomodoro — Work");
                self.add_pause_reset("pause_pomodoro", "reset_pomodoro");
                self.add_separator();
                self.add_item("Start Break", sel!(startBreak:));
                self.add_separator();
                self.add_music_menu(snapshot, media_state);
                self.add_countdown_menu(snapshot);
                self.add_separator();
                self.add_item("Open App", sel!(openApp:));
                self.add_item("Quit", sel!(quitApp:));
            }
            MenuMode::BreakRunning => {
                self.add_section_title("Break Time");
                self.add_pause_reset("pause_pomodoro", "reset_pomodoro");
                self.add_separator();
                self.add_item("Skip Break", sel!(skipBreak:));
                self.add_separator();
                self.add_music_menu(snapshot, media_state);
                self.add_countdown_menu(snapshot);
                self.add_separator();
                self.add_item("Open App", sel!(openApp:));
                self.add_item("Quit", sel!(quitApp:));
            }
            MenuMode::CountdownRunning => {
                self.add_section_title("Countdown Timer");
                self.add_pause_reset("pause_countdown", "reset_countdown");
                self.add_separator();
                self.add_music_menu(snapshot, media_state);
                self.add_separator();
                self.add_item("Open Countdown Tab", sel!(openCountdown:));
                self.add_item("Open App", sel!(openApp:));
                self.add_item("Quit", sel!(quitApp:));
            }
            MenuMode::Idle => {
                self.add_section_title("Pomodoro Timer");
                self.add_item("Start Pomodoro", sel!(startPomodoro:));
                self.add_item("Start Countdown", sel!(startCountdown:));
                self.add_separator();
                self.add_music_menu(snapshot, media_state);
                self.add_separator();
                self.add_item("Open App", sel!(openApp:));
                self.add_item("Quit", sel!(quitApp:));
            }
        }
    }

    fn add_section_title(&self, title: &str) {
        let item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str(title),
            None,
            &NSString::from_str(""),
        );
        unsafe {
            item.set_enabled(false);
            self.menu.add_item(&item);
        }
    }

    fn add_separator(&self) {
        let item = NSMenuItem::separator_item();
        unsafe {
            self.menu.add_item(&item);
        }
    }

    fn add_item(&self, title: &str, selector: Sel) {
        let item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str(title),
            Some(selector),
            &NSString::from_str(""),
        );
        unsafe {
            item.set_target(Some(&self.handler));
            self.menu.add_item(&item);
        }
    }

    fn add_pause_reset(&self, pause_action: &str, reset_action: &str) {
        self.add_item("⏸ Pause", selector_for_action(pause_action));
        self.add_item("↺ Reset", selector_for_action(reset_action));
    }

    fn add_music_menu(&self, snapshot: &TimerSnapshot, media_state: &SystemMediaState) {
        let menu_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("Music ▶"),
            None,
            &NSString::from_str(""),
        );
        let submenu = NSMenu::new();

        let play_label = if media_state.is_playing {
            "⏸ Pause"
        } else {
            "▶ Play"
        };
        let play_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str(play_label),
            Some(sel!(musicPlayPause:)),
            &NSString::from_str(""),
        );
        unsafe {
            play_item.set_target(Some(&self.handler));
            play_item.set_enabled(media_state.available && media_state.supports_play_pause);
            submenu.add_item(&play_item);
        }

        let prev_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("⏮ Previous"),
            Some(sel!(musicPrevious:)),
            &NSString::from_str(""),
        );
        unsafe {
            prev_item.set_target(Some(&self.handler));
            prev_item.set_enabled(media_state.supports_previous);
            submenu.add_item(&prev_item);
        }

        let next_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("⏭ Next"),
            Some(sel!(musicNext:)),
            &NSString::from_str(""),
        );
        unsafe {
            next_item.set_target(Some(&self.handler));
            next_item.set_enabled(media_state.supports_next);
            submenu.add_item(&next_item);
        }

        submenu.add_item(&NSMenuItem::separator_item());

        let focus_parent = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("Focus Sound ▶"),
            None,
            &NSString::from_str(""),
        );
        let focus_menu = NSMenu::new();
        self.add_focus_item(&focus_menu, "Off", FocusSound::Off, snapshot.focus_sound);
        self.add_focus_item(&focus_menu, "White", FocusSound::White, snapshot.focus_sound);
        self.add_focus_item(&focus_menu, "Rain", FocusSound::Rain, snapshot.focus_sound);
        self.add_focus_item(&focus_menu, "Brown", FocusSound::Brown, snapshot.focus_sound);
        unsafe {
            focus_parent.set_submenu(Some(&focus_menu));
            submenu.add_item(&focus_parent);
        }

        submenu.add_item(&NSMenuItem::separator_item());
        let open_music = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("Open Music Tab"),
            Some(sel!(openMusic:)),
            &NSString::from_str(""),
        );
        unsafe {
            open_music.set_target(Some(&self.handler));
            submenu.add_item(&open_music);
            menu_item.set_submenu(Some(&submenu));
            self.menu.add_item(&menu_item);
        }
    }

    fn add_focus_item(
        &self,
        menu: &NSMenu,
        title: &str,
        value: FocusSound,
        current: FocusSound,
    ) {
        let item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str(title),
            Some(selector_for_focus(value)),
            &NSString::from_str(""),
        );
        unsafe {
            item.set_target(Some(&self.handler));
            if value == current {
                item.set_state(NSControlStateValue::On);
            }
            menu.add_item(&item);
        }
    }

    fn add_countdown_menu(&self, snapshot: &TimerSnapshot) {
        let menu_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("Countdown ▶"),
            None,
            &NSString::from_str(""),
        );
        let submenu = NSMenu::new();
        let start_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("Start"),
            Some(sel!(startCountdown:)),
            &NSString::from_str(""),
        );
        let pause_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("Pause"),
            Some(sel!(pauseCountdown:)),
            &NSString::from_str(""),
        );
        let reset_item = NSMenuItem::alloc().init_with_title_action_key_equivalent(
            &NSString::from_str("Reset"),
            Some(sel!(resetCountdown:)),
            &NSString::from_str(""),
        );
        unsafe {
            start_item.set_target(Some(&self.handler));
            pause_item.set_target(Some(&self.handler));
            reset_item.set_target(Some(&self.handler));

            start_item.set_enabled(!snapshot.countdown.running);
            pause_item.set_enabled(snapshot.countdown.running);
            reset_item.set_enabled(snapshot.countdown.remaining_seconds
                < snapshot.countdown.duration_minutes * 60);

            submenu.add_item(&start_item);
            submenu.add_item(&pause_item);
            submenu.add_item(&reset_item);
            submenu.add_item(&NSMenuItem::separator_item());
            let open_countdown = NSMenuItem::alloc().init_with_title_action_key_equivalent(
                &NSString::from_str("Open Countdown Tab"),
                Some(sel!(openCountdown:)),
                &NSString::from_str(""),
            );
            open_countdown.set_target(Some(&self.handler));
            submenu.add_item(&open_countdown);
            menu_item.set_submenu(Some(&submenu));
            self.menu.add_item(&menu_item);
        }
    }
}

#[cfg(target_os = "macos")]
unsafe impl Send for StatusBarController {}

#[cfg(target_os = "macos")]
unsafe impl Sync for StatusBarController {}

#[cfg(target_os = "macos")]
pub fn init(app: AppHandle, engine: Arc<TimerEngine>) {
    let controller = StatusBarController::new(app, engine);
    let _ = STATUS_BAR.set(controller);
}

#[cfg(target_os = "macos")]
pub fn update_status_bar(app: &AppHandle, snapshot: &TimerSnapshot) {
    if STATUS_BAR.get().is_none() {
        return;
    }
    let snapshot = snapshot.clone();
    let _ = app.run_on_main_thread(move || {
        if let Some(controller) = STATUS_BAR.get() {
            controller.update(&snapshot);
        }
    });
}

#[cfg(target_os = "macos")]
fn build_title(snapshot: &TimerSnapshot) -> String {
    match menu_mode(snapshot) {
        MenuMode::PomodoroRunning => format!("🍅 {}", format_mm_ss(snapshot.pomodoro.remaining_seconds)),
        MenuMode::BreakRunning => format!("☕ {}", format_mm_ss(snapshot.pomodoro.remaining_seconds)),
        MenuMode::CountdownRunning => format!(
            "⏱ {}",
            format_mm_ss(snapshot.countdown.remaining_seconds)
        ),
        MenuMode::Idle => "🍅 Ready".to_string(),
    }
}

#[cfg(target_os = "macos")]
fn format_mm_ss(total_seconds: u32) -> String {
    let minutes = total_seconds / 60;
    let seconds = total_seconds % 60;
    format!("{:02}:{:02}", minutes, seconds)
}

#[cfg(target_os = "macos")]
fn menu_mode(snapshot: &TimerSnapshot) -> MenuMode {
    if snapshot.pomodoro.running {
        match snapshot.pomodoro.mode {
            PomodoroMode::Work => MenuMode::PomodoroRunning,
            PomodoroMode::ShortBreak | PomodoroMode::LongBreak => MenuMode::BreakRunning,
        }
    } else if snapshot.countdown.running {
        MenuMode::CountdownRunning
    } else {
        MenuMode::Idle
    }
}

#[cfg(target_os = "macos")]
fn selector_for_action(action: &str) -> Sel {
    match action {
        "pause_pomodoro" => sel!(pausePomodoro:),
        "reset_pomodoro" => sel!(resetPomodoro:),
        "pause_countdown" => sel!(pauseCountdown:),
        "reset_countdown" => sel!(resetCountdown:),
        _ => sel!(noop:),
    }
}

#[cfg(target_os = "macos")]
fn selector_for_focus(sound: FocusSound) -> Sel {
    match sound {
        FocusSound::Off => sel!(focusOff:),
        FocusSound::White => sel!(focusWhite:),
        FocusSound::Rain => sel!(focusRain:),
        FocusSound::Brown => sel!(focusBrown:),
    }
}

#[cfg(target_os = "macos")]
fn create_handler() -> Id<Object> {
    static CLASS: OnceCell<&'static Class> = OnceCell::new();
    let class = CLASS.get_or_init(|| {
        let superclass = class!(NSObject);
        let mut decl = ClassDecl::new("PomodoroStatusHandler", superclass)
            .expect("Unable to register PomodoroStatusHandler class");
        decl.add_method(sel!(startPomodoro:), start_pomodoro as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(startBreak:), start_break as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(skipBreak:), skip_break as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(pausePomodoro:), pause_pomodoro as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(resetPomodoro:), reset_pomodoro as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(startCountdown:), start_countdown as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(pauseCountdown:), pause_countdown as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(resetCountdown:), reset_countdown as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(openApp:), open_app as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(openMusic:), open_music as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(openCountdown:), open_countdown as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(quitApp:), quit_app as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(musicPlayPause:), music_play_pause as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(musicPrevious:), music_previous as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(musicNext:), music_next as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(focusOff:), focus_off as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(focusWhite:), focus_white as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(focusRain:), focus_rain as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(focusBrown:), focus_brown as extern "C" fn(&Object, Sel, *mut Object));
        decl.add_method(sel!(noop:), noop as extern "C" fn(&Object, Sel, *mut Object));
        decl.register()
    });
    unsafe { Id::from_retained_ptr(msg_send![class, new]) }
}

#[cfg(target_os = "macos")]
extern "C" fn noop(_: &Object, _: Sel, _: *mut Object) {}

#[cfg(target_os = "macos")]
fn with_engine<F: FnOnce(&Arc<TimerEngine>)>(action: F) {
    if let Some(engine) = TIMER_ENGINE.get() {
        action(engine);
    }
}

#[cfg(target_os = "macos")]
fn with_app<F: FnOnce(&AppHandle)>(action: F) {
    if let Some(app) = APP_HANDLE.get() {
        action(app);
    }
}

#[cfg(target_os = "macos")]
extern "C" fn start_pomodoro(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.start_pomodoro());
}

#[cfg(target_os = "macos")]
extern "C" fn start_break(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.start_break());
}

#[cfg(target_os = "macos")]
extern "C" fn skip_break(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.skip_break());
}

#[cfg(target_os = "macos")]
extern "C" fn pause_pomodoro(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.pause_pomodoro());
}

#[cfg(target_os = "macos")]
extern "C" fn reset_pomodoro(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.reset_pomodoro());
}

#[cfg(target_os = "macos")]
extern "C" fn start_countdown(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.start_countdown());
}

#[cfg(target_os = "macos")]
extern "C" fn pause_countdown(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.pause_countdown());
}

#[cfg(target_os = "macos")]
extern "C" fn reset_countdown(_: &Object, _: Sel, _: *mut Object) {
    with_engine(|engine| engine.reset_countdown());
}

#[cfg(target_os = "macos")]
extern "C" fn open_app(_: &Object, _: Sel, _: *mut Object) {
    with_app(|app| {
        if let Some(window) = app.get_webview_window("main") {
            let _ = window.show();
            let _ = window.set_focus();
        }
    });
}

#[cfg(target_os = "macos")]
extern "C" fn open_music(_: &Object, _: Sel, _: *mut Object) {
    with_app(|app| {
        if let Some(window) = app.get_webview_window("main") {
            let _ = window.show();
            let _ = window.set_focus();
        }
        let _ = app.emit("select-tab", "music");
    });
}

#[cfg(target_os = "macos")]
extern "C" fn open_countdown(_: &Object, _: Sel, _: *mut Object) {
    with_app(|app| {
        if let Some(window) = app.get_webview_window("main") {
            let _ = window.show();
            let _ = window.set_focus();
        }
        let _ = app.emit("select-tab", "countdown");
    });
}

#[cfg(target_os = "macos")]
extern "C" fn quit_app(_: &Object, _: Sel, _: *mut Object) {
    with_app(|app| app.exit(0));
}

#[cfg(target_os = "macos")]
extern "C" fn music_play_pause(_: &Object, _: Sel, _: *mut Object) {
    let _ = control_media_action("play_pause");
}

#[cfg(target_os = "macos")]
extern "C" fn music_previous(_: &Object, _: Sel, _: *mut Object) {
    let _ = control_media_action("previous");
}

#[cfg(target_os = "macos")]
extern "C" fn music_next(_: &Object, _: Sel, _: *mut Object) {
    let _ = control_media_action("next");
}

#[cfg(target_os = "macos")]
extern "C" fn focus_off(_: &Object, _: Sel, _: *mut Object) {
    handle_focus_sound(FocusSound::Off);
}

#[cfg(target_os = "macos")]
extern "C" fn focus_white(_: &Object, _: Sel, _: *mut Object) {
    handle_focus_sound(FocusSound::White);
}

#[cfg(target_os = "macos")]
extern "C" fn focus_rain(_: &Object, _: Sel, _: *mut Object) {
    handle_focus_sound(FocusSound::Rain);
}

#[cfg(target_os = "macos")]
extern "C" fn focus_brown(_: &Object, _: Sel, _: *mut Object) {
    handle_focus_sound(FocusSound::Brown);
}

#[cfg(target_os = "macos")]
fn handle_focus_sound(sound: FocusSound) {
    with_engine(|engine| engine.set_focus_sound(sound));
    with_app(|app| {
        let _ = app.emit("focus_sound", sound);
    });
}
}

#[cfg(all(target_os = "macos", feature = "status-bar"))]
pub use macos::{init, update_status_bar};

#[cfg(not(all(target_os = "macos", feature = "status-bar")))]
use std::sync::Arc;
#[cfg(not(all(target_os = "macos", feature = "status-bar")))]
use tauri::AppHandle;
#[cfg(not(all(target_os = "macos", feature = "status-bar")))]
use crate::timer::{TimerEngine, TimerSnapshot};

#[cfg(not(all(target_os = "macos", feature = "status-bar")))]
pub fn init(_app: AppHandle, _engine: Arc<TimerEngine>) {}

#[cfg(not(all(target_os = "macos", feature = "status-bar")))]
pub fn update_status_bar(_app: &AppHandle, _snapshot: &TimerSnapshot) {}

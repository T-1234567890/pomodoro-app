# Pomodoro App — merged main + validation
import json
import os
import tkinter as tk
from tkinter import messagebox
from music_player import MusicPlayerApp
from datetime import date
from ui_utils import (
    apply_glass_style,
    create_glass_card,
    create_glass_tile,
    style_body,
    style_caption,
    style_entry,
    style_glass_button,
    refresh_glass_button,
    style_heading,
    style_stat_label,
    style_subtext,
    style_switch,
    style_timer_display,
    style_dropdown,
    style_glass_panel,
    GLASS_LIGHT_THEME,
    GLASS_DARK_THEME
)

DATA_FILE = 'pomodoro_data.json'

SESSION_PRESETS = {
    'Classic 25/5': {'work': 25, 'break': 5, 'long_break': 15, 'interval': 4},
    'Quick 15/3': {'work': 15, 'break': 3, 'long_break': 10, 'interval': 4},
    'Deep 50/10': {'work': 50, 'break': 10, 'long_break': 20, 'interval': 3},
    'Gentle 20/5': {'work': 20, 'break': 5, 'long_break': 15, 'interval': 4},
    'Custom': None
}


class CountdownWindow:
    def __init__(self, master, theme=None, on_close=None):
        self.theme = theme or GLASS_LIGHT_THEME
        self.top = tk.Toplevel(master)
        self.top.title('Countdown Timer')
        self.on_close = on_close

        apply_glass_style(self.top, self.theme)
        self.card = create_glass_card(self.top, self.theme)
        self.card.grid(row=0, column=0, padx=18, pady=18, sticky='nsew')
        self.card.content.grid_columnconfigure(1, weight=1)

        self.time_var = tk.StringVar(value='5')
        self.title_label = tk.Label(self.card.content, text='Countdown Timer')
        self.subtitle_label = tk.Label(self.card.content, text='Quick timer for focused bursts.')
        self.title_label.grid(row=0, column=0, columnspan=2, sticky='w', pady=(8, 0))
        self.subtitle_label.grid(row=1, column=0, columnspan=2, sticky='w', pady=(0, 12))

        self.minutes_label = tk.Label(self.card.content, text='Minutes')
        self.minutes_entry = tk.Entry(self.card.content, textvariable=self.time_var, width=8)
        self.minutes_label.grid(row=2, column=0, sticky='w', pady=(0, 6))
        self.minutes_entry.grid(row=2, column=1, sticky='e', pady=(0, 6))

        self.timer_frame = create_glass_tile(self.card.content, self.theme)
        self.timer_frame.grid(row=3, column=0, columnspan=2, pady=(4, 12), sticky='ew')
        self.timer_frame.content.grid_columnconfigure(0, weight=1)

        self.time_label = tk.Label(self.timer_frame.content, text='00:00')
        self.time_label.grid(row=0, column=0, padx=8, pady=6)

        self.start_btn = tk.Button(self.card.content, text='Start', command=self.start)
        self.reset_btn = tk.Button(self.card.content, text='Reset', command=self.reset)
        self.start_btn.grid(row=4, column=0, padx=(0, 6), pady=(6, 0), sticky='ew')
        self.reset_btn.grid(row=4, column=1, padx=(6, 0), pady=(6, 0), sticky='ew')

        self.remaining = 0
        self.timer_id = None
        self.running = False

        self.apply_theme(self.theme)
        self.top.protocol('WM_DELETE_WINDOW', self.close)

    def format_time(self, secs):
        m, s = divmod(secs, 60)
        return f'{m:02d}:{s:02d}'

    def start(self):
        if not self.running:
            try:
                self.remaining = int(float(self.time_var.get()) * 60)
            except ValueError:
                messagebox.showerror('Error', 'Enter a number for minutes')
                return
            self.running = True
            self.countdown()

    def reset(self):
        if self.timer_id:
            self.top.after_cancel(self.timer_id)
        self.running = False
        self.time_label.config(text='00:00')

    def countdown(self):
        self.time_label.config(text=self.format_time(self.remaining))
        if self.remaining > 0:
            self.remaining -= 1
            self.timer_id = self.top.after(1000, self.countdown)
        else:
            self.running = False
            messagebox.showinfo('Done', "Time's up!")

    def close(self):
        if self.timer_id:
            self.top.after_cancel(self.timer_id)
        if callable(self.on_close):
            self.on_close(self)
        self.top.destroy()

    def apply_theme(self, theme):
        self.theme = theme
        apply_glass_style(self.top, theme)
        style_glass_panel(self.card, theme)
        style_glass_panel(self.timer_frame, theme, variant='alt')
        base_bg = theme['card']
        tile_bg = theme.get('card_alt', theme['card'])

        for widget in [
            self.card.content, self.minutes_label,
            self.minutes_entry, self.title_label, self.subtitle_label
        ]:
            widget.configure(bg=base_bg, fg=theme['text'])
        for widget in (self.timer_frame.content, self.time_label):
            widget.configure(bg=tile_bg, fg=theme['text'])
        style_heading(self.title_label, theme)
        style_subtext(self.subtitle_label, theme)
        style_body(self.minutes_label, theme)
        style_timer_display(self.time_label, theme)
        style_entry(self.minutes_entry, theme)
        for btn in (self.start_btn, self.reset_btn):
            style_glass_button(btn, theme, primary=(btn is self.start_btn))


class PomodoroApp:
    def __init__(self, master):
        self.master = master
        self.master.title('Pomodoro Timer')

        self.current_theme = GLASS_LIGHT_THEME
        self.running = False

        self.work_seconds = 25 * 60
        self.break_seconds = 5 * 60
        self.long_break_seconds = 15 * 60
        self.long_break_interval = 4

        self.remaining_seconds = 0
        self.is_break = False
        self.break_kind = 'short'
        self.cycle_progress = 0
        self.active_break_seconds = 0

        self.timer_id = None
        self.child_windows = []
        self.pulse_job = None
        self.pulse_up = True

        self.data = self.load_data()

        apply_glass_style(master, self.current_theme)

        # --- UI Layout ---
        self.container = tk.Frame(master, bg=self.current_theme['window'])
        self.container.grid(row=0, column=0, padx=24, pady=24, sticky='nsew')
        self.container.grid_columnconfigure(0, weight=1)

        self.top_panel = create_glass_card(self.container, self.current_theme, variant='base')
        self.top_panel.grid(row=0, column=0, sticky='ew', pady=(0, 16))
        self.top_panel.content.grid_columnconfigure(0, weight=1)

        self.header_frame = tk.Frame(self.top_panel.content, bg=self.current_theme['card'])
        self.header_frame.grid(row=0, column=0, sticky='ew')
        self.header_frame.grid_columnconfigure(0, weight=1)
        self.title_label = tk.Label(self.header_frame, text='Pomodoro')
        self.subtitle_label = tk.Label(self.header_frame, text='Stay in the flow with focused sprints.')
        self.title_label.grid(row=0, column=0, sticky='w')
        self.subtitle_label.grid(row=1, column=0, sticky='w', pady=(4, 0))

        self.timer_display = tk.Frame(self.top_panel.content, bg=self.current_theme['card'])
        self.timer_display.grid(row=1, column=0, sticky='ew', pady=(12, 0))
        self.timer_display.grid_columnconfigure(0, weight=1)

        self.time_label = tk.Label(self.timer_display, text=self.format_time(self.work_seconds))
        self.time_label.grid(row=0, column=0, pady=(6, 2), padx=6)
        self.cycle_status_label = tk.Label(self.timer_display, text='')
        self.cycle_status_label.grid(row=1, column=0, pady=(0, 6))

        self.controls_panel = create_glass_tile(self.container, self.current_theme, variant='alt')
        self.controls_panel.grid(row=1, column=0, sticky='ew')
        for col in range(3):
            self.controls_panel.content.grid_columnconfigure(col, weight=1)

        # --- Presets ---
        preset_names = list(SESSION_PRESETS.keys())
        self.preset_var = tk.StringVar(value=preset_names[0])
        self.preset_label = tk.Label(self.controls_panel.content, text='Session preset')
        self.preset_menu = tk.OptionMenu(self.controls_panel.content, self.preset_var, *preset_names, command=self.apply_preset)
        self.preset_label.grid(row=0, column=0, sticky='w', pady=(2, 6))
        self.preset_menu.grid(row=0, column=1, columnspan=2, sticky='ew', pady=(2, 6))

        # --- Inputs ---
        self.work_var = tk.StringVar(value='25')
        self.break_var = tk.StringVar(value='5')
        self.long_break_var = tk.StringVar(value='15')
        self.long_break_interval_var = tk.StringVar(value='4')

        self.work_label = tk.Label(self.controls_panel.content, text='Work minutes')
        self.break_label = tk.Label(self.controls_panel.content, text='Break minutes')
        self.long_break_label = tk.Label(self.controls_panel.content, text='Long break minutes')
        self.interval_label = tk.Label(self.controls_panel.content, text='Long break every (sessions)')

        self.work_entry = tk.Entry(self.controls_panel.content, textvariable=self.work_var)
        self.break_entry = tk.Entry(self.controls_panel.content, textvariable=self.break_var)
        self.long_break_entry = tk.Entry(self.controls_panel.content, textvariable=self.long_break_var)
        self.long_break_interval_entry = tk.Entry(self.controls_panel.content, textvariable=self.long_break_interval_var)

        self.work_label.grid(row=1, column=0, sticky='w', pady=(0, 2))
        self.work_entry.grid(row=1, column=1, sticky='ew', pady=(0, 2))
        self.break_label.grid(row=2, column=0, sticky='w', pady=(0, 2))
        self.break_entry.grid(row=2, column=1, sticky='ew', pady=(0, 2))
        self.long_break_label.grid(row=3, column=0, sticky='w', pady=(0, 2))
        self.long_break_entry.grid(row=3, column=1, sticky='ew', pady=(0, 2))
        self.interval_label.grid(row=4, column=0, sticky='w', pady=(0, 2))
        self.long_break_interval_entry.grid(row=4, column=1, sticky='ew', pady=(0, 4))

        # --- Validation label ---
        self.validation_var = tk.StringVar(value='')
        self.validation_label = tk.Label(self.controls_panel.content, textvariable=self.validation_var)
        self.validation_label.grid(row=5, column=0, columnspan=3, sticky='w', pady=(0, 6))

        # --- Action Buttons ---
        self.start_button = tk.Button(self.controls_panel.content, text='Start', command=self.start)
        self.pause_button = tk.Button(self.controls_panel.content, text='Pause', state='disabled', command=self.pause)
        self.reset_button = tk.Button(self.controls_panel.content, text='Reset', state='disabled', command=self.reset)

        self.start_button.grid(row=6, column=0, sticky='ew', pady=(0, 6))
        self.pause_button.grid(row=6, column=1, sticky='ew', pady=(0, 6))
        self.reset_button.grid(row=6, column=2, sticky='ew', pady=(0, 6))

        # --- Progress / Status ---
        self.count_label = tk.Label(self.controls_panel.content, text=f"Today's pomodoros: {self.data['count']}")
        self.count_label.grid(row=7, column=0, columnspan=3, sticky='w', pady=(4, 4))

        # --- Toggles ---
        self.toggles_frame = create_glass_tile(self.controls_panel.content, self.current_theme)
        self.dark_mode_var = tk.BooleanVar()
        self.sound_var = tk.BooleanVar(value=True)

        self.dark_mode_check = tk.Checkbutton(self.toggles_frame.content, text='Dark Mode',
                                              variable=self.dark_mode_var,
                                              command=self.toggle_dark_mode)

        self.sound_check = tk.Checkbutton(self.toggles_frame.content, text='Sound on completion',
                                          variable=self.sound_var)

        self.dark_mode_check.grid(row=0, column=0, padx=(0, 12))
        self.sound_check.grid(row=0, column=1)
        self.toggles_frame.grid(row=8, column=0, columnspan=3, sticky='ew', pady=(4, 8))

        # --- Summary Panel ---
        self.summary_frame = create_glass_tile(self.controls_panel.content, self.current_theme)
        self.summary_title = tk.Label(self.summary_frame.content, text='Productivity summary')
        self.focus_time_label = tk.Label(self.summary_frame.content, text='Focus time')
        self.focus_time_value = tk.Label(self.summary_frame.content, text='0m')
        self.breaks_label = tk.Label(self.summary_frame.content, text='Breaks taken')
        self.breaks_value = tk.Label(self.summary_frame.content, text='0 short / 0 long')

        self.summary_frame.grid(row=9, column=0, columnspan=3, sticky='ew', pady=(2, 10))
        self.summary_title.grid(row=0, column=0, columnspan=2, sticky='w')
        self.focus_time_label.grid(row=1, column=0, sticky='w')
        self.focus_time_value.grid(row=1, column=1, sticky='e')
        self.breaks_label.grid(row=2, column=0, sticky='w')
        self.breaks_value.grid(row=2, column=1, sticky='e')

        # --- Secondary Actions ---
        self.countdown_button = tk.Button(self.controls_panel.content, text='Open Countdown', command=self.open_countdown)
        self.music_button = tk.Button(self.controls_panel.content, text='Open Music Player', command=self.open_music_player)

        self.countdown_button.grid(row=10, column=0, columnspan=3, sticky='ew', pady=(0, 6))
        self.music_button.grid(row=11, column=0, columnspan=3, sticky='ew')

        # Live Validation
        self.work_var.trace_add('write', lambda *_: self._on_input_change())
        self.break_var.trace_add('write', lambda *_: self._on_input_change())

        self.apply_theme(self.current_theme)
        self.apply_preset(preset_names[0])
        self.update_summary()

    # =============================
    # Data & Formatting
    # =============================

    def load_data(self):
        today = date.today().isoformat()
        defaults = {
            'date': today,
            'count': 0,
            'short_breaks': 0,
            'long_breaks': 0,
            'focus_seconds': 0,
            'break_seconds': 0
        }
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE, 'r') as f:
                    data = json.load(f)
            except Exception:
                data = defaults.copy()
        else:
            data = defaults.copy()

        if data.get('date') != today:
            data = defaults.copy()

        return data

    def save_data(self):
        with open(DATA_FILE, 'w') as f:
            json.dump(self.data, f)

    def format_time(self, seconds):
        mins, secs = divmod(seconds, 60)
        return f'{mins:02d}:{secs:02d}'

    # =============================
    # Theme / UI Styling
    # =============================

    def apply_theme(self, theme):
        self.current_theme = theme
        apply_glass_style(self.master, theme)

        style_heading(self.title_label, theme)
        style_subtext(self.subtitle_label, theme)
        style_glass_panel(self.top_panel, theme, variant='base')
        style_glass_panel(self.controls_panel, theme, variant='alt')
        style_glass_panel(self.summary_frame, theme, variant='alt')
        style_glass_panel(self.toggles_frame, theme, variant='alt')
        self.header_frame.configure(bg=theme['card'])
        self.timer_display.configure(bg=theme['card'])

        for lbl in [self.work_label, self.break_label,
                    self.long_break_label, self.interval_label,
                    self.preset_label, self.cycle_status_label]:
            style_body(lbl, theme)

        for lbl in [self.count_label, self.cycle_status_label,
                    self.summary_title, self.focus_time_label,
                    self.focus_time_value, self.breaks_label,
                    self.breaks_value, self.validation_label]:
            style_body(lbl, theme)

        style_heading(self.summary_title, theme)
        style_stat_label(self.focus_time_value, theme)
        style_stat_label(self.breaks_value, theme)
        style_timer_display(self.time_label, theme)
        style_caption(self.validation_label, theme)
        style_subtext(self.cycle_status_label, theme)
        tile_bg = theme.get('card_alt', theme['card'])
        base_bg = theme['card']
        self.header_frame.configure(bg=base_bg)
        self.timer_display.configure(bg=base_bg)
        self.focus_time_label.configure(bg=tile_bg)
        self.breaks_label.configure(bg=tile_bg)

        for lbl in (self.title_label, self.subtitle_label, self.time_label, self.cycle_status_label):
            lbl.configure(bg=base_bg if lbl is not self.time_label else tile_bg)

        for lbl in (self.count_label, self.validation_label,
                    self.summary_title, self.focus_time_label,
                    self.focus_time_value, self.breaks_label, self.breaks_value):
            lbl.configure(bg=tile_bg)

        for lbl in (self.work_label, self.break_label, self.long_break_label, self.interval_label, self.preset_label):
            lbl.configure(bg=tile_bg)

        style_dropdown(self.preset_menu, theme)

        for entry in [self.work_entry, self.break_entry,
                      self.long_break_entry, self.long_break_interval_entry]:
            style_entry(entry, theme)

        for btn, primary in [
            (self.start_button, True),
            (self.pause_button, False),
            (self.reset_button, False),
            (self.countdown_button, False),
            (self.music_button, False)
        ]:
            style_glass_button(btn, theme, primary)
            refresh_glass_button(btn, theme)

        style_switch(self.dark_mode_check, theme)
        style_switch(self.sound_check, theme)
        for check in (self.dark_mode_check, self.sound_check):
            check.configure(bg=tile_bg, activebackground=tile_bg, selectcolor=tile_bg)

        self.master.configure(bg=theme['window'])
        self.container.configure(bg=theme['window'])
        self._refresh_button_states()

    # =============================
    # Validation Helpers
    # =============================

    def _inputs_valid(self, show_message=False):
        for value, label in [
            (self.work_var.get(), 'Work minutes'),
            (self.break_var.get(), 'Break minutes')
        ]:
            try:
                m = float(value)
            except ValueError:
                msg = f'{label} must be a number.'
                if show_message:
                    messagebox.showerror('Invalid input', msg)
                return False, msg

            if m <= 0:
                msg = f'{label} must be greater than zero.'
                if show_message:
                    messagebox.showerror('Invalid input', msg)
                return False, msg

        return True, ''

    def _get_durations(self):
        valid, msg = self._inputs_valid()
        self.validation_var.set(msg)
        if not valid:
            return None
        return int(float(self.work_var.get()) * 60), int(float(self.break_var.get()) * 60)

    def _on_input_change(self):
        valid, _ = self._inputs_valid()
        self.start_button.config(state=('normal' if valid else 'disabled'))
        self._refresh_button_states()

    # =============================
    # Presets
    # =============================

    def apply_preset(self, preset_name):
        preset = SESSION_PRESETS.get(preset_name)
        if not preset:
            return
        self.work_var.set(str(preset['work']))
        self.break_var.set(str(preset['break']))
        self.long_break_var.set(str(preset['long_break']))
        self.long_break_interval_var.set(str(preset['interval']))
        self.remaining_seconds = 0
        self.is_break = False
        self.time_label.config(text=self.format_time(int(self.work_var.get()) * 60))
        self.update_summary()

    # =============================
    # Timer Actions
    # =============================

    def start(self):
        if not self.running:
            durations = self._get_durations()
            if not durations:
                return

            self.work_seconds, self.break_seconds = durations

            if self.remaining_seconds <= 0:
                self.remaining_seconds = self.work_seconds

            self.running = True
            self.start_button.config(state='disabled')
            self.pause_button.config(state='normal')
            self.reset_button.config(state='normal')
            self.countdown()

    def pause(self):
        self.running = False
        self.start_button.config(text='Resume', state='normal')
        self.pause_button.config(state='disabled')

    def reset(self):
        self.running = False
        self.remaining_seconds = self.work_seconds
        self.time_label.config(text=self.format_time(self.work_seconds))
        self.start_button.config(text='Start', state='normal')
        self.pause_button.config(state='disabled')
        self.reset_button.config(state='disabled')

    def countdown(self):
        self.time_label.config(text=self.format_time(self.remaining_seconds))

        if not self.running:
            return

        if self.remaining_seconds > 0:
            self.remaining_seconds -= 1
            self.timer_id = self.master.after(1000, self.countdown)
        else:
            self.running = False
            messagebox.showinfo("Time's up", "Work session complete!")
            self.reset()

    # =============================
    # UI Helpers & Child Windows
    # =============================

    def _refresh_button_states(self):
        """Refresh glass styles for buttons after state changes."""
        for btn in (
            self.start_button,
            self.pause_button,
            self.reset_button,
            self.countdown_button,
            self.music_button
        ):
            refresh_glass_button(btn, self.current_theme)

    def toggle_dark_mode(self):
        """Switch between light and dark glass themes."""
        theme = GLASS_DARK_THEME if self.dark_mode_var.get() else GLASS_LIGHT_THEME
        self.apply_theme(theme)
        for child in list(self.child_windows):
            if hasattr(child, 'apply_theme'):
                try:
                    child.apply_theme(theme)
                except Exception:
                    pass

    def open_countdown(self):
        """Open a themed countdown timer window."""
        window = CountdownWindow(self.master, theme=self.current_theme, on_close=self._remove_child_window)
        self.child_windows.append(window)

    def open_music_player(self):
        """Open a themed music player window."""
        top = tk.Toplevel(self.master)
        player = MusicPlayerApp(top)
        player.apply_theme(self.current_theme)
        self.child_windows.append(player)

        def _on_close():
            self._remove_child_window(player)
            top.destroy()

        top.protocol('WM_DELETE_WINDOW', _on_close)

    def _remove_child_window(self, child):
        if child in self.child_windows:
            self.child_windows.remove(child)

    def update_summary(self):
        """Update the productivity summary labels."""
        focus_minutes = self.data.get('focus_seconds', 0) // 60
        break_minutes = self.data.get('break_seconds', 0) // 60
        short_breaks = self.data.get('short_breaks', 0)
        long_breaks = self.data.get('long_breaks', 0)
        self.count_label.config(text=f"Today's pomodoros: {self.data.get('count', 0)}")
        self.focus_time_value.config(text=f'{focus_minutes}m focus / {break_minutes}m break')
        self.breaks_value.config(text=f'{short_breaks} short / {long_breaks} long')

# =============================
# NOTE: The Tkinter launcher has been archived. To run the legacy UI, use:
# python3 history/ui-tkinter-0.4.x/pomodoro.py

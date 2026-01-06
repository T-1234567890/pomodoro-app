import json
import os
import tkinter as tk
from tkinter import messagebox
from music_player import MusicPlayerApp
from datetime import date
from ui_utils import (
    apply_glass_style,
    create_glass_card,
    style_body,
    style_entry,
    style_glass_button,
    style_heading,
    style_stat_label,
    style_subtext,
    style_switch,
    GLASS_LIGHT_THEME,
    GLASS_DARK_THEME
)

DATA_FILE = 'pomodoro_data.json'


class CountdownWindow:
    """Simple countdown timer window displayed as a separate page."""

    def __init__(self, master, theme=None, on_close=None):
        self.theme = theme or GLASS_LIGHT_THEME
        self.top = tk.Toplevel(master)
        self.top.title('Countdown Timer')
        self.on_close = on_close

        apply_glass_style(self.top, self.theme)
        self.card = create_glass_card(self.top, self.theme)
        self.card.grid(row=0, column=0, padx=18, pady=18)
        self.card.grid_columnconfigure(1, weight=1)

        self.time_var = tk.StringVar(value='5')
        self.title_label = tk.Label(self.card, text='Countdown Timer')
        self.subtitle_label = tk.Label(self.card, text='Quick timer for focused bursts.')
        self.title_label.grid(row=0, column=0, columnspan=2, sticky='w', pady=(8, 0))
        self.subtitle_label.grid(row=1, column=0, columnspan=2, sticky='w', pady=(0, 12))

        self.minutes_label = tk.Label(self.card, text='Minutes')
        self.minutes_entry = tk.Entry(self.card, textvariable=self.time_var, width=8)
        self.minutes_label.grid(row=2, column=0, sticky='w', pady=(0, 6))
        self.minutes_entry.grid(row=2, column=1, sticky='e', pady=(0, 6))

        self.time_label = tk.Label(self.card, text='00:00', font=('SF Pro Display', 28, 'bold'))
        self.time_label.grid(row=3, column=0, columnspan=2, pady=10)

        self.start_btn = tk.Button(self.card, text='Start', command=self.start)
        self.reset_btn = tk.Button(self.card, text='Reset', command=self.reset)
        self.start_btn.grid(row=4, column=0, padx=(0, 6), pady=(6, 0), sticky='ew')
        self.reset_btn.grid(row=4, column=1, padx=(6, 0), pady=(6, 0), sticky='ew')

        self.remaining = 0
        self.timer_id = None
        self.running = False

        self.apply_theme(self.theme)
        self.top.protocol('WM_DELETE_WINDOW', self.close)

    def format_time(self, secs: int) -> str:
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
            self.timer_id = None
        self.running = False
        self.time_label.config(text='00:00')

    def countdown(self):
        self.time_label.config(text=self.format_time(self.remaining))
        if self.remaining > 0:
            self.remaining -= 1
            self.timer_id = self.top.after(1000, self.countdown)
        else:
            self.running = False
            self.timer_id = None
            messagebox.showinfo('Done', "Time's up!")

    def close(self):
        """Close the countdown window and notify the parent."""
        if self.timer_id:
            self.top.after_cancel(self.timer_id)
            self.timer_id = None
        if callable(self.on_close):
            self.on_close(self)
        self.top.destroy()

    def apply_theme(self, theme: dict):
        self.theme = theme
        apply_glass_style(self.top, theme)
        for widget in [self.card, self.time_label, self.minutes_label, self.minutes_entry,
                       self.title_label, self.subtitle_label]:
            widget.configure(bg=theme['card'], fg=theme['text'])
        style_heading(self.title_label, theme)
        style_subtext(self.subtitle_label, theme)
        style_body(self.minutes_label, theme)
        style_entry(self.minutes_entry, theme)
        self.time_label.configure(font=('SF Pro Display', 28, 'bold'), fg=theme['text'])
        for btn in [self.start_btn, self.reset_btn]:
            style_glass_button(btn, theme, primary=btn is self.start_btn)


class PomodoroApp:
    def __init__(self, master):
        self.master = master
        self.master.title('Pomodoro Timer')
        self.current_theme = GLASS_LIGHT_THEME
        self.running = False
        self.work_seconds = 25 * 60
        self.break_seconds = 5 * 60
        self.remaining_seconds = 0
        self.is_break = False
        self.timer_id = None
        self.data = self.load_data()
        self.child_windows = []

        # Base window styling
        apply_glass_style(master, self.current_theme)

        # Layout structure
        self.card = create_glass_card(master, self.current_theme)
        self.card.grid(row=0, column=0, padx=20, pady=20, sticky='nsew')
        for col in range(3):
            self.card.grid_columnconfigure(col, weight=1)

        # Header
        self.title_label = tk.Label(self.card, text='Pomodoro')
        self.subtitle_label = tk.Label(self.card, text='Stay in the flow with focused sprints.')
        self.title_label.grid(row=0, column=0, columnspan=3, sticky='w', pady=(8, 0))
        self.subtitle_label.grid(row=1, column=0, columnspan=3, sticky='w', pady=(0, 12))

        # Inputs
        self.work_label = tk.Label(self.card, text='Work minutes')
        self.break_label = tk.Label(self.card, text='Break minutes')
        self.work_var = tk.StringVar(value='25')
        self.break_var = tk.StringVar(value='5')
        self.work_entry = tk.Entry(self.card, textvariable=self.work_var, width=8)
        self.break_entry = tk.Entry(self.card, textvariable=self.break_var, width=8)
        self.work_label.grid(row=2, column=0, sticky='w', pady=(0, 6))
        self.work_entry.grid(row=2, column=1, sticky='ew', pady=(0, 6))
        self.break_label.grid(row=3, column=0, sticky='w', pady=(0, 12))
        self.break_entry.grid(row=3, column=1, sticky='ew', pady=(0, 12))

        # Time display
        self.time_label = tk.Label(self.card, text=self.format_time(self.work_seconds), font=('SF Pro Display', 32, 'bold'))
        self.time_label.grid(row=4, column=0, columnspan=3, pady=(0, 12))

        # Action buttons
        self.start_button = tk.Button(self.card, text='Start', command=self.start)
        self.pause_button = tk.Button(self.card, text='Pause', command=self.pause, state='disabled')
        self.reset_button = tk.Button(self.card, text='Reset', command=self.reset, state='disabled')
        self.start_button.grid(row=5, column=0, sticky='ew', padx=(0, 6))
        self.pause_button.grid(row=5, column=1, sticky='ew', padx=6)
        self.reset_button.grid(row=5, column=2, sticky='ew', padx=(6, 0))

        # Progress / info
        self.count_label = tk.Label(self.card, text=f'Today\'s pomodoros: {self.data["count"]}')
        self.count_label.grid(row=6, column=0, columnspan=3, pady=(12, 4))

        # Toggles
        self.dark_mode_var = tk.BooleanVar()
        self.dark_mode_check = tk.Checkbutton(self.card, text='Dark Mode',
                                              variable=self.dark_mode_var,
                                              command=self.toggle_dark_mode)
        self.dark_mode_check.grid(row=7, column=0, columnspan=3, pady=(0, 12))

        # Secondary actions
        self.countdown_button = tk.Button(self.card, text='Open Countdown',
                                          command=self.open_countdown)
        self.countdown_button.grid(row=8, column=0, columnspan=3, pady=(4, 0), sticky='ew')

        self.music_button = tk.Button(self.card, text='Open Music Player',
                                      command=self.open_music_player)
        self.music_button.grid(row=9, column=0, columnspan=3, pady=(6, 12), sticky='ew')

        self.apply_theme(self.current_theme)

    def load_data(self):
        today = date.today().isoformat()
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE, 'r') as f:
                    data = json.load(f)
            except Exception:
                data = {'date': today, 'count': 0}
        else:
            data = {'date': today, 'count': 0}

        if data.get('date') != today:
            data = {'date': today, 'count': 0}
        return data

    def save_data(self):
        with open(DATA_FILE, 'w') as f:
            json.dump(self.data, f)

    def format_time(self, seconds):
        mins = seconds // 60
        secs = seconds % 60
        return f'{mins:02d}:{secs:02d}'

    def apply_theme(self, theme: dict):
        self.current_theme = theme
        apply_glass_style(self.master, theme)
        for frame in [self.card]:
            frame.configure(bg=theme['card'], highlightbackground=theme['border'], highlightcolor=theme['border'])

        # Text styling
        style_heading(self.title_label, theme)
        style_subtext(self.subtitle_label, theme)
        style_body(self.work_label, theme)
        style_body(self.break_label, theme)
        self.time_label.configure(bg=theme['card'], fg=theme['text'])
        style_stat_label(self.count_label, theme)
        style_switch(self.dark_mode_check, theme)
        style_body(self.dark_mode_check, theme)

        # Entry styling
        for entry in [self.work_entry, self.break_entry]:
            style_entry(entry, theme)

        # Buttons
        style_glass_button(self.start_button, theme, primary=True)
        style_glass_button(self.pause_button, theme, primary=False)
        style_glass_button(self.reset_button, theme, primary=False)
        style_glass_button(self.countdown_button, theme, primary=False)
        style_glass_button(self.music_button, theme, primary=False)

        # Window background outside card
        self.master.configure(bg=theme['window'])

    def toggle_dark_mode(self):
        theme = GLASS_DARK_THEME if self.dark_mode_var.get() else GLASS_LIGHT_THEME
        self.apply_theme(theme)
        for child in list(self.child_windows):
            if isinstance(child, CountdownWindow):
                child.apply_theme(theme)

    def open_countdown(self):
        """Open the countdown timer window."""
        win = CountdownWindow(self.master, theme=self.current_theme, on_close=self._remove_child_window)
        self.child_windows.append(win)

    def open_music_player(self):
        """Open the simple music player window."""
        win = tk.Toplevel(self.master)
        player = MusicPlayerApp(win)
        if hasattr(player, 'apply_theme'):
            player.apply_theme(self.current_theme)

    def _remove_child_window(self, window):
        """Remove references to closed child windows."""
        try:
            self.child_windows.remove(window)
        except ValueError:
            pass

    def start(self):
        if not self.running:
            # Only calculate the durations when starting fresh
            if self.remaining_seconds <= 0:
                try:
                    self.work_seconds = int(float(self.work_var.get()) * 60)
                    self.break_seconds = int(float(self.break_var.get()) * 60)
                except ValueError:
                    messagebox.showerror('Error', 'Please enter valid numbers for minutes')
                    return
                self.remaining_seconds = self.work_seconds if not self.is_break else self.break_seconds

            # Start or resume the countdown without resetting remaining_seconds
            self.running = True
            self.start_button.config(state='disabled')
            self.pause_button.config(state='normal')
            self.reset_button.config(state='normal')
            self.countdown()

    def pause(self):
        if self.running:
            self.running = False
            if self.timer_id:
                self.master.after_cancel(self.timer_id)
                self.timer_id = None
            self.start_button.config(text='Resume', state='normal')
            self.pause_button.config(state='disabled')

    def reset(self):
        if self.timer_id:
            self.master.after_cancel(self.timer_id)
            self.timer_id = None
        self.running = False
        self.is_break = False
        self.remaining_seconds = 0
        self.start_button.config(text='Start', state='normal')
        self.pause_button.config(state='disabled')
        self.reset_button.config(state='disabled')
        try:
            work_seconds = int(float(self.work_var.get()) * 60)
        except ValueError:
            work_seconds = self.work_seconds
            messagebox.showwarning('Invalid input', 'Work minutes must be a number. Using the last valid value.')
        self.time_label.config(text=self.format_time(work_seconds))

    def countdown(self):
        self.time_label.config(text=self.format_time(self.remaining_seconds))
        if self.remaining_seconds > 0:
            self.remaining_seconds -= 1
            self.timer_id = self.master.after(1000, self.countdown)
        else:
            self.running = False
            self.timer_id = None
            if not self.is_break:
                self.data['count'] += 1
                self.save_data()
                self.count_label.config(text=f"Today's pomodoros: {self.data['count']}")
                messagebox.showinfo('Time\'s up', 'Work session complete! Time for a break.')
                self.is_break = True
                self.remaining_seconds = self.break_seconds
                self.start_button.config(text='Start Break', state='disabled')
                self.pause_button.config(state='normal')
                self.running = True
                self.countdown()
            else:
                messagebox.showinfo('Break Over', 'Break over! Ready for another pomodoro.')
                self.is_break = False
                self.start_button.config(text='Start', state='normal')
                self.pause_button.config(state='disabled')
                self.reset_button.config(state='disabled')
                self.time_label.config(text=self.format_time(int(float(self.work_var.get()) * 60)))

if __name__ == '__main__':
    root = tk.Tk()
    app = PomodoroApp(root)
    root.mainloop()

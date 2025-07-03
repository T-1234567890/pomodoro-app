import json
import os
import tkinter as tk
from tkinter import messagebox
from music_player import MusicPlayerApp
from datetime import date

DATA_FILE = 'pomodoro_data.json'


class CountdownWindow:
    """Simple countdown timer window displayed as a separate page."""

    def __init__(self, master):
        self.top = tk.Toplevel(master)
        self.top.title('Countdown Timer')

        self.time_var = tk.StringVar(value='5')
        tk.Label(self.top, text='Minutes:').grid(row=0, column=0)
        tk.Entry(self.top, textvariable=self.time_var, width=5).grid(row=0, column=1)

        self.time_label = tk.Label(self.top, text='00:00', font=('Helvetica', 24))
        self.time_label.grid(row=1, column=0, columnspan=2, pady=10)

        tk.Button(self.top, text='Start', command=self.start).grid(row=2, column=0)
        tk.Button(self.top, text='Reset', command=self.reset).grid(row=2, column=1)

        self.remaining = 0
        self.timer_id = None
        self.running = False

    def apply_theme(self, bg: str, fg: str):
        self.top.config(bg=bg)
        for widget in [self.time_label]:
            widget.config(bg=bg, fg=fg)
        for child in self.top.winfo_children():
            if isinstance(child, tk.Label) or isinstance(child, tk.Button) or isinstance(child, tk.Entry):
                child.config(bg=bg, fg=fg)
            if isinstance(child, tk.Entry):
                child.config(insertbackground=fg)

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


class PomodoroApp:
    def __init__(self, master):
        self.master = master
        self.master.title('Pomodoro Timer')
        self.running = False
        self.work_seconds = 25 * 60
        self.break_seconds = 5 * 60
        self.remaining_seconds = 0
        self.is_break = False
        self.timer_id = None
        self.data = self.load_data()
        self.default_bg = master.cget('bg')
        self.default_fg = 'black'

        # UI Setup
        self.work_label = tk.Label(master, text='Work minutes:')
        self.break_label = tk.Label(master, text='Break minutes:')
        self.work_label.grid(row=0, column=0)
        self.break_label.grid(row=1, column=0)
        self.work_var = tk.StringVar(value='25')
        self.break_var = tk.StringVar(value='5')
        self.work_entry = tk.Entry(master, textvariable=self.work_var, width=5)
        self.break_entry = tk.Entry(master, textvariable=self.break_var, width=5)
        self.work_entry.grid(row=0, column=1)
        self.break_entry.grid(row=1, column=1)

        self.time_label = tk.Label(master, text=self.format_time(self.work_seconds), font=('Helvetica', 24))
        self.time_label.grid(row=2, column=0, columnspan=3, pady=10)

        self.start_button = tk.Button(master, text='Start', command=self.start)
        self.pause_button = tk.Button(master, text='Pause', command=self.pause, state='disabled')
        self.reset_button = tk.Button(master, text='Reset', command=self.reset, state='disabled')
        self.start_button.grid(row=3, column=0)
        self.pause_button.grid(row=3, column=1)
        self.reset_button.grid(row=3, column=2)

        self.count_label = tk.Label(master, text=f'Today\'s pomodoros: {self.data["count"]}')
        self.count_label.grid(row=4, column=0, columnspan=3, pady=5)

        self.dark_mode_var = tk.BooleanVar()
        self.dark_mode_check = tk.Checkbutton(master, text='Dark Mode',
                                              variable=self.dark_mode_var,
                                              command=self.toggle_dark_mode)
        self.dark_mode_check.grid(row=5, column=0, columnspan=3)

        self.countdown_button = tk.Button(master, text='Open Countdown',
                                          command=self.open_countdown)
        self.countdown_button.grid(row=6, column=0, columnspan=3, pady=(5, 0))

        self.music_button = tk.Button(master, text='Open Music Player',
                                      command=self.open_music_player)
        self.music_button.grid(row=7, column=0, columnspan=3, pady=(5, 0))

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

    def apply_theme(self, bg, fg):
        self.master.config(bg=bg)
        widgets = [
            self.work_label, self.break_label, self.time_label,
            self.start_button, self.pause_button, self.reset_button,
            self.count_label, self.dark_mode_check, self.countdown_button
        ]
        for w in widgets:
            w.config(bg=bg, fg=fg)
        for entry in [self.work_entry, self.break_entry]:
            entry.config(bg=bg, fg=fg, insertbackground=fg)

    def toggle_dark_mode(self):
        if self.dark_mode_var.get():
            self.apply_theme('#2e2e2e', '#ffffff')
        else:
            self.apply_theme(self.default_bg, self.default_fg)

    def open_countdown(self):
        """Open the countdown timer window."""
        win = CountdownWindow(self.master)
        if self.dark_mode_var.get():
            win.apply_theme('#2e2e2e', '#ffffff')

    def open_music_player(self):
        """Open the simple music player window."""
        win = tk.Toplevel(self.master)
        player = MusicPlayerApp(win)
        if self.dark_mode_var.get() and hasattr(player, 'apply_theme'):
            player.apply_theme('#2e2e2e', '#ffffff')

    def start(self):
        if not self.running:
            try:
                self.work_seconds = int(float(self.work_var.get()) * 60)
                self.break_seconds = int(float(self.break_var.get()) * 60)
            except ValueError:
                messagebox.showerror('Error', 'Please enter valid numbers for minutes')
                return
            if not self.is_break:
                self.remaining_seconds = self.work_seconds
            else:
                self.remaining_seconds = self.break_seconds
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
        self.start_button.config(text='Start', state='normal')
        self.pause_button.config(state='disabled')
        self.reset_button.config(state='disabled')
        self.time_label.config(text=self.format_time(int(float(self.work_var.get()) * 60)))

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

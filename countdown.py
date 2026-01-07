import tkinter as tk
from tkinter import messagebox
from ui_utils import (
    apply_glass_style,
    create_glass_card,
    create_glass_tile,
    style_body,
    style_entry,
    style_glass_button,
    style_heading,
    style_subtext,
    style_timer_display,
    style_glass_panel,
    GLASS_LIGHT_THEME
)


class CountdownApp:
    def __init__(self, master):
        self.master = master
        master.title('Countdown Timer')

        self.theme = GLASS_LIGHT_THEME
        self.time_var = tk.StringVar(value='5')

        apply_glass_style(master, self.theme)
        self.card = create_glass_card(master, self.theme)
        self.card.grid(row=0, column=0, padx=20, pady=20)
        self.card.content.grid_columnconfigure(1, weight=1)

        self.title_label = tk.Label(self.card.content, text='Countdown Timer')
        self.subtitle_label = tk.Label(self.card.content, text='Quick timer for focused bursts.')
        self.title_label.grid(row=0, column=0, columnspan=2, sticky='w', pady=(6, 0))
        self.subtitle_label.grid(row=1, column=0, columnspan=2, sticky='w', pady=(2, 10))

        self.minutes_label = tk.Label(self.card.content, text='Minutes')
        self.minutes_entry = tk.Entry(self.card.content, textvariable=self.time_var, width=6)
        self.minutes_label.grid(row=2, column=0, sticky='w', pady=(0, 6))
        self.minutes_entry.grid(row=2, column=1, sticky='e', pady=(0, 6))

        self.timer_tile = create_glass_tile(self.card.content, self.theme)
        self.timer_tile.grid(row=3, column=0, columnspan=2, sticky='ew', pady=(2, 10))
        self.timer_tile.content.grid_columnconfigure(0, weight=1)

        self.time_label = tk.Label(self.timer_tile.content, text='00:00')
        self.time_label.grid(row=0, column=0, pady=6)

        self.start_button = tk.Button(self.card.content, text='Start', command=self.start)
        self.reset_button = tk.Button(self.card.content, text='Reset', command=self.reset)
        self.start_button.grid(row=4, column=0, sticky='ew', padx=(0, 6))
        self.reset_button.grid(row=4, column=1, sticky='ew', padx=(6, 0))

        self.remaining = 0
        self.running = False
        self.timer_id = None

        self.apply_theme(self.theme)

    def apply_theme(self, theme):
        self.theme = theme
        apply_glass_style(self.master, theme)
        style_glass_panel(self.card, theme)
        style_glass_panel(self.timer_tile, theme, variant='alt')

        base_bg = theme['card']
        tile_bg = theme.get('card_alt', theme['card'])
        self.card.content.configure(bg=base_bg)
        self.timer_tile.content.configure(bg=tile_bg)
        for widget in (self.minutes_label, self.minutes_entry, self.title_label, self.subtitle_label):
            widget.configure(bg=base_bg, fg=theme['text'])
        self.time_label.configure(bg=tile_bg, fg=theme['text'])

        style_heading(self.title_label, theme)
        style_subtext(self.subtitle_label, theme)
        style_body(self.minutes_label, theme)
        style_entry(self.minutes_entry, theme)
        style_timer_display(self.time_label, theme)
        style_glass_button(self.start_button, theme, primary=True)
        style_glass_button(self.reset_button, theme, primary=False)
        self.master.configure(bg=theme['window'])

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
            self.master.after_cancel(self.timer_id)
            self.timer_id = None
        self.running = False
        self.time_label.config(text='00:00')

    def countdown(self):
        self.time_label.config(text=self.format_time(self.remaining))
        if self.remaining > 0:
            self.remaining -= 1
            self.timer_id = self.master.after(1000, self.countdown)
        else:
            self.running = False
            self.timer_id = None
            messagebox.showinfo('Done', "Time's up!")


if __name__ == '__main__':
    root = tk.Tk()
    app = CountdownApp(root)
    root.mainloop()

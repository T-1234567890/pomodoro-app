import tkinter as tk
from tkinter import messagebox

class CountdownApp:
    def __init__(self, master):
        self.master = master
        master.title('Countdown Timer')

        self.time_var = tk.StringVar(value='5')
        tk.Label(master, text='Minutes:').grid(row=0, column=0)
        tk.Entry(master, textvariable=self.time_var, width=5).grid(row=0, column=1)
        self.time_label = tk.Label(master, text='00:00', font=('Helvetica', 24))
        self.time_label.grid(row=1, column=0, columnspan=2, pady=10)

        tk.Button(master, text='Start', command=self.start).grid(row=2, column=0)
        tk.Button(master, text='Reset', command=self.reset).grid(row=2, column=1)

        self.remaining = 0
        self.running = False
        self.timer_id = None

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

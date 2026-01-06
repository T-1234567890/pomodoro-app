import os
import sys

import subprocess
import tkinter as tk
from tkinter import filedialog, messagebox
import shutil
from ui_utils import (
    apply_glass_style,
    create_glass_card,
    style_body,
    style_glass_button,
    style_heading,
    style_subtext,
    GLASS_LIGHT_THEME
)


def read_id3v1_tags(path):
    """Return title and artist from ID3v1 tag if present."""
    try:
        with open(path, 'rb') as f:
            f.seek(-128, os.SEEK_END)
            tag = f.read(128)
            if tag[:3] == b'TAG':
                title = tag[3:33].decode('latin-1').strip('\x00').strip()
                artist = tag[33:63].decode('latin-1').strip('\x00').strip()
                return title or os.path.basename(path), artist
    except Exception:
        pass
    return os.path.basename(path), ''


def play_audio(path):
    """Attempt to play audio using built-in OS commands."""
    try:
        if sys.platform == 'darwin':
            return subprocess.Popen(['afplay', path])
        elif sys.platform.startswith('win'):
            import winsound
            winsound.PlaySound(path, winsound.SND_FILENAME | winsound.SND_ASYNC)
            return None
        else:
            return subprocess.Popen(['aplay', path])
    except FileNotFoundError:
        messagebox.showerror('Error', 'No suitable audio player found.')
        return None


def get_external_playback():
    """Return title and artist from another music player if available."""
    if shutil.which('playerctl'):
        try:
            title = subprocess.check_output(
                ['playerctl', 'metadata', 'xesam:title'], text=True
            ).strip()
            artist = subprocess.check_output(
                ['playerctl', 'metadata', 'xesam:artist'], text=True
            ).strip()
            if title:
                return title, artist
        except Exception:
            pass
    if sys.platform == 'darwin':
        for app in ('Music', 'Spotify'):
            script = (
                'tell application "' + app + '"\n'
                'if it is running then\n'
                'try\n'
                'set t to the name of the current track\n'
                'set a to the artist of the current track\n'
                'return t & "|" & a\n'
                'end try\n'
                'end if\n'
                'end tell'
            )
            try:
                out = subprocess.check_output(
                    ['osascript', '-e', script], text=True
                ).strip()
                if '|' in out:
                    t, a = out.split('|', 1)
                    if t:
                        return t, a
            except Exception:
                pass
    return '', ''



nplayers = []


class MusicPlayerApp:
    def __init__(self, master):
        self.master = master
        master.title('Simple Music Player')
        self.theme = GLASS_LIGHT_THEME

        self.filepath = ''
        self.process = None

        self.title_var = tk.StringVar()
        self.artist_var = tk.StringVar()
        self.external_var = tk.StringVar(value='')


        apply_glass_style(master, self.theme)
        self.card = create_glass_card(master, self.theme)
        self.card.grid(row=0, column=0, padx=18, pady=18)
        self.card.grid_columnconfigure(1, weight=1)

        self.header = tk.Label(self.card, text='Music Player')
        self.subheader = tk.Label(self.card, text='Bring your own focus soundtrack.')
        self.header.grid(row=0, column=0, columnspan=3, sticky='w', pady=(8, 0))
        self.subheader.grid(row=1, column=0, columnspan=3, sticky='w', pady=(0, 10))

        tk.Button(self.card, text='Open', command=self.open_file).grid(row=2, column=0, sticky='ew', padx=(0, 6))
        tk.Button(self.card, text='Play', command=self.play).grid(row=2, column=1, sticky='ew', padx=6)
        tk.Button(self.card, text='Stop', command=self.stop).grid(row=2, column=2, sticky='ew', padx=(6, 0))

        tk.Label(self.card, text='Title').grid(row=3, column=0, sticky='w', pady=(10, 0))
        tk.Label(self.card, textvariable=self.title_var, anchor='w').grid(row=3, column=1, columnspan=2, sticky='w', pady=(10, 0))

        tk.Label(self.card, text='Artist').grid(row=4, column=0, sticky='w')
        tk.Label(self.card, textvariable=self.artist_var, anchor='w').grid(row=4, column=1, columnspan=2, sticky='w')

        tk.Label(self.card, text='Other Player').grid(row=5, column=0, sticky='w', pady=(6, 0))
        tk.Label(self.card, textvariable=self.external_var, anchor='w').grid(row=5, column=1, columnspan=2, sticky='w', pady=(6, 0))

        self.update_id = self.update_external()
        self.master.bind('<Destroy>', self._on_destroy)

        self.apply_theme(self.theme)


    def apply_theme(self, theme: dict = None):
        """Apply background/foreground colors to widgets."""
        self.theme = theme or GLASS_LIGHT_THEME
        apply_glass_style(self.master, self.theme)
        self.card.configure(bg=self.theme['card'], highlightbackground=self.theme['border'], highlightcolor=self.theme['border'])

        for widget in [self.header, self.subheader]:
            widget.configure(bg=self.theme['card'])
        style_heading(self.header, self.theme)
        style_subtext(self.subheader, self.theme)

        buttons = [child for child in self.card.winfo_children() if isinstance(child, tk.Button)]
        labels = [child for child in self.card.winfo_children() if isinstance(child, tk.Label)]

        for btn in buttons:
            style_glass_button(btn, self.theme, primary=btn['text'] in ('Play',))
        for lbl in labels:
            if lbl in (self.header, self.subheader):
                continue
            style_body(lbl, self.theme)
        self.master.configure(bg=self.theme['window'])

    def open_file(self):
        path = filedialog.askopenfilename(title='Open Music File',
                                          filetypes=[('Audio files', '*.mp3 *.wav *.ogg *.flac'),
                                                     ('All files', '*.*')])
        if path:
            self.filepath = path
            title, artist = read_id3v1_tags(path)
            self.title_var.set(title)
            self.artist_var.set(artist or 'Unknown')

    def play(self):
        if not self.filepath:
            messagebox.showwarning('No file', 'Please open a music file first.')
            return
        self.stop()
        self.process = play_audio(self.filepath)

    def stop(self):
        if self.process is not None:
            self.process.terminate()
            self.process = None
        if sys.platform.startswith('win'):
            import winsound
            winsound.PlaySound(None, winsound.SND_PURGE)

    def update_external(self):
        """Periodically update information from other music players."""
        title, artist = get_external_playback()
        if title:
            self.external_var.set(f'{title} - {artist}' if artist else title)
        else:
            self.external_var.set('')
        self.update_id = self.master.after(5000, self.update_external)
        return self.update_id

    def _on_destroy(self, event):
        if event.widget is self.master and hasattr(self, 'update_id'):
            try:
                self.master.after_cancel(self.update_id)
            except Exception:
                pass



if __name__ == '__main__':
    root = tk.Tk()
    app = MusicPlayerApp(root)
    root.mainloop()

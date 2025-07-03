import os
import sys
import shutil
import subprocess
import tkinter as tk
from tkinter import filedialog, messagebox


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


def get_external_track():
    """Return title and artist from other music software if available."""
    try:
        if sys.platform == 'darwin':
            script = (
                'tell application "System Events"\n'
                'set hasMusic to "Music" is in (name of processes)\n'
                'set hasITunes to "iTunes" is in (name of processes)\n'
                'end tell\n'
                'if hasMusic then\n'
                '  tell application "Music"\n'
                '    if player state is playing then\n'
                '      return (get name of current track) & "||" & (get artist of current track)\n'
                '    end if\n'
                '  end tell\n'
                'end if\n'
                'if hasITunes then\n'
                '  tell application "iTunes"\n'
                '    if player state is playing then\n'
                '      return (get name of current track) & "||" & (get artist of current track)\n'
                '    end if\n'
                '  end tell\n'
                'end if'
            )
            out = subprocess.check_output(['osascript', '-e', script]).decode().strip()
            if out:
                title, artist = (out.split('||') + [''])[:2]
                return title, artist
        elif shutil.which('playerctl'):
            title = subprocess.check_output(
                ['playerctl', 'metadata', '--format', '{{title}}'], stderr=subprocess.DEVNULL
            ).decode().strip()
            artist = subprocess.check_output(
                ['playerctl', 'metadata', '--format', '{{artist}}'], stderr=subprocess.DEVNULL
            ).decode().strip()
            if title or artist:
                return title, artist
    except Exception:
        pass
    return None, None


nplayers = []


class MusicPlayerApp:
    def __init__(self, master):
        self.master = master
        master.title('Simple Music Player')

        self.filepath = ''
        self.process = None

        self.title_var = tk.StringVar()
        self.artist_var = tk.StringVar()
        self.external_var = tk.StringVar()

        tk.Button(master, text='Open', command=self.open_file).grid(row=0, column=0)
        tk.Button(master, text='Play', command=self.play).grid(row=0, column=1)
        tk.Button(master, text='Stop', command=self.stop).grid(row=0, column=2)
        tk.Button(master, text='Refresh Info', command=self.refresh_external).grid(row=0, column=3)

        tk.Label(master, text='Title:').grid(row=1, column=0, sticky='e')
        tk.Label(master, text='Artist:').grid(row=2, column=0, sticky='e')
        tk.Label(master, textvariable=self.title_var).grid(row=1, column=1, columnspan=3, sticky='w')
        tk.Label(master, textvariable=self.artist_var).grid(row=2, column=1, columnspan=3, sticky='w')
        tk.Label(master, text='External:').grid(row=3, column=0, sticky='e')
        tk.Label(master, textvariable=self.external_var).grid(row=3, column=1, columnspan=3, sticky='w')

        self.schedule_external_update()

    def apply_theme(self, bg: str, fg: str):
        """Apply background/foreground colors to widgets."""
        self.master.configure(bg=bg)
        for child in self.master.winfo_children():
            if isinstance(child, (tk.Button, tk.Label)):
                child.configure(bg=bg, fg=fg)

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

    def refresh_external(self):
        """Refresh information about other players."""
        title, artist = get_external_track()
        if title or artist:
            self.external_var.set(f"{title} - {artist}".strip(' -'))
        else:
            self.external_var.set('')

    def schedule_external_update(self):
        self.refresh_external()
        self.master.after(5000, self.schedule_external_update)


if __name__ == '__main__':
    root = tk.Tk()
    app = MusicPlayerApp(root)
    root.mainloop()

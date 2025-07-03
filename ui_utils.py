# Utility functions for applying a simple, consistent UI theme.
import tkinter as tk

SIMPLE_BG = '#f8f8f8'
SIMPLE_FG = '#000000'


def apply_simple_style(win: tk.Misc, bg: str = SIMPLE_BG, fg: str = SIMPLE_FG):
    """Apply a minimal style to the given tkinter window."""
    try:
        win.configure(bg=bg)
    except tk.TclError:
        pass
    for child in win.winfo_children():
        if isinstance(child, (tk.Button, tk.Label, tk.Entry, tk.Checkbutton)):
            try:
                child.configure(bg=bg, fg=fg)
            except tk.TclError:
                pass
        if isinstance(child, tk.Entry):
            try:
                child.configure(insertbackground=fg)
            except tk.TclError:
                pass
        # Also apply recursively for frames
        if isinstance(child, (tk.Frame, tk.LabelFrame, tk.Toplevel)):
            apply_simple_style(child, bg, fg)

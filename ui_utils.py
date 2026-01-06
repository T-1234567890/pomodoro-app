# Utility functions for applying a simple, consistent UI theme.
import tkinter as tk

SIMPLE_BG = '#f8f8f8'
SIMPLE_FG = '#000000'

# Apple-inspired glassmorphism palette
GLASS_LIGHT_THEME = {
    'window': '#e5e9f2',
    'card': '#f9fbff',
    'text': '#1c2635',
    'muted_text': '#546071',
    'accent': '#4f7cff',
    'accent_active': '#2f5ee8',
    'entry_bg': '#eef2fb',
    'border': '#d9e2f3'
}

GLASS_DARK_THEME = {
    'window': '#12151c',
    'card': '#1b202c',
    'text': '#f5f7ff',
    'muted_text': '#c8cedd',
    'accent': '#6c8dff',
    'accent_active': '#4f74f5',
    'entry_bg': '#12151c',
    'border': '#2a3040'
}


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


def apply_glass_style(win: tk.Misc, theme: dict = None):
    """Apply a modern glass-inspired background to a window."""
    theme = theme or GLASS_LIGHT_THEME
    try:
        win.configure(bg=theme['window'])
    except tk.TclError:
        pass


def create_glass_card(parent: tk.Misc, theme: dict = None) -> tk.Frame:
    """Create a lightly frosted container for grouping controls."""
    theme = theme or GLASS_LIGHT_THEME
    frame = tk.Frame(
        parent,
        bg=theme['card'],
        bd=0,
        highlightthickness=1,
        highlightbackground=theme['border'],
        highlightcolor=theme['border']
    )
    return frame


def style_heading(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['text'],
        font=('SF Pro Display', 18, 'bold')
    )


def style_subtext(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['muted_text'],
        font=('SF Pro Text', 11)
    )


def style_stat_label(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['text'],
        font=('SF Pro Display', 14, 'bold')
    )


def style_body(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['text'],
        font=('SF Pro Text', 12)
    )


def style_entry(entry: tk.Entry, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    entry.configure(
        bg=theme['entry_bg'],
        fg=theme['text'],
        insertbackground=theme['text'],
        relief='flat',
        font=('SF Pro Text', 12),
        highlightthickness=1,
        highlightbackground=theme['border'],
        highlightcolor=theme['accent'],
        bd=0
    )


def style_switch(check: tk.Checkbutton, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    check.configure(
        bg=theme['card'],
        fg=theme['muted_text'],
        selectcolor=theme['card'],
        activebackground=theme['card'],
        activeforeground=theme['text'],
        font=('SF Pro Text', 11, 'bold')
    )


def style_glass_button(button: tk.Button, theme: dict = None, primary: bool = True):
    theme = theme or GLASS_LIGHT_THEME
    bg = theme['accent'] if primary else theme['entry_bg']
    fg = '#ffffff' if primary else theme['text']
    active_bg = theme['accent_active'] if primary else theme['border']
    button.configure(
        bg=bg,
        fg=fg,
        activebackground=active_bg,
        activeforeground=fg,
        relief='flat',
        bd=0,
        padx=12,
        pady=8,
        font=('SF Pro Display', 11, 'bold'),
        cursor='hand2',
        highlightthickness=0,
        disabledforeground=theme['muted_text']
    )

# Utility functions for applying a simple, consistent UI theme.
import tkinter as tk

SIMPLE_BG = '#f8f8f8'
SIMPLE_FG = '#000000'

# Apple-inspired glassmorphism palette
GLASS_LIGHT_THEME = {
    'window': '#f4f6fb',
    'card': '#e8ecf4',
    'text': '#1e2430',
    'muted_text': '#5c6675',
    'accent': '#0a84ff',
    'accent_active': '#0066d1',
    'entry_bg': '#f7f8fc',
    'border': '#cfd7e6',
    'disabled_bg': '#d9dfea',
    'disabled_text': '#8a93a6',
    'shadow': '#cfd6e5',
    'glow': '#5ea4ff',
    'button_secondary': '#e0e5ef',
    'button_secondary_active': '#ccd4e3',
    'button_secondary_disabled': '#d4d9e4'
}

GLASS_DARK_THEME = {
    'window': '#0d1117',
    'card': '#151b24',
    'text': '#f3f5ff',
    'muted_text': '#b3bbcc',
    'accent': '#0a84ff',
    'accent_active': '#2b7bff',
    'entry_bg': '#0f131b',
    'border': '#263044',
    'disabled_bg': '#1b202a',
    'disabled_text': '#6f7890',
    'shadow': '#06070a',
    'glow': '#4da3ff',
    'button_secondary': '#1c2330',
    'button_secondary_active': '#222b3a',
    'button_secondary_disabled': '#171d24'
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
    button._glass_theme = theme
    button._glass_primary = primary
    _apply_glass_button_style(button)


def refresh_glass_button(button: tk.Button, theme: dict = None):
    """Re-apply glass button visuals, useful after state changes."""
    if theme:
        button._glass_theme = theme
    _apply_glass_button_style(button)


def _apply_glass_button_style(button: tk.Button):
    theme = getattr(button, '_glass_theme', GLASS_LIGHT_THEME)
    primary = getattr(button, '_glass_primary', True)
    state = str(button.cget('state'))
    secondary_bg = theme.get('button_secondary', theme['entry_bg'])
    secondary_active = theme.get('button_secondary_active', theme['border'])
    secondary_disabled = theme.get('button_secondary_disabled', theme['disabled_bg'])
    base_bg = theme['accent'] if primary else secondary_bg
    base_fg = '#ffffff' if primary else theme['text']
    active_bg = theme['accent_active'] if primary else secondary_active
    if state == 'disabled':
        bg = theme['disabled_bg'] if primary else secondary_disabled
        fg = theme['disabled_text']
    else:
        bg = base_bg
        fg = base_fg
    button.configure(
        bg=bg,
        fg=fg,
        activebackground=active_bg,
        activeforeground=base_fg,
        relief='flat',
        bd=0,
        padx=14,
        pady=9,
        font=('SF Pro Display', 11, 'bold'),
        cursor='hand2',
        highlightthickness=1,
        highlightbackground=theme['border'],
        highlightcolor=theme['border'],
        disabledforeground=theme['disabled_text']
    )

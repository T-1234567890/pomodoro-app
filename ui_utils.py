# Utility functions for applying a simple, consistent UI theme.
import tkinter as tk

SIMPLE_BG = '#f8f8f8'
SIMPLE_FG = '#000000'

# macOS 26 inspired liquid glass palette
GLASS_LIGHT_THEME = {
    'window': '#eef2f8',
    'card': '#f5f7fc',
    'card_alt': '#ecf1f9',
    'text': '#1f2633',
    'muted_text': '#5c6678',
    'accent': '#0a84ff',
    'accent_active': '#0a6fd6',
    'entry_bg': '#f2f5fb',
    'border': '#d5ddee',
    'border_subtle': '#cdd6e8',
    'disabled_bg': '#e1e7f2',
    'disabled_text': '#8a93a6',
    'shadow': '#c6d1e3',
    'glow': '#6aa7ff',
    'button_secondary': '#e4e9f3',
    'button_secondary_active': '#d6deed',
    'button_secondary_disabled': '#d9dfeb'
}

GLASS_DARK_THEME = {
    'window': '#0f141c',
    'card': '#151b26',
    'card_alt': '#1a2130',
    'text': '#dfe5f2',
    'muted_text': '#9da7ba',
    'accent': '#4c9dff',
    'accent_active': '#6aadff',
    'entry_bg': '#101723',
    'border': '#202a3b',
    'border_subtle': '#1c2535',
    'disabled_bg': '#1c2330',
    'disabled_text': '#7b85a0',
    'shadow': '#07090d',
    'glow': '#3a86ff',
    'button_secondary': '#1b2331',
    'button_secondary_active': '#222c3c',
    'button_secondary_disabled': '#161c26'
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


def style_card_frame(frame: tk.Frame, theme: dict = None, variant: str = 'base'):
    """Apply frosted card styling to a frame."""
    theme = theme or GLASS_LIGHT_THEME
    surface = theme.get('card_alt', theme['card']) if variant == 'alt' else theme['card']
    border_color = blend_colors(surface, theme.get('border_subtle', theme['border']), 0.3)
    frame.configure(
        bg=surface,
        bd=0,
        relief='flat',
        highlightthickness=1,
        highlightbackground=border_color,
        highlightcolor=theme.get('border', theme['border'])
    )


def create_glass_card(parent: tk.Misc, theme: dict = None) -> tk.Frame:
    """Create a lightly frosted container for grouping controls."""
    theme = theme or GLASS_LIGHT_THEME
    frame = tk.Frame(parent)
    style_card_frame(frame, theme)
    return frame


def create_glass_tile(parent: tk.Misc, theme: dict = None) -> tk.Frame:
    """Create a floating glass tile for key content (e.g., timers)."""
    theme = theme or GLASS_LIGHT_THEME
    frame = tk.Frame(parent)
    style_card_frame(frame, theme, variant='alt')
    return frame


def style_heading(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['text'],
        font=('SF Pro Display', 19, 'bold')
    )


def style_subtext(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['muted_text'],
        font=('SF Pro Text', 12)
    )


def style_stat_label(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['text'],
        font=('SF Pro Display', 15, 'bold')
    )


def style_body(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['text'],
        font=('SF Pro Text', 12)
    )


def style_caption(label: tk.Label, theme: dict = None):
    """Subtle helper text for validation or statuses."""
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['muted_text'],
        font=('SF Pro Text', 10)
    )


def style_timer_display(label: tk.Label, theme: dict = None):
    """Display style for the main timer readout."""
    theme = theme or GLASS_LIGHT_THEME
    highlight = blend_colors(theme.get('border_subtle', theme['border']), theme.get('card_alt', theme['card']), 0.4)
    label.configure(
        bg=theme.get('card_alt', theme['card']),
        fg=theme['text'],
        font=('SF Pro Display', 36, 'bold'),
        relief='flat',
        bd=0,
        highlightthickness=1,
        highlightbackground=highlight,
        highlightcolor=highlight,
        padx=6,
        pady=6
    )


def style_entry(entry: tk.Entry, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    entry.configure(
        bg=theme['entry_bg'],
        fg=theme['text'],
        insertbackground=theme['text'],
        relief='flat',
        font=('SF Pro Text', 12),
        highlightthickness=2,
        highlightbackground=theme.get('border_subtle', theme['border']),
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


def style_dropdown(option_menu: tk.OptionMenu, theme: dict = None):
    """Apply glass styling to OptionMenu widgets."""
    theme = theme or GLASS_LIGHT_THEME
    option_menu.configure(
        bg=theme['entry_bg'],
        fg=theme['text'],
        activebackground=theme['border'],
        activeforeground=theme['text'],
        highlightthickness=1,
        highlightbackground=theme['border'],
        relief='flat',
        bd=0,
        font=('SF Pro Text', 12)
    )
    menu = option_menu['menu']
    menu.configure(
        bg=theme['entry_bg'],
        fg=theme['text'],
        activebackground=theme['border'],
        activeforeground=theme['text'],
        font=('SF Pro Text', 12)
    )


def blend_colors(base_hex: str, overlay_hex: str, ratio: float = 0.5) -> str:
    """Return a blended hex color between base and overlay."""
    ratio = max(0.0, min(1.0, ratio))
    base_hex = base_hex.lstrip('#')
    overlay_hex = overlay_hex.lstrip('#')
    base_rgb = tuple(int(base_hex[i:i+2], 16) for i in (0, 2, 4))
    overlay_rgb = tuple(int(overlay_hex[i:i+2], 16) for i in (0, 2, 4))
    mixed = tuple(int(b + (o - b) * ratio) for b, o in zip(base_rgb, overlay_rgb))
    return '#{:02x}{:02x}{:02x}'.format(*mixed)

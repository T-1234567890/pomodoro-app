# Utility functions for applying a simple, consistent UI theme.
import tkinter as tk

SIMPLE_BG = '#f8f8f8'
SIMPLE_FG = '#000000'

# macOS 26 inspired liquid glass palette
GLASS_LIGHT_THEME = {
    'window': '#e7edf7',
    'card': '#f4f7fd',
    'card_alt': '#e9eff8',
    'text': '#1b2336',
    'muted_text': '#5d6a82',
    'accent': '#2f8cff',
    'accent_active': '#1f6fe0',
    'entry_bg': '#eef2fb',
    'border': '#d6deec',
    'border_subtle': '#c8d2e4',
    'disabled_bg': '#dfe6f2',
    'disabled_text': '#7c879a',
    'shadow': '#b9c5da',
    'glow': '#6da7ff',
    'button_secondary': '#e1e7f3',
    'button_secondary_active': '#d0d9ea',
    'button_secondary_disabled': '#d4dbe7',
    'button_primary_hover': '#4aa1ff',
    'button_primary_pressed': '#1c63c8',
    'button_secondary_hover': '#f0f4fb',
    'button_secondary_pressed': '#c5d1e6',
    'card_gradient_top': '#f8faff',
    'card_gradient_bottom': '#e6edf8',
    'card_alt_gradient_top': '#eef2fb',
    'card_alt_gradient_bottom': '#dde5f3',
    'inner_shadow': '#fdfdff',
    'panel_radius': 28,
    'panel_padding': 18,
    'panel_shadow_offset': 7
}

GLASS_DARK_THEME = {
    'window': '#111722',
    'card': '#1a2230',
    'card_alt': '#202b3b',
    'text': '#f1f5ff',
    'muted_text': '#a2aec2',
    'accent': '#5aa3ff',
    'accent_active': '#7fb6ff',
    'entry_bg': '#161d2b',
    'border': '#2b3547',
    'border_subtle': '#223043',
    'disabled_bg': '#1f2736',
    'disabled_text': '#a4aec4',
    'shadow': '#0c111a',
    'glow': '#3c82ff',
    'button_secondary': '#222c3d',
    'button_secondary_active': '#2b3850',
    'button_secondary_disabled': '#1b2432',
    'button_primary_hover': '#7cb6ff',
    'button_primary_pressed': '#3a78d6',
    'button_secondary_hover': '#2e3a52',
    'button_secondary_pressed': '#1b2638',
    'card_gradient_top': '#212c3e',
    'card_gradient_bottom': '#161f2c',
    'card_alt_gradient_top': '#273446',
    'card_alt_gradient_bottom': '#1b2534',
    'inner_shadow': '#0f141d',
    'panel_radius': 28,
    'panel_padding': 18,
    'panel_shadow_offset': 7
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


def _draw_rounded_rect(canvas: tk.Canvas, x1: int, y1: int, x2: int, y2: int, radius: int, **kwargs):
    radius = max(0, min(radius, (x2 - x1) // 2, (y2 - y1) // 2))
    points = [
        x1 + radius, y1,
        x2 - radius, y1,
        x2, y1,
        x2, y1 + radius,
        x2, y2 - radius,
        x2, y2,
        x2 - radius, y2,
        x1 + radius, y2,
        x1, y2,
        x1, y2 - radius,
        x1, y1 + radius,
        x1, y1
    ]
    return canvas.create_polygon(points, smooth=True, **kwargs)


def _corner_offset(y: int, height: int, radius: int) -> int:
    if radius <= 0:
        return 0
    if y < radius:
        dy = radius - y
        return radius - int((radius ** 2 - dy ** 2) ** 0.5)
    if y > height - radius:
        dy = y - (height - radius)
        return radius - int((radius ** 2 - dy ** 2) ** 0.5)
    return 0


class GlassPanel(tk.Frame):
    """A rounded glass panel with a subtle gradient and soft shadow."""

    def __init__(self, parent: tk.Misc, theme: dict = None, variant: str = 'base', radius: int = None):
        theme = theme or GLASS_LIGHT_THEME
        super().__init__(parent, bg=theme['window'])
        self.theme = theme
        self.variant = variant
        self.radius = radius or theme.get('panel_radius', 24)
        self.padding = theme.get('panel_padding', 16)
        self.shadow_offset = theme.get('panel_shadow_offset', 6)

        self.canvas = tk.Canvas(self, highlightthickness=0, bd=0, bg=theme['window'])
        self.canvas.place(relwidth=1, relheight=1)
        self.content = tk.Frame(self, bg=self._surface_color())
        self.content.pack(padx=self.padding, pady=self.padding, fill='both', expand=True)
        self.canvas.lower()

        self.bind('<Configure>', self._on_configure)

    def _surface_color(self) -> str:
        return self.theme.get('card_alt', self.theme['card']) if self.variant == 'alt' else self.theme['card']

    def _gradient_colors(self):
        if self.variant == 'alt':
            return self.theme['card_alt_gradient_top'], self.theme['card_alt_gradient_bottom']
        return self.theme['card_gradient_top'], self.theme['card_gradient_bottom']

    def apply_theme(self, theme: dict = None, variant: str = None):
        if theme:
            self.theme = theme
        if variant:
            self.variant = variant
        self.configure(bg=self.theme['window'])
        self.canvas.configure(bg=self.theme['window'])
        self.content.configure(bg=self._surface_color())
        self._draw()

    def _on_configure(self, _event=None):
        self._draw()

    def _draw(self):
        width = self.winfo_width()
        height = self.winfo_height()
        if width <= 1 or height <= 1:
            return
        self.canvas.delete('all')
        draw_width = max(1, width - self.shadow_offset)
        draw_height = max(1, height - self.shadow_offset)
        radius = min(self.radius, draw_width // 2, draw_height // 2)

        shadow_color = self.theme['shadow']
        _draw_rounded_rect(
            self.canvas,
            self.shadow_offset,
            self.shadow_offset,
            self.shadow_offset + draw_width,
            self.shadow_offset + draw_height,
            radius,
            fill=shadow_color,
            outline=''
        )

        top_color, bottom_color = self._gradient_colors()
        for y in range(draw_height):
            ratio = y / max(draw_height - 1, 1)
            color = blend_colors(top_color, bottom_color, ratio)
            x_offset = _corner_offset(y, draw_height, radius)
            self.canvas.create_line(x_offset, y, draw_width - x_offset, y, fill=color)

        border_color = self.theme.get('border', '#d0d6e4')
        inner_shadow = self.theme.get('inner_shadow', border_color)
        _draw_rounded_rect(
            self.canvas,
            0,
            0,
            draw_width,
            draw_height,
            radius,
            fill='',
            outline=border_color,
            width=1
        )
        if radius > 2:
            _draw_rounded_rect(
                self.canvas,
                1,
                1,
                draw_width - 1,
                draw_height - 1,
                max(0, radius - 1),
                fill='',
                outline=inner_shadow,
                width=1
            )

        self.canvas.lower()


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


def style_glass_panel(panel: tk.Misc, theme: dict = None, variant: str = 'base'):
    theme = theme or GLASS_LIGHT_THEME
    if isinstance(panel, GlassPanel):
        panel.apply_theme(theme, variant=variant)
    else:
        style_card_frame(panel, theme, variant=variant)


def create_glass_card(parent: tk.Misc, theme: dict = None, variant: str = 'base') -> GlassPanel:
    """Create a lightly frosted container for grouping controls."""
    theme = theme or GLASS_LIGHT_THEME
    panel = GlassPanel(parent, theme, variant=variant)
    return panel


def create_glass_tile(parent: tk.Misc, theme: dict = None, variant: str = 'alt') -> GlassPanel:
    """Create a floating glass tile for key content (e.g., timers)."""
    theme = theme or GLASS_LIGHT_THEME
    panel = GlassPanel(parent, theme, variant=variant)
    return panel


def style_heading(label: tk.Label, theme: dict = None):
    theme = theme or GLASS_LIGHT_THEME
    label.configure(
        bg=theme['card'],
        fg=theme['text'],
        font=('SF Pro Display', 24, 'bold')
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
        font=('SF Pro Display', 46, 'bold'),
        relief='flat',
        bd=0,
        highlightthickness=1,
        highlightbackground=highlight,
        highlightcolor=highlight,
        padx=18,
        pady=10
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
    if not getattr(button, '_glass_events_bound', False):
        button.bind('<Enter>', _on_glass_hover, add='+')
        button.bind('<Leave>', _on_glass_leave, add='+')
        button.bind('<ButtonPress-1>', _on_glass_press, add='+')
        button.bind('<ButtonRelease-1>', _on_glass_release, add='+')
        button._glass_events_bound = True
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
    button._glass_base_bg = base_bg
    button._glass_base_fg = base_fg
    button._glass_active_bg = active_bg
    button.configure(
        bg=bg,
        fg=fg,
        activebackground=active_bg,
        activeforeground=base_fg,
        relief='flat',
        bd=0,
        padx=22,
        pady=9,
        font=('SF Pro Display', 11, 'bold'),
        cursor='hand2',
        highlightthickness=0,
        disabledforeground=theme['disabled_text']
    )


def _on_glass_hover(event):
    button = event.widget
    if str(button.cget('state')) == 'disabled':
        return
    theme = getattr(button, '_glass_theme', GLASS_LIGHT_THEME)
    primary = getattr(button, '_glass_primary', True)
    hover_color = theme['button_primary_hover'] if primary else theme['button_secondary_hover']
    button.configure(bg=hover_color)


def _on_glass_leave(event):
    button = event.widget
    if str(button.cget('state')) == 'disabled':
        return
    _apply_glass_button_style(button)


def _on_glass_press(event):
    button = event.widget
    if str(button.cget('state')) == 'disabled':
        return
    theme = getattr(button, '_glass_theme', GLASS_LIGHT_THEME)
    primary = getattr(button, '_glass_primary', True)
    pressed_color = theme['button_primary_pressed'] if primary else theme['button_secondary_pressed']
    button.configure(bg=pressed_color)


def _on_glass_release(event):
    button = event.widget
    if str(button.cget('state')) == 'disabled':
        return
    _apply_glass_button_style(button)


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

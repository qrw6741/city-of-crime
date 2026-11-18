class_name UI
## Shared styling and widget helpers for every menu in the game.

const ACCENT := Color(1.0, 0.70, 0.12)
const GREEN := Color(0.35, 0.85, 0.45)
const RED := Color(1.0, 0.32, 0.30)
const BLUE := Color(0.35, 0.65, 1.0)
const TEXT := Color(0.94, 0.94, 0.96)
const DIM := Color(0.62, 0.64, 0.70)
const PANEL := Color(0.05, 0.06, 0.08, 0.92)
const PANEL_LIGHT := Color(0.12, 0.13, 0.17, 0.95)

static var _theme: Theme
static var _font: Font
static var _bold: Font

static func font(bold: bool = false) -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "DejaVu Sans", "Noto Sans", "sans-serif"])
		_font = f
		var b := SystemFont.new()
		b.font_names = f.font_names
		b.font_weight = 800
		_bold = b
	return _bold if bold else _font

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(Color(0.14, 0.15, 0.19, 0.95), 6, Color(1, 1, 1, 0.06)))
	t.set_stylebox("hover", "Button", box(Color(0.22, 0.23, 0.28, 0.98), 6, ACCENT))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.2), 6, ACCENT))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 6, ACCENT))
	t.set_stylebox("disabled", "Button", box(Color(0.10, 0.10, 0.12, 0.8), 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.BLACK)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 10))
	t.set_stylebox("panel", "Panel", box(PANEL, 10))
	t.set_stylebox("normal", "LineEdit", box(Color(0.1, 0.11, 0.14), 6, Color(1, 1, 1, 0.15)))
	t.set_stylebox("focus", "LineEdit", box(Color(0.1, 0.11, 0.14), 6, ACCENT))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("slider", "HSlider", box(Color(0.2, 0.2, 0.25), 3))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), 3))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.2), 4))
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, 6))
	_theme = t
	return t

static func box(color: Color, radius: int = 8, border: Color = Color(0, 0, 0, 0), border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(border_w)
	return s

static func label(text: String, size: int = 18, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(true))
	return l

static func shadow_label(text: String, size: int, color: Color = TEXT, bold: bool = true) -> Label:
	var l := label(text, size, color, bold)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", max(4, size / 6))
	return l

static func button(text: String, cb: Callable, min_w: int = 0, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_w, 40)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("hover"))
	return b

static func panel(min_size: Vector2 = Vector2.ZERO, color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	var sb := box(color, 12)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	return p

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

static func hfill() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func header(title: String, subtitle: String = "") -> VBoxContainer:
	var v := vbox(2)
	v.add_child(label(title.to_upper(), 30, ACCENT, true))
	if subtitle != "":
		v.add_child(label(subtitle, 15, DIM))
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.12)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	return v

static func scroll(min_size: Vector2) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return s

static func swatch(c: Color, sz: Vector2 = Vector2(26, 26)) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = sz
	return r

static func bar(value: float, color: Color, w: float = 160.0, h: float = 8.0) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.custom_minimum_size = Vector2(w, h)
	var fg := ColorRect.new()
	fg.color = color
	fg.size = Vector2(w * clamp(value, 0.0, 1.0), h)
	bg.add_child(fg)
	return bg

static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()

static func fullscreen_root(owner: Node, dim: float = 0.55) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if dim > 0.0:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, dim)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)
	owner.add_child(root)
	return root

static func centered(root: Control, child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	root.add_child(c)
	return c

class_name UITheme
extends RefCounted
## Shared look & feel: colours, styleboxes, a global Theme and small widget factories.

const COL_BG_TOP := Color("0b1426")
const COL_BG_BOTTOM := Color("1d2b4a")
const COL_PANEL := Color(0.07, 0.10, 0.19, 0.95)
const COL_SAFFRON := Color("ff9933")
const COL_GREEN := Color("138808")
const COL_TEXT := Color("f4f6fb")
const COL_MUTED := Color("9aa6bf")
const COL_DANGER := Color("ff6b6b")
const COL_OK := Color("5fd38d")

static func box(color: Color, radius := 12, border := Color.TRANSPARENT, border_w := 0, pad := Vector2(16, 8)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, box(Color(1, 1, 1, 0.10)))
		t.set_stylebox("hover", cls, box(Color(1, 1, 1, 0.18)))
		t.set_stylebox("pressed", cls, box(Color(1, 1, 1, 0.05)))
		t.set_stylebox("disabled", cls, box(Color(1, 1, 1, 0.04)))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, COL_TEXT)
		t.set_color("font_hover_color", cls, COL_TEXT)
		t.set_color("font_pressed_color", cls, COL_TEXT)
		t.set_color("font_focus_color", cls, COL_TEXT)
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.35))
		t.set_font_size("font_size", cls, 20)
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_stylebox("normal", "LineEdit", box(Color(1, 1, 1, 0.08), 10, Color(1, 1, 1, 0.15), 1, Vector2(14, 12)))
	t.set_stylebox("focus", "LineEdit", box(Color(1, 1, 1, 0.10), 10, COL_SAFFRON, 2, Vector2(14, 12)))
	t.set_color("font_color", "LineEdit", COL_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", COL_MUTED)
	t.set_color("caret_color", "LineEdit", COL_SAFFRON)
	t.set_stylebox("panel", "PopupMenu", box(Color("172036"), 10, Color(1, 1, 1, 0.15), 1, Vector2(8, 6)))
	t.set_stylebox("hover", "PopupMenu", box(Color(1, 0.6, 0.2, 0.35), 6, Color.TRANSPARENT, 0, Vector2(8, 6)))
	t.set_color("font_color", "PopupMenu", COL_TEXT)
	t.set_color("font_hover_color", "PopupMenu", COL_TEXT)
	t.set_color("font_disabled_color", "PopupMenu", Color(1, 1, 1, 0.3))
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.15), 4, Color.TRANSPARENT, 0, Vector2(0, 3)))
	t.set_stylebox("grabber_area", "HSlider", box(COL_SAFFRON, 4, Color.TRANSPARENT, 0, Vector2(0, 3)))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(COL_SAFFRON.lightened(0.15), 4, Color.TRANSPARENT, 0, Vector2(0, 3)))
	return t

static func button(text: String, accent := false, min_height := 54.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	if accent:
		b.add_theme_stylebox_override("normal", box(COL_SAFFRON))
		b.add_theme_stylebox_override("hover", box(COL_SAFFRON.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", box(COL_SAFFRON.darkened(0.15)))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color("1a1206"))
	return b

static func label(text: String, size := 20, color := COL_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

static func line_edit(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 50)
	return e

static func gradient_background() -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([COL_BG_TOP, COL_BG_BOTTOM])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Thin saffron / white / green strip along the top edge.
static func tricolor_strip() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in [COL_SAFFRON, Color.WHITE, COL_GREEN]:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(0, 6)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r)
	return v

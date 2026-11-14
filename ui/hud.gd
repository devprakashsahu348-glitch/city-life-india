class_name GameHUD
extends CanvasLayer
## Gameplay HUD with multi-touch controls handled directly from InputEventScreenTouch/Drag
## (so joystick + jump + camera drag work at the same time). Mouse is emulated as touch on desktop.

signal pause_requested

class TouchPad extends Control:
	var caption := ""
	var is_stick := false
	var held := false:
		set(v):
			held = v
			queue_redraw()
	var knob := Vector2.ZERO:
		set(v):
			knob = v
			queue_redraw()

	func _init(p_caption := "", stick := false) -> void:
		caption = p_caption
		is_stick = stick
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		draw_circle(c, r, Color(1, 1, 1, 0.22 if held else 0.10))
		draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(1, 1, 1, 0.38), 3.0, true)
		if is_stick:
			draw_circle(c + knob * r * 0.6, r * 0.36, Color(1, 1, 1, 0.45 if held else 0.30))
		else:
			var font := ThemeDB.fallback_font
			var ts := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.3), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.92))

var player: Player
var _coins: Label
var _clock: Label
var _joy: TouchPad
var _jump: TouchPad
var _sprint: TouchPad
var _pause_pad: TouchPad
var _roles := {} # touch index -> role

func _init() -> void:
	layer = 5

func _ready() -> void:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.35), 18, Color.TRANSPARENT, 0, Vector2(16, 6)))
	pill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pill.offset_left = 28
	pill.offset_top = 20
	_coins = UITheme.label("", 20, UITheme.COL_SAFFRON)
	pill.add_child(_coins)
	add_child(pill)
	set_coins(int(SaveManager.data["wallet"]["coins"]))

	_clock = UITheme.label("", 20, UITheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_clock.anchor_left = 0.5
	_clock.anchor_right = 0.5
	_clock.offset_left = -100
	_clock.offset_right = 100
	_clock.offset_top = 24
	_clock.offset_bottom = 54
	add_child(_clock)

	var hint := UITheme.label("Phase 1 build - placeholder art. Left stick: move | Drag right side: look", 14, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -300
	hint.offset_right = 300
	hint.offset_top = -34
	hint.offset_bottom = -8
	add_child(hint)

	_joy = _pad("", true, Control.PRESET_BOTTOM_LEFT, 56, 44, 230)
	_jump = _pad("JUMP", false, Control.PRESET_BOTTOM_RIGHT, 56, 56, 124)
	_sprint = _pad("RUN", false, Control.PRESET_BOTTOM_RIGHT, 210, 36, 100)
	_pause_pad = _pad("II", false, Control.PRESET_TOP_RIGHT, 28, 18, 64)

func _pad(caption: String, stick: bool, preset: int, mx: float, my: float, s: float) -> TouchPad:
	var p := TouchPad.new(caption, stick)
	p.set_anchors_preset(preset)
	match preset:
		Control.PRESET_BOTTOM_LEFT:
			p.offset_left = mx; p.offset_right = mx + s; p.offset_bottom = -my; p.offset_top = -my - s
		Control.PRESET_BOTTOM_RIGHT:
			p.offset_right = -mx; p.offset_left = -mx - s; p.offset_bottom = -my; p.offset_top = -my - s
		Control.PRESET_TOP_RIGHT:
			p.offset_right = -mx; p.offset_left = -mx - s; p.offset_top = my; p.offset_bottom = my + s
	add_child(p)
	return p

func set_coins(amount: int) -> void:
	_coins.text = "Coins  %d" % amount

func set_clock(hours: float) -> void:
	_clock.text = "%02d:%02d" % [int(hours), int((hours - floorf(hours)) * 60.0)]

func reset_touches() -> void:
	_roles.clear()
	for p in [_joy, _jump, _sprint, _pause_pad]:
		p.held = false
	_joy.knob = Vector2.ZERO
	if player:
		player.touch_move = Vector2.ZERO
		player.touch_sprint = false

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)

func _hit(pad: TouchPad, pos: Vector2, grow := 14.0) -> bool:
	return pad.get_global_rect().grow(grow).has_point(pos)

func _touch_down(idx: int, pos: Vector2) -> void:
	if _hit(_pause_pad, pos):
		pause_requested.emit()
		reset_touches()
	elif _hit(_jump, pos):
		_roles[idx] = "jump"
		_jump.held = true
		player.queue_jump()
	elif _hit(_sprint, pos):
		_roles[idx] = "sprint"
		_sprint.held = true
		player.touch_sprint = true
	elif _hit(_joy, pos, 30.0):
		_roles[idx] = "joy"
		_joy.held = true
		_update_stick(pos)
	elif pos.x > get_viewport().get_visible_rect().size.x * 0.35:
		_roles[idx] = "cam"

func _touch_drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	match _roles.get(idx, ""):
		"joy": _update_stick(pos)
		"cam": player.add_look(rel)

func _touch_up(idx: int) -> void:
	match _roles.get(idx, ""):
		"joy":
			_joy.held = false
			_joy.knob = Vector2.ZERO
			player.touch_move = Vector2.ZERO
		"jump": _jump.held = false
		"sprint":
			_sprint.held = false
			player.touch_sprint = false
	_roles.erase(idx)

func _update_stick(pos: Vector2) -> void:
	var rect := _joy.get_global_rect()
	var v := ((pos - rect.get_center()) / (rect.size.x * 0.5)).limit_length(1.0)
	_joy.knob = v
	var deadzone := 0.12
	if v.length() < deadzone:
		player.touch_move = Vector2.ZERO
	else:
		player.touch_move = (v * float(Game.get_setting("control_sensitivity"))).limit_length(1.0)

class_name PauseMenu
extends CanvasLayer
## In-game pause overlay. Also handles Esc / Android Back (toggle pause, or close Settings).

signal toggle_requested
signal exit_requested

var _settings: SettingsPanel

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.COL_PANEL, 22, Color(1, 1, 1, 0.12), 1, Vector2(34, 26)))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(UITheme.label("PAUSED", 34, UITheme.COL_SAFFRON, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UITheme.button("Resume", true)
	resume.pressed.connect(func() -> void: toggle_requested.emit())
	col.add_child(resume)
	var settings := UITheme.button("Settings")
	settings.pressed.connect(_open_settings)
	col.add_child(settings)
	var leave := UITheme.button("Save & Exit to Menu")
	leave.pressed.connect(func() -> void: exit_requested.emit())
	col.add_child(leave)

func _open_settings() -> void:
	_settings = SettingsPanel.new()
	add_child(_settings)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()

func _on_back() -> void:
	if _settings != null and is_instance_valid(_settings):
		_settings.close()
	else:
		toggle_requested.emit()

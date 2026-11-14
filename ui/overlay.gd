class_name Overlay
extends Control
## Modal dialog: dimmed backdrop, titled panel, scrollable [member content], Close button.

signal closed

var content: VBoxContainer

func _init(title_text := "", width := 640.0) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.COL_PANEL, 22, Color(1, 1, 1, 0.12), 1, Vector2(28, 22)))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(UITheme.label(title_text, 30, UITheme.COL_SAFFRON))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	var close_btn := UITheme.button("Close", true, 48)
	close_btn.pressed.connect(close)
	col.add_child(close_btn)

func close() -> void:
	closed.emit()
	queue_free()

## Adds "label .... control" row to [member content].
func add_row(text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_child(UITheme.label(text, 20))
	row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 260.0)
	row.add_child(control)
	content.add_child(row)

func add_note(text: String, color := UITheme.COL_MUTED) -> void:
	var l := UITheme.label(text, 16, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	content.add_child(l)

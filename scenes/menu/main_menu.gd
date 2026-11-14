extends Control
## Main menu. Features that are not built yet are shown disabled with the phase that adds them.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UITheme.gradient_background())
	add_child(UITheme.tricolor_strip())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	row.add_child(_build_title())
	row.add_child(_build_buttons())

func _build_title() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.add_child(UITheme.label("CITY LIFE", 64))
	col.add_child(UITheme.label("INDIA", 92, UITheme.COL_SAFFRON))
	col.add_child(UITheme.label("Drive. Explore. Live the city.", 22, UITheme.COL_MUTED))
	var ver := UITheme.label("v0.1.0  |  Phase 1 build  |  placeholder art", 14, UITheme.COL_MUTED)
	ver.custom_minimum_size.y = 40
	ver.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	col.add_child(ver)
	return col

func _build_buttons() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(390, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 9)
	var p: Dictionary = SaveManager.data["profile"]
	var chip := UITheme.label("%s   Lv %d   |   %d coins" % [str(p["username"]), int(p["level"]), int(SaveManager.data["wallet"]["coins"])], 18, UITheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(chip)
	col.add_child(_btn("Play", true, _on_play))
	var cont := _btn("Continue", false, _on_continue)
	cont.disabled = not SaveManager.has_progress()
	col.add_child(cont)
	col.add_child(_disabled_btn("Garage", "Phase 4"))
	col.add_child(_disabled_btn("Missions", "Phase 2"))
	col.add_child(_btn("Profile", false, _on_profile))
	col.add_child(_btn("Settings", false, func() -> void: add_child(SettingsPanel.new())))
	col.add_child(_disabled_btn("Store", "later"))
	col.add_child(_btn("Exit", false, _on_exit))
	return col

func _btn(text: String, accent: bool, action: Callable) -> Button:
	var b := UITheme.button(text, accent, 48)
	b.pressed.connect(action)
	return b

func _disabled_btn(text: String, when: String) -> Button:
	var b := UITheme.button("%s   (%s)" % [text, when], false, 48)
	b.disabled = true
	return b

func _on_play() -> void:
	if SaveManager.has_progress():
		var dlg := ConfirmationDialog.new()
		dlg.title = "New game"
		dlg.dialog_text = "Start a new game? Your coins, level and position will be reset. Use Continue to keep them."
		dlg.confirmed.connect(_start_new_game)
		add_child(dlg)
		dlg.popup_centered()
	else:
		_start_new_game()

func _start_new_game() -> void:
	SaveManager.reset_progress()
	Game.go_to(Game.SCENE_CITY)

func _on_continue() -> void:
	Game.go_to(Game.SCENE_CITY)

func _on_profile() -> void:
	var o := Overlay.new("Profile")
	var p: Dictionary = SaveManager.data["profile"]
	o.add_row("Username", UITheme.label(str(p["username"]), 20, UITheme.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	o.add_row("Player ID", UITheme.label(str(p["player_id"]), 20, UITheme.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	o.add_row("Level", UITheme.label(str(int(p["level"])), 20, UITheme.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	o.add_row("Coins", UITheme.label(str(int(SaveManager.data["wallet"]["coins"])), 20, UITheme.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	o.add_row("Account type", UITheme.label(AuthManager.mode_label(), 20, UITheme.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	o.add_note("Profile pictures, achievements and cloud save arrive in later phases.")
	add_child(o)

func _on_exit() -> void:
	SaveManager.save_game()
	get_tree().quit()

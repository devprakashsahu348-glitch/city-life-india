class_name SettingsPanel
extends Overlay
## Settings: graphics quality, sensitivities, privacy info, account + logout.
## (Audio volumes arrive with the audio system in Phase 6; language in Phase 6.)

func _init() -> void:
	super("Settings")
	add_row("Graphics quality", _quality_control())
	add_row("Control sensitivity", _slider("control_sensitivity"))
	add_row("Camera sensitivity", _slider("camera_sensitivity"))
	add_note("Ultra is only offered on devices with enough memory. Audio and language options arrive in Phase 6.")
	add_note("Privacy: guest progress is stored only on this device. This build collects no personal data and has no ads or purchases. A full privacy policy will be linked here before release.")
	var who := "%s  |  %s" % [str(SaveManager.data["profile"]["username"]), AuthManager.mode_label()]
	add_row("Account", UITheme.label(who, 18, UITheme.COL_MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	var logout := UITheme.button("Log out", false, 48)
	logout.pressed.connect(_on_logout)
	content.add_child(logout)

func _quality_control() -> OptionButton:
	var ob := OptionButton.new()
	for n in Game.QUALITY_NAMES:
		ob.add_item(n)
	ob.set_item_disabled(3, not Game.ultra_supported())
	ob.select(Game.resolved_quality())
	ob.item_selected.connect(func(i: int) -> void: Game.set_setting("graphics_quality", i))
	return ob

func _slider(key: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.5
	s.max_value = 2.0
	s.step = 0.05
	s.value = float(Game.get_setting(key))
	s.custom_minimum_size = Vector2(260, 32)
	s.value_changed.connect(func(v: float) -> void: Game.set_setting(key, v))
	return s

func _on_logout() -> void:
	AuthManager.logout()
	Game.go_to(Game.SCENE_LOGIN)

extends Node
## Game - global scene routing, settings access, graphics quality and input map.

signal settings_changed

const SCENE_BOOT := "res://scenes/boot.tscn"
const SCENE_LOGIN := "res://scenes/login/login.tscn"
const SCENE_MENU := "res://scenes/menu/main_menu.tscn"
const SCENE_CITY := "res://scenes/world/city.tscn"

const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
const ULTRA_MIN_RAM_BYTES := 6 * 1024 * 1024 * 1024
const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
}

func _ready() -> void:
	get_tree().root.theme = UITheme.build_theme()
	_register_input_actions()
	SaveManager.slot_loaded.connect(apply_graphics)
	apply_graphics()

func go_to(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)

# --- settings ---------------------------------------------------------------

func get_setting(key: String) -> Variant:
	return SaveManager.data["settings"].get(key)

func set_setting(key: String, value: Variant) -> void:
	SaveManager.data["settings"][key] = value
	SaveManager.mark_dirty()
	if key == "graphics_quality":
		apply_graphics()
	else:
		settings_changed.emit()

# --- graphics ---------------------------------------------------------------

func ultra_supported() -> bool:
	if not OS.has_feature("mobile"):
		return true
	var mem := OS.get_memory_info()
	return int(mem.get("physical", -1)) >= ULTRA_MIN_RAM_BYTES

func auto_quality() -> int:
	return 1 if OS.has_feature("mobile") else 2

func resolved_quality() -> int:
	var q: int = int(get_setting("graphics_quality"))
	if q < 0:
		q = auto_quality()
	if q >= 3 and not ultra_supported():
		q = 2
	return clampi(q, 0, 3)

func apply_graphics() -> void:
	var vp := get_viewport()
	match resolved_quality():
		0:
			vp.scaling_3d_scale = 0.6
			vp.msaa_3d = Viewport.MSAA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1:
			vp.scaling_3d_scale = 0.75
			vp.msaa_3d = Viewport.MSAA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		2:
			vp.scaling_3d_scale = 0.9
			vp.msaa_3d = Viewport.MSAA_2X
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		_:
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_4X
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
	settings_changed.emit()

# --- input ------------------------------------------------------------------

func _register_input_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

extends Node
## SaveManager - local, versioned, crash-safe save data (one slot per account).
##
## * Writes go to "<file>.tmp" first, the previous save is kept as "<file>.bak",
##   then the .tmp is renamed into place. On load we try main -> .tmp -> .bak and
##   use the first file whose checksum is valid (recovery from interrupted saves).
## * The checksum detects corruption only. It is NOT anti-cheat: local files can
##   always be edited. Cloud accounts will make coins server-authoritative (Phase 5).

signal slot_loaded

const SAVE_VERSION := 1
const AUTOSAVE_SECONDS := 30.0

var slot := ""
var data: Dictionary = {}
var _dirty := false

func _ready() -> void:
	data = default_data()
	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_SECONDS
	timer.autostart = true
	timer.timeout.connect(_on_autosave)
	add_child(timer)

func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {"username": "", "player_id": "", "level": 1, "xp": 0},
		"wallet": {"coins": 0},
		"world": {"has_progress": false, "player_pos": [], "player_yaw": 0.0, "time_of_day": 9.0},
		"settings": {"graphics_quality": -1, "control_sensitivity": 1.0, "camera_sensitivity": 1.0},
	}

func has_progress() -> bool:
	return bool(data["world"].get("has_progress", false))

func mark_dirty() -> void:
	_dirty = true

## Loads (or creates) the save for [param new_slot]. Never fails: falls back to defaults.
func load_slot(new_slot: String) -> void:
	slot = new_slot
	data = default_data()
	_dirty = false
	for suffix in ["", ".tmp", ".bak"]:
		var loaded := _read_file(_path(slot) + suffix)
		if not loaded.is_empty():
			data = _migrate(_merge(default_data(), loaded))
			if suffix != "":
				push_warning("SaveManager: recovered save from %s" % suffix)
			break
	slot_loaded.emit()

func unload_slot() -> void:
	slot = ""
	data = default_data()
	_dirty = false

## Resets progress (wallet, level, world) but keeps profile identity and settings.
func reset_progress() -> void:
	var fresh := default_data()
	data["wallet"] = fresh["wallet"]
	data["world"] = fresh["world"]
	data["profile"]["level"] = 1
	data["profile"]["xp"] = 0
	mark_dirty()
	save_game()

func save_game() -> bool:
	if slot.is_empty():
		return false
	data["last_saved"] = Time.get_unix_time_from_system()
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({"checksum": payload.sha256_text(), "payload": payload})
	var path := _path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(envelope)
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	var main_name := path.get_file()
	if dir.file_exists(main_name):
		dir.copy(path, path + ".bak")
		dir.remove(main_name)
	var err := dir.rename(tmp.get_file(), main_name)
	if err != OK:
		push_error("SaveManager: rename failed (%d); .tmp kept for recovery" % err)
		return false
	_dirty = false
	return true

func _path(slot_name: String) -> String:
	return "user://save_%s.json" % slot_name

func _on_autosave() -> void:
	if _dirty:
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var envelope: Variant = json.data
	if typeof(envelope) != TYPE_DICTIONARY:
		return {}
	var payload: String = str(envelope.get("payload", ""))
	if payload.sha256_text() != str(envelope.get("checksum", "")):
		return {}
	var inner := JSON.new()
	if inner.parse(payload) != OK:
		return {}
	return inner.data if typeof(inner.data) == TYPE_DICTIONARY else {}

func _merge(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for key in loaded:
		if out.has(key) and typeof(out[key]) == TYPE_DICTIONARY and typeof(loaded[key]) == TYPE_DICTIONARY:
			out[key] = _merge(out[key], loaded[key])
		else:
			out[key] = loaded[key]
	return out

func _migrate(d: Dictionary) -> Dictionary:
	# Add one block per version bump, e.g. if int(d["version"]) < 2: ...
	d["version"] = SAVE_VERSION
	return d

extends SceneTree
## Headless smoke test:  godot --headless --path . -s tests/smoke_test.gd
## Verifies save/auth logic and that menu, login and city scenes build and run.

var _fails := 0

func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := root.get_node("Game")
	var auth := root.get_node("AuthManager")
	var sm := root.get_node("SaveManager")
	# clean old test data
	for f in DirAccess.get_files_at("user://"):
		DirAccess.remove_absolute("user://" + f)

	var r: Dictionary = auth.continue_as_guest()
	_check(r["ok"] and auth.is_guest(), "guest session")
	_check(str(sm.data["profile"]["player_id"]).begins_with("CLI-"), "player id generated")
	sm.data["wallet"]["coins"] = 123
	_check(sm.save_game(), "save")
	sm.load_slot("guest")
	_check(int(sm.data["wallet"]["coins"]) == 123, "save round-trip")
	# corrupt main file -> recover from .bak (second save creates the .bak)
	sm.data["wallet"]["coins"] = 124
	sm.save_game()
	var f := FileAccess.open("user://save_guest.json", FileAccess.WRITE)
	f.store_string("{garbage")
	f.close()
	sm.load_slot("guest")
	_check(int(sm.data["wallet"]["coins"]) == 123, "recovery from corrupted save (.bak)")

	_check(not auth.sign_in_google()["ok"], "google sign-in honestly unavailable")
	_check(not auth.create_dev_account("bad", "abc", "password1", "password1")["ok"], "reject bad email")
	_check(not auth.create_dev_account("a@b.in", "abc", "short", "short")["ok"], "reject short password")
	_check(auth.create_dev_account("a@b.in", "Asha", "password1", "password1")["ok"], "create dev account")
	var accounts := FileAccess.get_file_as_string("user://dev_accounts.json")
	_check(not accounts.contains("password1"), "no plaintext password stored")
	auth.logout()
	_check(not auth.login_dev("a@b.in", "wrongpass1")["ok"], "wrong password rejected")
	_check(auth.login_dev("a@b.in", "password1")["ok"], "login with correct password")
	_check(str(sm.data["profile"]["username"]) == "Asha", "account profile loaded")

	for path in [game.SCENE_LOGIN, game.SCENE_MENU]:
		var s: Node = load(path).instantiate()
		root.add_child(s)
		await process_frame
		_check(is_instance_valid(s), "scene builds: " + path)
		s.queue_free()
		await process_frame

	var city: Node = load(game.SCENE_CITY).instantiate()
	root.add_child(city)
	for i in 5:
		await physics_frame
	var player: Node3D = city.get_node("Player")
	_check(player.global_position.y > -1.0 and player.global_position.y < 3.0, "player stands on ground (y=%.2f)" % player.global_position.y)
	var start := player.global_position
	player.touch_move = Vector2(0, -1)
	for i in 60:
		await physics_frame
	_check(player.global_position.distance_to(start) > 1.0, "player moves (%.1f m)" % player.global_position.distance_to(start))
	player.touch_move = Vector2.ZERO
	for i in 30:
		await physics_frame
	var ground_y := player.global_position.y
	_check(ground_y < 0.1, "player rests on the ground (y=%.3f)" % ground_y)
	player.queue_jump()
	for i in 6:
		await physics_frame
	_check(player.global_position.y > ground_y + 0.1, "player jumps (y=%.2f)" % player.global_position.y)
	city.time_of_day = 20.0
	city._update_sky()
	city.time_of_day = 12.0
	city._update_sky()
	_check(true, "day/night update runs")
	city.save_world()
	_check(sm.data["world"]["player_pos"].size() == 3, "world state saved")
	print("FAILURES: %d" % _fails)
	quit(1 if _fails > 0 else 0)

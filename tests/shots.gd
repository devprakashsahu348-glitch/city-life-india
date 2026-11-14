extends SceneTree
## Screenshot helper (needs a display / xvfb): godot --rendering-method gl_compatibility -s tests/shots.gd
func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/home/claude/shots/%s.png" % name)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("AuthManager").continue_as_guest()
	root.get_node("SaveManager").data["wallet"]["coins"] = 250
	var s: Node = load("res://scenes/login/login.tscn").instantiate()
	root.add_child(s); await _shot("1_login"); s.queue_free(); await process_frame
	s = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(s); await _shot("2_menu"); s.queue_free(); await process_frame
	var city: Node = load("res://scenes/world/city.tscn").instantiate()
	root.add_child(city)
	for i in 40: await physics_frame
	var p: Node3D = city.get_node("Player")
	p.yaw = 0.0
	p.pitch = -0.25
	await _shot("3_city_morning")
	p.global_position = Vector3(35, 0.6, 130); p.yaw = 0.0
	city.time_of_day = 17.9; city._update_sky(); await _shot("4_city_sunset")
	p.global_position = Vector3(35, 0.6, 20); p.yaw = 0.6; p.pitch = -0.1
	city.time_of_day = 12.0; city._update_sky(); await _shot("5_city_noon")
	city.time_of_day = 21.0; city._update_sky(); await _shot("6_city_night")
	quit()

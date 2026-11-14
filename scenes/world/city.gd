extends Node3D
## Phase 1 city: procedurally generated grid of blocks (placeholder art), day/night cycle,
## player, HUD and pause menu. Each block is its own Node3D ("Block_i_j") so later phases can
## stream sections in/out instead of loading the whole city.

const BLOCK_SIZE := 56.0
const ROAD_WIDTH := 14.0
const PITCH := BLOCK_SIZE + ROAD_WIDTH
const GRID_RADIUS := 2
const EXTENT := (GRID_RADIUS + 0.5) * PITCH + ROAD_WIDTH * 0.5
const DAY_LENGTH_SECONDS := 1200.0
const SHOP_NAMES := ["SHARMA SWEETS", "CHAI TAPRI", "CITY MEDICAL", "GUPTA KIRANA", "RAJ ELECTRONICS", "PUNJABI DHABA", "MOBILE POINT", "FRESH JUICE", "BOMBAY BAKERY", "AUTO PARTS", "SAREE HOUSE", "TIFFIN CENTRE"]
const PALETTE := [Color("e8c36a"), Color("d98a5f"), Color("5fa8a0"), Color("d96f8a"), Color("c9c1b0"), Color("8fb3d9"), Color("e5a14f"), Color("a9c27a")]

var time_of_day := 9.0

var _rng := RandomNumberGenerator.new()
var _mats := {}
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _player: Player
var _hud: GameHUD
var _pause: PauseMenu
var _sky_timer := 0.0

func _ready() -> void:
	_rng.seed = 1947
	time_of_day = float(SaveManager.data["world"]["time_of_day"])
	_build_environment()
	_build_ground()
	_build_roads()
	_build_blocks()
	_build_boundaries()
	_spawn_player()
	_build_ui()
	var t := Timer.new()
	t.wait_time = 20.0
	t.autostart = true
	t.timeout.connect(save_world)
	add_child(t)
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()
	_update_sky()
	SaveManager.data["world"]["has_progress"] = true
	save_world()

func _process(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta * 24.0 / DAY_LENGTH_SECONDS, 24.0)
	_sky_timer += delta
	if _sky_timer >= 0.25:
		_sky_timer = 0.0
		_update_sky()
		_hud.set_clock(time_of_day)

func save_world() -> void:
	if _player == null:
		return
	var st := _player.get_save_state()
	SaveManager.data["world"]["player_pos"] = st["pos"]
	SaveManager.data["world"]["player_yaw"] = st["yaw"]
	SaveManager.data["world"]["time_of_day"] = time_of_day
	SaveManager.data["world"]["has_progress"] = true
	SaveManager.mark_dirty()
	SaveManager.save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_world()

# --- environment ------------------------------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.0025
	_env.fog_sky_affect = 0.5
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	add_child(_sun)

func _update_sky() -> void:
	var a := (time_of_day - 6.0) / 24.0 * TAU # 0 = sunrise, PI/2 = noon, PI = sunset
	var s := sin(a)
	var dir := -Vector3(cos(a), s, 0.35).normalized()
	_sun.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3.ZERO)
	var day := smoothstep(-0.12, 0.25, s)
	var warm := clampf(1.0 - absf(s) * 5.0, 0.0, 1.0) * 0.9
	var top := Color(0.02, 0.03, 0.08).lerp(Color(0.25, 0.5, 0.85), day)
	var horizon := Color(0.08, 0.10, 0.18).lerp(Color(0.65, 0.78, 0.92), day).lerp(Color(1.0, 0.55, 0.25), warm)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon.darkened(0.5)
	_env.fog_light_color = horizon
	_env.ambient_light_color = Color(0.12, 0.15, 0.30).lerp(Color(0.62, 0.68, 0.80), day)
	_env.ambient_light_energy = lerpf(0.9, 0.7, day)
	_sun.light_energy = clampf(s * 2.2, 0.0, 1.4)
	_sun.light_color = Color.WHITE.lerp(Color(1.0, 0.65, 0.4), warm)
	_sun.visible = s > -0.05

func _apply_quality() -> void:
	var q := Game.resolved_quality()
	_sun.shadow_enabled = q >= 1
	_sun.directional_shadow_max_distance = [60.0, 100.0, 150.0, 250.0][q]
	_env.glow_enabled = q >= 2

# --- world geometry ---------------------------------------------------------

func _mat(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), roughness]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]

func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, collide := false) -> Node3D:
	var node: Node3D
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	if collide:
		var body := StaticBody3D.new()
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		node = body
	else:
		node = mi
	node.position = pos
	parent.add_child(node)
	return node

func _build_ground() -> void:
	_box(self, Vector3(1000, 0.2, 1000), Vector3(0, -0.1, 0), Color("6b5f4a"), true)

func _build_roads() -> void:
	var roads := Node3D.new()
	roads.name = "Roads"
	add_child(roads)
	var asphalt := Color("2b2d31")
	var positions: Array[float] = []
	for k in range(-GRID_RADIUS - 1, GRID_RADIUS + 1):
		positions.append((k + 0.5) * PITCH)
	for p in positions:
		_box(roads, Vector3(ROAD_WIDTH, 0.04, EXTENT * 2.0), Vector3(p, 0.02, 0), asphalt)
		_box(roads, Vector3(EXTENT * 2.0, 0.04, ROAD_WIDTH), Vector3(0, 0.022, p), asphalt)
	# Dashed centre lines as one MultiMesh (a single draw call).
	var xforms: Array[Transform3D] = []
	for p in positions:
		var t := -EXTENT + 3.0
		while t < EXTENT - 3.0:
			if absf(fposmod(t, PITCH) - PITCH * 0.5) >= 8.0:
				xforms.append(Transform3D(Basis.IDENTITY, Vector3(p, 0.05, t)))
				xforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(t, 0.052, p)))
			t += 6.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dash := BoxMesh.new()
	dash.size = Vector3(0.25, 0.02, 2.6)
	mm.mesh = dash
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(Color("e9e6d8"), 0.9)
	roads.add_child(mmi)

func _build_blocks() -> void:
	var city := Node3D.new()
	city.name = "City"
	add_child(city)
	for i in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for j in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var block := Node3D.new()
			block.name = "Block_%d_%d" % [i, j]
			block.position = Vector3(i * PITCH, 0, j * PITCH)
			city.add_child(block)
			var ring := maxi(absi(i), absi(j))
			if ring == 0:
				_build_park(block)
				continue
			_box(block, Vector3(BLOCK_SIZE, 0.04, BLOCK_SIZE), Vector3(0, 0.02, 0), Color("b9b2a3"))
			for lx in [-14.0, 14.0]:
				for lz in [-14.0, 14.0]:
					var w := _rng.randf_range(18.0, 24.0)
					var d := _rng.randf_range(18.0, 24.0)
					var h := _rng.randf_range(18.0, 42.0) if ring == 1 else _rng.randf_range(7.0, 16.0)
					var color: Color = PALETTE[_rng.randi() % PALETTE.size()]
					if ring == 1:
						color = color.lerp(Color("9aa7b8"), 0.55) # glassier "modern" towers
					_make_building(block, Vector3(lx, 0, lz), Vector3(w, h, d), color)

func _make_building(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := _box(parent, size, pos + Vector3(0, size.y * 0.5, 0), color, true)
	_box(body, Vector3(size.x + 0.6, 0.5, size.z + 0.6), Vector3(0, size.y * 0.5, 0), color.darkened(0.25)) # roof edge
	if size.y < 17.0:
		var sign_text: String = SHOP_NAMES[_rng.randi() % SHOP_NAMES.size()]
		var l := Label3D.new()
		l.text = sign_text
		l.font_size = 96
		l.pixel_size = 0.008
		l.outline_size = 16
		l.modulate = Color("fff3c4")
		l.position = Vector3(0, 3.4 - size.y * 0.5, size.z * 0.5 + 0.06)
		body.add_child(l)

func _build_park(block: Node3D) -> void:
	_box(block, Vector3(BLOCK_SIZE, 0.06, BLOCK_SIZE), Vector3(0, 0.03, 0), Color("4f8a3b"))
	var pole := _box(block, Vector3(0.3, 14.0, 0.3), Vector3(0, 7.0, 0), Color("d9d9d9"), true)
	# Tricolour flag (saffron / white / green) - original simple geometry
	var flag_cols := [Color("ff9933"), Color("f5f5f5"), Color("138808")]
	for n in 3:
		_box(pole, Vector3(3.6, 0.7, 0.05), Vector3(1.95, 6.2 - n * 0.7, 0), flag_cols[n])
	var sign_l := Label3D.new()
	sign_l.text = "CITY CENTRE PARK"
	sign_l.font_size = 96
	sign_l.pixel_size = 0.01
	sign_l.outline_size = 16
	sign_l.position = Vector3(0, 2.0, 2.0)
	block.add_child(sign_l)
	for n in 16:
		var p := Vector3(_rng.randf_range(-24, 24), 0, _rng.randf_range(-24, 24))
		if p.length() < 5.0:
			continue
		_box(block, Vector3(0.5, 3.0, 0.5), p + Vector3(0, 1.5, 0), Color("5b3d27"), true)
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.2
		sm.height = 4.4
		crown.mesh = sm
		crown.material_override = _mat(Color("2f6b2a"))
		crown.position = p + Vector3(0, 4.4, 0)
		block.add_child(crown)

func _build_boundaries() -> void:
	var walls := Node3D.new()
	walls.name = "Boundaries"
	add_child(walls)
	var span := EXTENT * 2.0 + 4.0
	for side in [-1.0, 1.0]:
		var wx := StaticBody3D.new()
		wx.position = Vector3(side * (EXTENT + 1.0), 15, 0)
		var cx := CollisionShape3D.new()
		var sx := BoxShape3D.new()
		sx.size = Vector3(2, 30, span)
		cx.shape = sx
		wx.add_child(cx)
		walls.add_child(wx)
		var wz := StaticBody3D.new()
		wz.position = Vector3(0, 15, side * (EXTENT + 1.0))
		var cz := CollisionShape3D.new()
		var sz := BoxShape3D.new()
		sz.size = Vector3(span, 30, 2)
		cz.shape = sz
		wz.add_child(cz)
		walls.add_child(wz)

# --- player & UI --------------------------------------------------------------

func _spawn_player() -> void:
	_player = Player.new()
	_player.name = "Player"
	add_child(_player)
	var w: Dictionary = SaveManager.data["world"]
	var pos: Array = w["player_pos"]
	if pos.size() == 3:
		_player.global_position = Vector3(float(pos[0]), float(pos[1]) + 0.2, float(pos[2]))
		_player.yaw = float(w["player_yaw"])
	else:
		_player.global_position = _player.spawn_point

func _build_ui() -> void:
	_hud = GameHUD.new()
	_hud.player = _player
	_hud.pause_requested.connect(func() -> void: _set_paused(true))
	add_child(_hud)
	_pause = PauseMenu.new()
	_pause.toggle_requested.connect(func() -> void: _set_paused(not get_tree().paused))
	_pause.exit_requested.connect(_exit_to_menu)
	add_child(_pause)

func _set_paused(p: bool) -> void:
	get_tree().paused = p
	_pause.visible = p
	_hud.visible = not p
	if p:
		_hud.reset_touches()
		save_world()

func _exit_to_menu() -> void:
	save_world()
	Game.go_to(Game.SCENE_MENU)

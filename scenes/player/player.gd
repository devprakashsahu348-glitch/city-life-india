class_name Player
extends CharacterBody3D
## Third-person player controller + camera rig (spring arm with collision).
## Body mesh is a PLACEHOLDER (capsule + head); the Blender character replaces it in Phase 2.

const WALK_SPEED := 3.6
const RUN_SPEED := 7.2
const JUMP_VELOCITY := 5.2
const GROUND_ACCEL := 32.0
const AIR_ACCEL := 8.0
const CAM_DISTANCE := 4.8
const CAM_HEIGHT := 1.55
const PITCH_MIN := -1.15
const PITCH_MAX := 0.45
const KILL_Y := -30.0

## Set by the touch HUD (-1..1 per axis) and by keyboard via the input map.
var touch_move := Vector2.ZERO
var touch_sprint := false
var yaw := 0.0
var pitch := -0.28
var spawn_point := Vector3(35, 0.6, 20)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _jump_queued := false
var _rig: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _model: Node3D

func _ready() -> void:
	_build_body()
	_build_camera_rig()
	_update_rig(1.0)

func queue_jump() -> void:
	_jump_queued = true

func add_look(relative: Vector2) -> void:
	var sens := 0.005 * float(Game.get_setting("camera_sensitivity"))
	yaw -= relative.x * sens
	pitch = clampf(pitch - relative.y * sens, PITCH_MIN, PITCH_MAX)

func get_save_state() -> Dictionary:
	return {"pos": [global_position.x, global_position.y, global_position.z], "yaw": yaw}

func respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)
	_model = Node3D.new()
	add_child(_model)
	_model.add_child(_part(CapsuleMesh.new(), Vector3(0, 0.85, 0), Color("2f5fb3"), 0.3, 1.3))
	_model.add_child(_part(SphereMesh.new(), Vector3(0, 1.62, 0), Color("c68a5b"), 0.17, 0.34))
	_model.add_child(_part(BoxMesh.new(), Vector3(0, 1.62, -0.17), Color("c68a5b"), 0.08, 0.08)) # "nose": shows facing

func _part(mesh: Mesh, pos: Vector3, color: Color, radius: float, height: float) -> MeshInstance3D:
	if mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = radius
		(mesh as CapsuleMesh).height = height
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = radius
		(mesh as SphereMesh).height = height
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = Vector3.ONE * radius
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

func _build_camera_rig() -> void:
	_rig = Node3D.new()
	_rig.top_level = true
	add_child(_rig)
	_arm = SpringArm3D.new()
	_arm.spring_length = CAM_DISTANCE
	_arm.margin = 0.25
	_arm.add_excluded_object(get_rid())
	_rig.add_child(_arm)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.near = 0.1
	_camera.far = 600.0
	_arm.add_child(_camera)
	_camera.make_current()

func _update_rig(weight: float) -> void:
	var target := global_position + Vector3(0, CAM_HEIGHT, 0)
	_rig.global_position = _rig.global_position.lerp(target, weight)
	_rig.rotation = Vector3(pitch, yaw, 0.0)

func _process(delta: float) -> void:
	_update_rig(1.0 - exp(-24.0 * delta))

func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move = (move + touch_move).limit_length(1.0)
	var sprinting := Input.is_action_pressed("sprint") or touch_sprint
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	var dir := Basis(Vector3.UP, yaw) * Vector3(move.x, 0.0, move.y)
	var target := Vector2(dir.x, dir.z) * speed
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if is_on_floor():
		if _jump_queued or Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= _gravity * delta
	_jump_queued = false
	move_and_slide()
	if move.length() > 0.1:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-14.0 * delta))
	if global_position.y < KILL_Y:
		respawn()

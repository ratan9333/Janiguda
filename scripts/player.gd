extends CharacterBody3D
## Player for the Janiguda map. 1 unit = 1 metre.
##
## Third-person by default with a spring arm; V drops to first person, F flies.
## Reads physical keys directly so the project needs no InputMap setup; swap to
## Input.is_action_pressed() when you want rebindable controls.
##
## Character: Mixamo "Vanguard", via the three.js examples (Soldier.glb).
## Animations Idle / Walk / Run are driven from ground speed below.

const WALK_SPEED := 3.0
## Requested: 20x walk speed on Shift. That is 60 m/s - 216 km/h - so it is
## deliberately extreme. Drop the multiplier here to tame it.
const SPRINT_MULTIPLIER := 20.0
const RUN_SPEED := WALK_SPEED * SPRINT_MULTIPLIER
const FLY_SPEED := 40.0
const JUMP_VELOCITY := 6.5
const GRAVITY := 18.0

const ACCELERATION := 14.0
const SPRINT_ACCELERATION := 90.0    # or it would take ~4 s to reach 60 m/s
const DECELERATION := 26.0
const AIR_CONTROL := 0.35
const TURN_SPEED := 12.0

const MOUSE_SENSITIVITY := 0.0024
const PITCH_MIN := deg_to_rad(-80.0)
const PITCH_MAX := deg_to_rad(70.0)

const THIRD_PERSON_ARM := 4.5
const EYE_HEIGHT := 1.62

## Animation playback rates. The run cycle is authored for roughly 4 m/s, so at
## sprint speed it is clamped rather than played 15x and turned into a blur.
const WALK_CYCLE_SPEED := 1.4
const RUN_CYCLE_SPEED := 4.0
const MAX_CYCLE_SCALE := 2.2

@onready var body: Node3D = $Body
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var flying := false
var first_person := false
var anim: AnimationPlayer
var _anim_names := {}
var _current_anim := ""
var _yaw := 0.0
var _pitch := -0.18


func _ready() -> void:
	floor_max_angle = deg_to_rad(52.0)
	# Generous snap: at sprint speed the capsule would otherwise launch off
	# every bump in the terrain.
	floor_snap_length = 0.9
	camera.far = 8000.0
	camera.near = 0.08
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_animation()
	_apply_view()


func _setup_animation() -> void:
	anim = _find_animation_player(body)
	if anim == null:
		push_warning("player: no AnimationPlayer in the character model")
		return
	# Match animation names case-insensitively - exporters differ.
	for n in anim.get_animation_list():
		_anim_names[n.to_lower()] = n
		var a := anim.get_animation(n)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	print("player: animations %s" % [anim.get_animation_list()])


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play(key: String, speed_scale: float) -> void:
	if anim == null:
		return
	var name: String = _anim_names.get(key, "")
	if name == "":
		return
	anim.speed_scale = clampf(speed_scale, 0.4, MAX_CYCLE_SCALE)
	if _current_anim != name:
		anim.play(name, 0.2)
		_current_anim = name


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
		pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				flying = not flying
				velocity = Vector3.ZERO
			KEY_V:
				first_person = not first_person
				_apply_view()


func _apply_view() -> void:
	arm.spring_length = 0.0 if first_person else THIRD_PERSON_ARM
	pivot.position.y = EYE_HEIGHT if first_person else 1.45
	body.visible = not first_person


func _wish_direction() -> Vector3:
	var v := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		v.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		v.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	# Movement follows where the camera looks, not where the body faces.
	return (Basis(Vector3.UP, _yaw) * v).normalized()


func _physics_process(delta: float) -> void:
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)

	if flying:
		var fwd := -pivot.global_transform.basis.z
		var right := pivot.global_transform.basis.x
		var dir := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W):
			dir += fwd
		if Input.is_physical_key_pressed(KEY_S):
			dir -= fwd
		if Input.is_physical_key_pressed(KEY_D):
			dir += right
		if Input.is_physical_key_pressed(KEY_A):
			dir -= right
		if Input.is_physical_key_pressed(KEY_SPACE):
			dir += Vector3.UP
		if Input.is_physical_key_pressed(KEY_CTRL):
			dir += Vector3.DOWN
		velocity = dir.normalized() * FLY_SPEED * (4.0 if sprint else 1.0)
		body.rotation.y = _yaw
		_play("idle", 1.0)
		move_and_slide()
		return

	var wish := _wish_direction()
	var target := wish * (RUN_SPEED if sprint else WALK_SPEED)
	var rate := DECELERATION
	if wish != Vector3.ZERO:
		rate = SPRINT_ACCELERATION if sprint else ACCELERATION
	if not is_on_floor():
		rate *= AIR_CONTROL
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	if is_on_floor():
		velocity.y = JUMP_VELOCITY if Input.is_physical_key_pressed(KEY_SPACE) else 0.0
	else:
		velocity.y -= GRAVITY * delta

	# Face the direction of travel; the camera stays free.
	if wish.length() > 0.01:
		if first_person:
			body.rotation.y = _yaw
		else:
			var want := atan2(-wish.x, -wish.z)
			body.rotation.y = lerp_angle(body.rotation.y, want, TURN_SPEED * delta)
	elif first_person:
		body.rotation.y = _yaw

	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if ground_speed < 0.35:
		_play("idle", 1.0)
	elif ground_speed <= WALK_SPEED * 1.25:
		_play("walk", ground_speed / WALK_CYCLE_SPEED)
	else:
		_play("run", ground_speed / RUN_CYCLE_SPEED)

	move_and_slide()

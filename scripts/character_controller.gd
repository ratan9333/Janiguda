extends CharacterBody3D

## Standalone third-person controller for the character playground.
##
## Deliberately separate from the game's player.gd so character/physics work
## stays isolated from gameplay code until it's ready to merge. No inventory,
## shops or smoking here - just movement feel and animation hookup.
##
## Drives character_rig.gd, so it works with both the box placeholder and an
## imported Mixamo model.

const WALK_SPEED := 2.7
const RUN_SPEED := 6.6
const ACCELERATION := 12.0
const DECELERATION := 18.0
const AIR_CONTROL := 0.35
const JUMP_VELOCITY := 7.2
const GRAVITY := 18.0
const TURN_SPEED := 11.0
const MOUSE_SENSITIVITY := 0.0025

# Game feel
const COYOTE_TIME := 0.12      # jump still works briefly after leaving a ledge
const JUMP_BUFFER := 0.15      # jump pressed just before landing still fires
const RUN_FOV_BONUS := 6.0     # subtle FOV widening at speed

# Kicking (footballs, and anything else in the "kickable" group)
const KICK_RANGE := 2.8
const KICK_POWER := 9.5
var kick_timer := 0.0

var rig
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var base_fov := 62.0

var animation_time := 0.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var was_on_floor := true
var landing_impact := 0.0

# Placeholder limb roots (null when a real model drives itself).
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D


func _ready() -> void:
	_ensure_input()
	rig = get_node("CharacterRig")
	camera_pivot = get_node("CameraPivot")
	spring_arm = get_node("CameraPivot/SpringArm3D")
	camera = get_node("CameraPivot/SpringArm3D/Camera3D")
	base_fov = camera.fov
	left_arm = rig.left_arm
	right_arm = rig.right_arm
	left_leg = rig.left_leg
	right_leg = rig.right_leg
	head = rig.head
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Register movement keys if the scene is run on its own (no main.gd to do it).
func _ensure_input() -> void:
	var bindings := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"run": KEY_SHIFT,
		"kick": KEY_F,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -0.9, 0.5)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()

	if grounded and not was_on_floor:
		landing_impact = clampf(absf(velocity.y) / JUMP_VELOCITY, 0.0, 1.4)
	was_on_floor = grounded

	coyote_timer = COYOTE_TIME if grounded else maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER

	if not grounded:
		velocity.y -= GRAVITY * delta
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	# Variable jump height: releasing early cuts the arc short.
	if velocity.y > 0.0 and not Input.is_action_pressed("jump"):
		velocity.y = move_toward(velocity.y, 0.0, 22.0 * delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_forward := -camera_pivot.global_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	var cam_right := camera_pivot.global_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	var direction := (cam_right * input.x + cam_forward * -input.y).normalized()

	var target_speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	var target := direction * target_speed
	var rate := ACCELERATION if direction.length_squared() > 0.0 else DECELERATION
	if not grounded:
		rate *= AIR_CONTROL
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	if direction.length_squared() > 0.0:
		var local_dir := global_basis.inverse() * direction
		var desired := atan2(-local_dir.x, -local_dir.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, desired, minf(1.0, TURN_SPEED * delta))

	move_and_slide()

	kick_timer = maxf(0.0, kick_timer - delta)
	if Input.is_action_just_pressed("kick") and kick_timer <= 0.0:
		_try_kick()

	var speed := Vector2(velocity.x, velocity.z).length()
	_animate(delta, speed, grounded)
	_camera_feel(delta, speed)


## Kick the nearest ball in front of the player, in the camera's facing
## direction. Anything in the "kickable" group with a kick() method responds.
func _try_kick() -> void:
	kick_timer = 0.4
	var ball := _nearest_kickable()
	if ball == null:
		return
	var dir := -camera_pivot.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	if ball.has_method("kick"):
		ball.kick(dir, KICK_POWER)


func _nearest_kickable() -> Node3D:
	var best: Node3D = null
	var best_distance := KICK_RANGE
	for node in get_tree().get_nodes_in_group("kickable"):
		if node is Node3D:
			var d := global_position.distance_to(node.global_position)
			if d < best_distance:
				best = node
				best_distance = d
	return best


func _animate(delta: float, speed: float, grounded: bool) -> void:
	animation_time += delta * (1.0 + speed * 0.42)
	# A real model drives its own AnimationPlayer.
	if not rig.is_placeholder:
		var clip := "Idle"
		if not grounded:
			clip = "Jump"
		elif speed > RUN_SPEED * 0.6:
			clip = "Run"
		elif speed > 0.18:
			clip = "Walk"
		rig.play(clip)
		return

	if kick_timer > 0.15:
		# Kick: right leg swings forward hard, arms out for balance.
		_lerp(right_leg, -1.35, delta * 22.0)
		_lerp(left_leg, 0.12, delta * 14.0)
		_lerp(left_arm, 0.45, delta * 12.0)
		_lerp(right_arm, -0.35, delta * 12.0)
	elif not grounded:
		_lerp(left_leg, -0.35, delta * 7.0)
		_lerp(right_leg, 0.45, delta * 7.0)
		_lerp(left_arm, 0.30, delta * 7.0)
		_lerp(right_arm, -0.30, delta * 7.0)
	elif speed > 0.18:
		var run_factor := clampf(speed / RUN_SPEED, 0.25, 1.0)
		var stride := sin(animation_time * 3.2) * lerpf(0.42, 0.78, run_factor)
		left_leg.rotation.x = stride
		right_leg.rotation.x = -stride
		left_arm.rotation.x = -stride * lerpf(0.65, 0.92, run_factor)
		right_arm.rotation.x = stride * lerpf(0.65, 0.92, run_factor)
		rig.position.y = absf(sin(animation_time * 3.2)) * lerpf(0.025, 0.065, run_factor)
		rig.rotation.x = lerp(rig.rotation.x, -0.10 * run_factor, delta * 7.0)
	else:
		_lerp(left_leg, 0.0, delta * 9.0)
		_lerp(right_leg, 0.0, delta * 9.0)
		_lerp(left_arm, 0.04, delta * 7.0)
		_lerp(right_arm, -0.04, delta * 7.0)
		rig.position.y = sin(animation_time * 2.0) * 0.008
		rig.rotation.x = lerp(rig.rotation.x, 0.0, delta * 7.0)

	if head:
		head.rotation.z = sin(animation_time * 1.5) * 0.012
	# Absorb landings with a short knee bend.
	if grounded and landing_impact > 0.01:
		rig.position.y -= landing_impact * 0.11


func _camera_feel(delta: float, speed: float) -> void:
	landing_impact = move_toward(landing_impact, 0.0, delta * 3.2)
	if camera == null:
		return
	var ratio := clampf(speed / RUN_SPEED, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, base_fov + RUN_FOV_BONUS * ratio, minf(1.0, delta * 4.0))
	camera.v_offset = lerpf(camera.v_offset, -landing_impact * 0.16, minf(1.0, delta * 12.0))


func _lerp(joint: Node3D, target: float, weight: float) -> void:
	if joint:
		joint.rotation.x = lerp(joint.rotation.x, target, weight)

extends Node3D

## Character workshop controller.
##
## A standalone scene for looking at and tuning the character in isolation -
## no 2 km world, no gameplay. Loads instantly.
##
## Controls:
##   Left-drag      orbit the camera
##   Mouse wheel    zoom
##   Space          toggle turntable auto-spin
##   1              Idle
##   2              Walk
##   3              Run
##   4              Sit / ride pose
##   5              Wave
##   R              reset camera

@export var orbit_sensitivity := 0.008
@export var auto_spin_speed := 0.5

var rig
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var state_label: Label

var yaw := 0.6
var pitch := -0.15
var distance := 4.2
var auto_spin := true
var dragging := false

var pose := "Idle"
var anim_time := 0.0

# Placeholder limb roots, when no imported model is present.
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D


func _ready() -> void:
	rig = get_node("CharacterRig")
	camera_pivot = get_node("CameraPivot")
	spring_arm = get_node("CameraPivot/SpringArm3D")
	state_label = get_node("HUD/StateLabel")
	# character_rig.gd populates these for the placeholder; null for a real model.
	left_arm = rig.left_arm
	right_arm = rig.right_arm
	left_leg = rig.left_leg
	right_leg = rig.right_leg
	head = rig.head
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 0.35, 1.5, 12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 0.35, 1.5, 12.0)
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * orbit_sensitivity
		pitch = clampf(pitch - event.relative.y * orbit_sensitivity, -1.2, 0.6)
		auto_spin = false
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: auto_spin = not auto_spin
			KEY_1: _set_pose("Idle")
			KEY_2: _set_pose("Walk")
			KEY_3: _set_pose("Run")
			KEY_4: _set_pose("Sit")
			KEY_5: _set_pose("Wave")
			KEY_R:
				yaw = 0.6
				pitch = -0.15
				distance = 4.2


func _set_pose(new_pose: String) -> void:
	pose = new_pose
	# A real model plays its own clip; the placeholder is posed by hand below.
	if not rig.is_placeholder:
		rig.play(new_pose)
	_update_label()


func _update_label() -> void:
	if state_label:
		var source := "placeholder boxes" if rig.is_placeholder else "imported model"
		state_label.text = "Pose: %s  (%s)\n1 Idle  2 Walk  3 Run  4 Sit  5 Wave  |  Space spin  R reset" % [pose, source]


func _process(delta: float) -> void:
	if auto_spin:
		yaw += auto_spin_speed * delta
	camera_pivot.rotation.y = yaw
	camera_pivot.rotation.x = pitch
	spring_arm.spring_length = distance

	anim_time += delta
	if rig.is_placeholder:
		_pose_placeholder(delta)


## Hand-animate the box character so poses are visible without a real model.
func _pose_placeholder(delta: float) -> void:
	var speed := 6.0
	match pose:
		"Walk":
			var s := sin(anim_time * 4.0) * 0.5
			_lerp_rot(left_leg, s, speed)
			_lerp_rot(right_leg, -s, speed)
			_lerp_rot(left_arm, -s * 0.7, speed)
			_lerp_rot(right_arm, s * 0.7, speed)
			rig.position.y = absf(sin(anim_time * 4.0)) * 0.04
		"Run":
			var s := sin(anim_time * 6.5) * 0.8
			_lerp_rot(left_leg, s, speed)
			_lerp_rot(right_leg, -s, speed)
			_lerp_rot(left_arm, -s * 0.9, speed)
			_lerp_rot(right_arm, s * 0.9, speed)
			rig.position.y = absf(sin(anim_time * 6.5)) * 0.07
			rig.rotation.x = lerp(rig.rotation.x, -0.14, delta * speed)
		"Sit":
			# Character faces -Z, so a forward swing is a POSITIVE x-rotation.
			# Thighs come forward, hands rest forward on the knees.
			_lerp_rot(left_leg, 1.35, speed)
			_lerp_rot(right_leg, 1.35, speed)
			_lerp_rot(left_arm, 0.95, speed)
			_lerp_rot(right_arm, 0.95, speed)
			rig.rotation.x = lerp(rig.rotation.x, 0.0, delta * speed)
		"Wave":
			_lerp_rot(left_leg, 0.0, speed)
			_lerp_rot(right_leg, 0.0, speed)
			_lerp_rot(left_arm, 0.05, speed)
			right_arm.rotation.x = lerp(right_arm.rotation.x, -2.6, delta * speed)
			right_arm.rotation.z = lerp(right_arm.rotation.z, -0.3 + sin(anim_time * 9.0) * 0.25, delta * speed)
			rig.rotation.x = lerp(rig.rotation.x, 0.0, delta * speed)
		_: # Idle
			_lerp_rot(left_leg, 0.0, speed)
			_lerp_rot(right_leg, 0.0, speed)
			_lerp_rot(left_arm, 0.04, speed)
			_lerp_rot(right_arm, -0.04, speed)
			right_arm.rotation.z = lerp(right_arm.rotation.z, 0.0, delta * speed)
			rig.position.y = sin(anim_time * 1.6) * 0.01
			rig.rotation.x = lerp(rig.rotation.x, 0.0, delta * speed)
	if head:
		head.rotation.z = sin(anim_time * 1.4) * 0.02


func _lerp_rot(joint: Node3D, target: float, speed: float) -> void:
	if joint:
		joint.rotation.x = lerp(joint.rotation.x, target, get_process_delta_time() * speed)

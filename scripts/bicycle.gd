extends CharacterBody3D

const MAX_SPEED := 18.0
const BOOST_SPEED := 24.0
const REVERSE_SPEED := 5.0
const PEDAL_ACCELERATION := 9.0
const BRAKE_FORCE := 15.0
const COAST_DRAG := 4.0
const STEERING_SPEED := 1.65

var rider
var bicycle_speed := 0.0
var mounted_time := 0.0
var front_wheel: Node3D
var rear_wheel: Node3D
var visual: Node3D


func _ready() -> void:
	add_to_group("interactable")
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(52.0)
	front_wheel = get_node("BikeVisual/FrontWheel")
	rear_wheel = get_node("BikeVisual/RearWheel")
	visual = get_node("BikeVisual")


func get_interaction_text() -> String:
	return "Press E to ride the bicycle"


func interact(player) -> void:
	if rider:
		return
	rider = player
	mounted_time = 0.0
	player.enter_vehicle(self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5

	if rider:
		mounted_time += delta
		var throttle := float(Input.is_action_pressed("move_forward")) - float(Input.is_action_pressed("move_back"))
		var max_forward := BOOST_SPEED if Input.is_action_pressed("run") else MAX_SPEED
		var target_speed := max_forward * throttle if throttle >= 0.0 else REVERSE_SPEED * throttle
		var rate := BRAKE_FORCE if throttle != 0.0 and signf(target_speed) != signf(bicycle_speed) else PEDAL_ACCELERATION
		bicycle_speed = move_toward(bicycle_speed, target_speed, rate * delta)
		if is_zero_approx(throttle):
			bicycle_speed = move_toward(bicycle_speed, 0.0, COAST_DRAG * delta)
		var steering := Input.get_axis("move_left", "move_right")
		var steering_strength := clampf(absf(bicycle_speed) / 5.0, 0.25, 1.0)
		rotation.y -= steering * STEERING_SPEED * steering_strength * signf(bicycle_speed) * delta
		visual.rotation.z = lerp(visual.rotation.z, -steering * 0.16 * steering_strength, delta * 6.0)
		if Input.is_action_just_pressed("interact") and mounted_time > 0.55:
			dismount()
	else:
		bicycle_speed = move_toward(bicycle_speed, 0.0, COAST_DRAG * delta)
		visual.rotation.z = lerp(visual.rotation.z, 0.0, delta * 6.0)

	var forward := -global_basis.z
	velocity.x = forward.x * bicycle_speed
	velocity.z = forward.z * bicycle_speed
	move_and_slide()
	var wheel_spin := bicycle_speed * delta / 0.55
	front_wheel.rotate_x(wheel_spin)
	rear_wheel.rotate_x(wheel_spin)


func dismount() -> void:
	if not rider:
		return
	var exiting_player = rider
	rider = null
	var exit_position := global_position + global_basis.x * 1.5 + Vector3(0, 0.8, 0)
	exiting_player.exit_vehicle(exit_position)

extends Camera3D

## Free-fly survey camera for inspecting the world base while building.
## Not the gameplay camera - just a way to look around the real map data.
##
## WASD move, mouse look, Shift boost, Space/Ctrl up-down, Esc frees the mouse.

const SPEED := 20.0
const BOOST := 70.0
const SENSITIVITY := 0.0025

var yaw := 0.0
var pitch := -0.2


func _ready() -> void:
	rotation = Vector3(pitch, yaw, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENSITIVITY
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, -1.5, 1.5)
		rotation = Vector3(pitch, yaw, 0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir -= global_basis.z
	if Input.is_physical_key_pressed(KEY_S): dir += global_basis.z
	if Input.is_physical_key_pressed(KEY_A): dir -= global_basis.x
	if Input.is_physical_key_pressed(KEY_D): dir += global_basis.x
	if Input.is_physical_key_pressed(KEY_SPACE): dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL): dir -= Vector3.UP
	var speed := BOOST if Input.is_physical_key_pressed(KEY_SHIFT) else SPEED
	global_position += dir.normalized() * speed * delta

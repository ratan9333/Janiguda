extends CharacterBody3D

signal inventory_changed(count: int, smoked: int, money: int)
signal hint_changed(text: String)

const WALK_SPEED := 2.7
const RUN_SPEED := 6.6
const ACCELERATION := 12.0
const DECELERATION := 18.0
const JUMP_VELOCITY := 7.2
const MOUSE_SENSITIVITY := 0.0025
const TURN_SPEED := 11.0

var cigarettes := 0
var smoked_count := 0
var money := 50
var nearby_interactable
var smoking := false
var camera_pivot: Node3D
var cigarette_visual: MeshInstance3D
var smoke_particles: GPUParticles3D
var character_rig: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D
var animation_time := 0.0
var message_id := 0
var message_active := false
var riding_vehicle
var player_collider: CollisionShape3D
var punching := false
var punch_cooldown := false


func _ready() -> void:
	camera_pivot = get_node("CameraPivot")
	character_rig = get_node("CharacterRig")
	left_arm = get_node("CharacterRig/LeftArm")
	right_arm = get_node("CharacterRig/RightArm")
	left_leg = get_node("CharacterRig/LeftLeg")
	right_leg = get_node("CharacterRig/RightLeg")
	head = get_node("CharacterRig/Head")
	player_collider = get_node("CollisionShape3D")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	create_smoking_effect()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -0.55, 0.35)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if riding_vehicle:
		global_position = riding_vehicle.global_position + riding_vehicle.global_basis * Vector3(0, 1.02, 0.20)
		global_rotation.y = riding_vehicle.global_rotation.y
		character_rig.rotation.y = 0.0
		velocity = Vector3.ZERO
		animate_character(delta, 0.0)
		return

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward := -camera_pivot.global_basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_pivot.global_basis.x
	camera_right.y = 0
	camera_right = camera_right.normalized()
	var direction := (camera_right * input.x + camera_forward * -input.y).normalized()
	var target_speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	var target := direction * target_speed
	var movement_rate := ACCELERATION if direction.length_squared() > 0.0 else DECELERATION
	velocity.x = move_toward(velocity.x, target.x, movement_rate * delta)
	velocity.z = move_toward(velocity.z, target.z, movement_rate * delta)
	if direction.length_squared() > 0.0:
		var local_direction := global_basis.inverse() * direction
		var desired_angle := atan2(-local_direction.x, -local_direction.z)
		character_rig.rotation.y = lerp_angle(character_rig.rotation.y, desired_angle, minf(1.0, TURN_SPEED * delta))
	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	animate_character(delta, horizontal_speed)

	nearby_interactable = find_nearby_interactable()
	if not message_active:
		if nearby_interactable:
			hint_changed.emit(nearby_interactable.get_interaction_text())
		elif cigarettes > 0 and not smoking:
			hint_changed.emit("Press F to smoke")
		elif not smoking:
			hint_changed.emit("")

	if Input.is_action_just_pressed("interact") and nearby_interactable:
		nearby_interactable.interact(self)

	if Input.is_action_just_pressed("smoke") and cigarettes > 0 and not smoking:
		smoke_cigarette()
	if Input.is_action_just_pressed("punch") and not smoking and not punch_cooldown:
		punch()


func animate_character(delta: float, movement_speed: float) -> void:
	animation_time += delta * (1.0 + movement_speed * 0.42)
	if riding_vehicle:
		left_arm.rotation.x = lerp(left_arm.rotation.x, 1.05, delta * 8.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, 1.05, delta * 8.0)
		left_leg.rotation.x = lerp(left_leg.rotation.x, -1.2 + sin(animation_time * 2.0) * 0.22, delta * 8.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, -1.2 - sin(animation_time * 2.0) * 0.22, delta * 8.0)
		character_rig.position.y = -0.28
		character_rig.rotation.x = lerp(character_rig.rotation.x, -0.10, delta * 6.0)
	elif not is_on_floor():
		left_leg.rotation.x = lerp(left_leg.rotation.x, -0.35, delta * 7.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.45, delta * 7.0)
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.30, delta * 7.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, -0.30, delta * 7.0)
		character_rig.rotation.x = lerp(character_rig.rotation.x, -0.08, delta * 5.0)
	elif smoking:
		# Raise the right hand toward the face during the smoking interaction.
		right_arm.rotation.x = lerp(right_arm.rotation.x, 1.85, delta * 7.0)
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.05, delta * 7.0)
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 9.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 9.0)
		character_rig.position.y = sin(animation_time * 2.0) * 0.008
	elif punching:
		right_arm.rotation.x = lerp(right_arm.rotation.x, -1.75, delta * 18.0)
		right_arm.rotation.z = lerp(right_arm.rotation.z, -0.24, delta * 18.0)
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.45, delta * 10.0)
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 10.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 10.0)
	elif movement_speed > 0.18:
		var run_factor := clampf(movement_speed / RUN_SPEED, 0.25, 1.0)
		var stride := sin(animation_time * 3.2) * lerpf(0.42, 0.78, run_factor)
		left_leg.rotation.x = stride
		right_leg.rotation.x = -stride
		left_arm.rotation.x = -stride * lerpf(0.65, 0.92, run_factor)
		right_arm.rotation.x = stride * lerpf(0.65, 0.92, run_factor)
		character_rig.position.y = abs(sin(animation_time * 3.2)) * lerpf(0.025, 0.065, run_factor)
		character_rig.rotation.x = lerp(character_rig.rotation.x, -0.10 * run_factor, delta * 7.0)
	else:
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 9.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 9.0)
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.04, delta * 7.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, -0.04, delta * 7.0)
		character_rig.position.y = sin(animation_time * 2.0) * 0.008
		character_rig.rotation.x = lerp(character_rig.rotation.x, 0.0, delta * 7.0)
	head.rotation.z = sin(animation_time * 1.5) * 0.012
	if not punching:
		right_arm.rotation.z = lerp(right_arm.rotation.z, 0.0, delta * 9.0)


func punch() -> void:
	punching = true
	punch_cooldown = true
	var facing := -character_rig.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var best_target: Node3D
	var best_distance := 2.25
	for node in get_tree().get_nodes_in_group("punchable"):
		if not node is Node3D:
			continue
		var offset: Vector3 = node.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < best_distance and (distance < 0.25 or facing.dot(offset.normalized()) > 0.20):
			best_target = node
			best_distance = distance
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(best_target) and best_target.has_method("receive_punch"):
		best_target.receive_punch(global_position)
	await get_tree().create_timer(0.16).timeout
	punching = false
	await get_tree().create_timer(0.28).timeout
	punch_cooldown = false


func enter_vehicle(vehicle) -> void:
	riding_vehicle = vehicle
	character_rig.rotation.y = 0.0
	player_collider.set_deferred("disabled", true)
	nearby_interactable = null
	show_message("Riding bicycle — W/S pedal, A/D steer, Shift boost, E dismount")


func exit_vehicle(exit_position: Vector3) -> void:
	riding_vehicle = null
	global_position = exit_position
	player_collider.set_deferred("disabled", false)
	character_rig.position = Vector3.ZERO
	character_rig.rotation.x = 0.0
	show_message("Dismounted bicycle")


func find_nearby_interactable():
	var best
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		var distance := global_position.distance_to(node.global_position)
		var interaction_range := 5.2 if node.name == "SpawnBicycle" else 2.4
		if distance < interaction_range and distance < best_distance:
			best = node
			best_distance = distance
	return best


func buy_cigarettes(price: int, quantity: int) -> bool:
	if money < price:
		show_message("Not enough money — one pack costs $%d" % price)
		return false
	money -= price
	cigarettes += quantity
	inventory_changed.emit(cigarettes, smoked_count, money)
	show_message("Bought one cigarette pack for $%d" % price)
	return true


func show_message(text: String) -> void:
	message_id += 1
	var this_message := message_id
	message_active = true
	hint_changed.emit(text)
	await get_tree().create_timer(2.5).timeout
	if this_message == message_id:
		message_active = false
		hint_changed.emit("")


func smoke_cigarette() -> void:
	smoking = true
	cigarettes -= 1
	smoked_count += 1
	inventory_changed.emit(cigarettes, smoked_count, money)
	hint_changed.emit("Smoking... (fictional game interaction)")
	cigarette_visual.visible = true
	smoke_particles.emitting = true
	await get_tree().create_timer(3.5).timeout
	smoke_particles.emitting = false
	cigarette_visual.visible = false
	smoking = false


func create_smoking_effect() -> void:
	cigarette_visual = MeshInstance3D.new()
	var cigarette := CylinderMesh.new()
	cigarette.top_radius = 0.025
	cigarette.bottom_radius = 0.025
	cigarette.height = 0.5
	var cigarette_material := StandardMaterial3D.new()
	cigarette_material.albedo_color = Color("eee8db")
	cigarette.material = cigarette_material
	cigarette_visual.mesh = cigarette
	cigarette_visual.rotation_degrees.z = 90
	cigarette_visual.position = Vector3(0.45, 0.85, -0.35)
	cigarette_visual.visible = false
	add_child(cigarette_visual)

	smoke_particles = GPUParticles3D.new()
	smoke_particles.amount = 30
	smoke_particles.lifetime = 1.4
	smoke_particles.one_shot = false
	smoke_particles.emitting = false
	smoke_particles.position = cigarette_visual.position + Vector3(0.24, 0.03, 0)
	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 22.0
	particle_material.initial_velocity_min = 0.25
	particle_material.initial_velocity_max = 0.55
	particle_material.gravity = Vector3(0, 0.18, 0)
	particle_material.scale_min = 0.08
	particle_material.scale_max = 0.2
	smoke_particles.process_material = particle_material
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.12
	smoke_mesh.height = 0.24
	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.albedo_color = Color(0.8, 0.84, 0.86, 0.38)
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mesh.material = smoke_material
	smoke_particles.draw_pass_1 = smoke_mesh
	add_child(smoke_particles)

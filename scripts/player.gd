extends CharacterBody3D

signal inventory_changed(count: int, smoked: int, money: int)
signal hint_changed(text: String)

const SPEED := 5.2
const ACCELERATION := 16.0
const JUMP_VELOCITY := 7.2
const MOUSE_SENSITIVITY := 0.0025

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


func _ready() -> void:
	camera_pivot = get_node("CameraPivot")
	character_rig = get_node("CharacterRig")
	left_arm = get_node("CharacterRig/LeftArm")
	right_arm = get_node("CharacterRig/RightArm")
	left_leg = get_node("CharacterRig/LeftLeg")
	right_leg = get_node("CharacterRig/RightLeg")
	head = get_node("CharacterRig/Head")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	create_smoking_effect()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -0.55, 0.35)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var target := direction * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCELERATION * delta)
	move_and_slide()
	animate_character(delta, input.length())

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


func animate_character(delta: float, movement_amount: float) -> void:
	animation_time += delta
	if smoking:
		# Raise the right hand toward the face during the smoking interaction.
		right_arm.rotation.x = lerp(right_arm.rotation.x, 1.85, delta * 7.0)
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.05, delta * 7.0)
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 9.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 9.0)
		character_rig.position.y = sin(animation_time * 2.0) * 0.008
	elif movement_amount > 0.05 and is_on_floor():
		var stride := sin(animation_time * 10.0) * 0.62
		left_leg.rotation.x = stride
		right_leg.rotation.x = -stride
		left_arm.rotation.x = -stride * 0.75
		right_arm.rotation.x = stride * 0.75
		character_rig.position.y = abs(sin(animation_time * 10.0)) * 0.035
	else:
		left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, delta * 9.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 9.0)
		left_arm.rotation.x = lerp(left_arm.rotation.x, 0.04, delta * 7.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, -0.04, delta * 7.0)
		character_rig.position.y = sin(animation_time * 2.0) * 0.008
	head.rotation.z = sin(animation_time * 1.5) * 0.012


func find_nearby_interactable():
	var best
	var best_distance := 2.4
	for node in get_tree().get_nodes_in_group("interactable"):
		var distance := global_position.distance_to(node.global_position)
		if distance < best_distance:
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

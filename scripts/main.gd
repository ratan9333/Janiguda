extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const SHOP_SCRIPT := preload("res://scripts/shop.gd")
const NPC_SCRIPT := preload("res://scripts/npc.gd")

var player
var status_label: Label
var hint_label: Label
var inventory_panel: ColorRect
var inventory_label: Label


func _ready() -> void:
	setup_input()
	build_environment()
	build_world()
	build_player()
	build_ui()


func setup_input() -> void:
	var bindings := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"inventory": KEY_I,
		"interact": KEY_E,
		"smoke": KEY_F,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key_event)


func build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("87b9d8")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8d3e6")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


func build_world() -> void:
	add_box("Ground", Vector3(30, 0.3, 30), Vector3(0, -0.15, 0), Color("79a960"), true)
	add_box("Road", Vector3(30, 0.06, 4.5), Vector3(0, 0.03, 0), Color("3f4650"), false)
	add_box("NorthSidewalk", Vector3(30, 0.12, 1.2), Vector3(0, 0.06, -2.8), Color("c8c1b4"), false)
	add_box("SouthSidewalk", Vector3(30, 0.12, 1.2), Vector3(0, 0.06, 2.8), Color("c8c1b4"), false)
	for x in range(-13, 14, 4):
		add_box("RoadLine", Vector3(2.0, 0.03, 0.12), Vector3(x, 0.07, 0), Color("eadb76"), false)

	build_apartment()
	build_shop()
	build_warehouse()
	build_park()

	add_box("WallNorth", Vector3(30, 1.2, 0.4), Vector3(0, 0.6, -15), Color("d9d0bd"), true)
	add_box("WallSouth", Vector3(30, 1.2, 0.4), Vector3(0, 0.6, 15), Color("d9d0bd"), true)
	add_box("WallWest", Vector3(0.4, 1.2, 30), Vector3(-15, 0.6, 0), Color("d9d0bd"), true)
	add_box("WallEast", Vector3(0.4, 1.2, 30), Vector3(15, 0.6, 0), Color("d9d0bd"), true)


func build_apartment() -> void:
	var wall := Color("d97862")
	add_box("ApartmentFloor", Vector3(6, 0.15, 5), Vector3(0, 0.08, -9), Color("d8c8ad"), true)
	add_box("ApartmentBack", Vector3(6, 3.2, 0.3), Vector3(0, 1.6, -11.5), wall, true)
	add_box("ApartmentLeft", Vector3(0.3, 3.2, 5), Vector3(-3, 1.6, -9), wall, true)
	add_box("ApartmentRight", Vector3(0.3, 3.2, 5), Vector3(3, 1.6, -9), wall, true)
	# Split front wall leaves a real doorway the player can walk through.
	add_box("ApartmentFrontLeft", Vector3(2.2, 3.2, 0.3), Vector3(-1.9, 1.6, -6.5), wall, true)
	add_box("ApartmentFrontRight", Vector3(2.2, 3.2, 0.3), Vector3(1.9, 1.6, -6.5), wall, true)
	add_box("ApartmentDoorTop", Vector3(1.6, 0.65, 0.3), Vector3(0, 2.875, -6.5), wall, true)
	add_box("ApartmentRoof", Vector3(6.3, 0.2, 5.3), Vector3(0, 3.3, -9), Color("75483d"), true)
	add_box("Bed", Vector3(1.5, 0.45, 2.2), Vector3(-1.7, 0.3, -10), Color("e5e1d5"), true)
	add_world_label("APARTMENT", Vector3(0, 3.8, -6.3), Color.WHITE)


func build_shop() -> void:
	add_box("ShopBuilding", Vector3(5.2, 3.2, 4.2), Vector3(-9, 1.6, 5.3), Color("e2b956"), true)
	add_box("ShopAwning", Vector3(4.3, 0.25, 1.0), Vector3(-9, 2.25, 3.0), Color("bd4c43"), true)
	add_world_label("CORNER SHOP", Vector3(-9, 2.8, 3.15), Color("fff1ba"))

	var counter := Area3D.new()
	counter.name = "ShopCounter"
	counter.set_script(SHOP_SCRIPT)
	counter.position = Vector3(-9, 1.0, 2.3)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 2.0, 1.5)
	shape_node.shape = shape
	counter.add_child(shape_node)
	add_child(counter)


func build_warehouse() -> void:
	add_box("Warehouse", Vector3(6.2, 4.0, 5.0), Vector3(8.5, 2.0, 5.5), Color("6b7f8e"), true)
	add_box("WarehouseDoor", Vector3(2.8, 2.8, 0.12), Vector3(8.5, 1.4, 2.95), Color("343b42"), false)
	add_world_label("WAREHOUSE", Vector3(8.5, 3.35, 2.85), Color.WHITE)


func build_park() -> void:
	add_box("ParkPath", Vector3(4.0, 0.05, 6.0), Vector3(0, 0.03, 10.5), Color("c6b898"), false)
	add_box("BenchSeat", Vector3(2.2, 0.18, 0.55), Vector3(2.2, 0.65, 9.5), Color("805a38"), true)
	add_box("BenchBack", Vector3(2.2, 0.8, 0.15), Vector3(2.2, 1.0, 9.75), Color("805a38"), true)
	add_tree(Vector3(-4.5, 0, 9.0))
	add_tree(Vector3(5.0, 0, 11.5))
	add_tree(Vector3(-3.0, 0, 13.0))
	add_world_label("PARK", Vector3(0, 2.1, 8.0), Color("efffdf"))
	build_npc(Vector3(-1.8, 1.0, 10.0))


func add_world_label(text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 42
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func add_box(node_name: String, size: Vector3, position: Vector3, color: Color, collision: bool) -> Node3D:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = position
	add_child(root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = make_material(color)
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)

	if collision:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	return root


func add_tree(position: Vector3) -> void:
	var trunk := add_box("Tree", Vector3(0.45, 2.2, 0.45), position + Vector3(0, 1.1, 0), Color("76513a"), true)
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.25
	sphere.height = 2.5
	sphere.material = make_material(Color("4d7f46"))
	crown.mesh = sphere
	crown.position.y = 2.4
	trunk.add_child(crown)


func build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 1.0, -5.0)
	player.rotation_degrees.y = 180.0

	var collider := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.8
	collider.shape = capsule_shape
	player.add_child(collider)

	build_stylized_character(player)

	var camera_pivot := Node3D.new()
	camera_pivot.name = "CameraPivot"
	# Tight, slightly elevated third-person framing similar to an action game.
	camera_pivot.position.y = 1.15
	player.add_child(camera_pivot)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.45, 1.05, 3.35)
	camera.rotation_degrees.x = -10
	camera.fov = 62.0
	camera.current = true
	camera_pivot.add_child(camera)

	# Add the fully assembled player last. Adding it earlier invokes player.gd's
	# _ready() before CameraPivot exists, leaving its camera reference null.
	add_child(player)


func build_stylized_character(character: Node3D) -> void:
	var rig := Node3D.new()
	rig.name = "CharacterRig"
	# The model's forward direction is -Z, away from the follow camera.
	rig.rotation_degrees.y = 0.0
	character.add_child(rig)

	# Torso and clothing.
	add_character_box(rig, "Torso", Vector3(0.72, 0.82, 0.38), Vector3(0, 0.34, 0), Color("375a8c"))
	add_character_box(rig, "ShirtStripe", Vector3(0.74, 0.10, 0.40), Vector3(0, 0.48, 0), Color("e6a84e"))
	add_character_box(rig, "Waist", Vector3(0.62, 0.18, 0.34), Vector3(0, -0.14, 0), Color("202735"))

	# The limb roots are named so player.gd can animate them while walking.
	var left_arm := Node3D.new()
	left_arm.name = "LeftArm"
	left_arm.position = Vector3(-0.47, 0.66, 0)
	rig.add_child(left_arm)
	add_character_box(left_arm, "Sleeve", Vector3(0.23, 0.42, 0.28), Vector3(0, -0.20, 0), Color("375a8c"))
	add_character_box(left_arm, "Forearm", Vector3(0.19, 0.38, 0.20), Vector3(0, -0.56, 0), Color("d6a178"))
	add_character_sphere(left_arm, "Hand", 0.13, Vector3(0, -0.79, 0), Color("d6a178"))

	var right_arm := Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.47, 0.66, 0)
	rig.add_child(right_arm)
	add_character_box(right_arm, "Sleeve", Vector3(0.23, 0.42, 0.28), Vector3(0, -0.20, 0), Color("375a8c"))
	add_character_box(right_arm, "Forearm", Vector3(0.19, 0.38, 0.20), Vector3(0, -0.56, 0), Color("d6a178"))
	add_character_sphere(right_arm, "Hand", 0.13, Vector3(0, -0.79, 0), Color("d6a178"))

	var left_leg := Node3D.new()
	left_leg.name = "LeftLeg"
	left_leg.position = Vector3(-0.19, -0.18, 0)
	rig.add_child(left_leg)
	add_character_box(left_leg, "Trouser", Vector3(0.27, 0.67, 0.30), Vector3(0, -0.31, 0), Color("263047"))
	add_character_box(left_leg, "Shoe", Vector3(0.31, 0.18, 0.49), Vector3(0, -0.70, -0.08), Color("17191e"))

	var right_leg := Node3D.new()
	right_leg.name = "RightLeg"
	right_leg.position = Vector3(0.19, -0.18, 0)
	rig.add_child(right_leg)
	add_character_box(right_leg, "Trouser", Vector3(0.27, 0.67, 0.30), Vector3(0, -0.31, 0), Color("263047"))
	add_character_box(right_leg, "Shoe", Vector3(0.31, 0.18, 0.49), Vector3(0, -0.70, -0.08), Color("17191e"))

	# Head, ears, hair, and a readable cartoon face.
	var head_root := Node3D.new()
	head_root.name = "Head"
	head_root.position = Vector3(0, 1.05, 0)
	rig.add_child(head_root)
	add_character_sphere(head_root, "Face", 0.34, Vector3.ZERO, Color("d6a178"))
	add_character_sphere(head_root, "LeftEar", 0.09, Vector3(-0.32, 0, 0), Color("c98f69"))
	add_character_sphere(head_root, "RightEar", 0.09, Vector3(0.32, 0, 0), Color("c98f69"))
	add_character_box(head_root, "HairTop", Vector3(0.58, 0.17, 0.55), Vector3(0, 0.27, 0.02), Color("33251f"))
	add_character_box(head_root, "HairSide", Vector3(0.62, 0.30, 0.18), Vector3(0, 0.13, 0.21), Color("33251f"))
	add_character_sphere(head_root, "LeftEye", 0.055, Vector3(-0.12, 0.06, -0.30), Color("f7f5ec"))
	add_character_sphere(head_root, "RightEye", 0.055, Vector3(0.12, 0.06, -0.30), Color("f7f5ec"))
	add_character_sphere(head_root, "LeftPupil", 0.024, Vector3(-0.12, 0.055, -0.348), Color("202027"))
	add_character_sphere(head_root, "RightPupil", 0.024, Vector3(0.12, 0.055, -0.348), Color("202027"))
	add_character_box(head_root, "Mouth", Vector3(0.15, 0.025, 0.025), Vector3(0, -0.13, -0.335), Color("713f3e"))


func add_character_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = make_material(color)
	part.mesh = mesh
	part.position = position
	parent.add_child(part)
	return part


func add_character_sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = make_material(color)
	part.mesh = mesh
	part.position = position
	parent.add_child(part)
	return part


func build_npc(position: Vector3) -> void:
	var npc := Area3D.new()
	npc.name = "NeighbourNPC"
	npc.set_script(NPC_SCRIPT)
	npc.position = position
	npc.rotation_degrees.y = 25.0
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	shape_node.shape = shape
	npc.add_child(shape_node)
	build_stylized_character(npc)
	var npc_torso: MeshInstance3D = npc.get_node("CharacterRig/Torso")
	npc_torso.material_override = make_material(Color("6f467f"))
	add_child(npc)


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.03, 0.04, 0.06, 0.78)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(470, 105)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "NEIGHBOURHOOD — VERSION 0.1"
	title.position = Vector2(34, 30)
	title.add_theme_font_size_override("font_size", 20)
	layer.add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(34, 63)
	status_label.text = "Money: $50   |   Cigarettes: 0   |   Smoked: 0"
	layer.add_child(status_label)

	var controls := Label.new()
	controls.position = Vector2(34, 88)
	controls.text = "WASD move • Space jump • E interact • F smoke • I inventory"
	controls.modulate = Color("b7c2d0")
	layer.add_child(controls)

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-170, -75)
	hint_label.size = Vector2(340, 40)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(hint_label)

	player.inventory_changed.connect(update_status)
	player.hint_changed.connect(set_hint)

	inventory_panel = ColorRect.new()
	inventory_panel.color = Color(0.035, 0.045, 0.065, 0.94)
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.position = Vector2(-170, -115)
	inventory_panel.size = Vector2(340, 230)
	inventory_panel.visible = false
	layer.add_child(inventory_panel)

	var inventory_title := Label.new()
	inventory_title.text = "INVENTORY"
	inventory_title.position = Vector2(24, 20)
	inventory_title.add_theme_font_size_override("font_size", 24)
	inventory_panel.add_child(inventory_title)
	inventory_label = Label.new()
	inventory_label.text = "Money                     $50\n\nCigarettes                   0"
	inventory_label.position = Vector2(24, 72)
	inventory_label.add_theme_font_size_override("font_size", 18)
	inventory_panel.add_child(inventory_label)
	var close_hint := Label.new()
	close_hint.text = "Press I to close"
	close_hint.position = Vector2(24, 185)
	close_hint.modulate = Color("aeb8c5")
	inventory_panel.add_child(close_hint)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory") and inventory_panel:
		inventory_panel.visible = not inventory_panel.visible


func update_status(count: int, smoked: int, money: int) -> void:
	status_label.text = "Money: $%d   |   Cigarettes: %d   |   Smoked: %d" % [money, count, smoked]
	inventory_label.text = "Money                     $%d\n\nCigarettes                   %d\n\nCigarettes smoked            %d" % [money, count, smoked]


func set_hint(text: String) -> void:
	hint_label.text = text


func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material

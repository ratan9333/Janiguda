extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const SHOP_SCRIPT := preload("res://scripts/shop.gd")
const NPC_SCRIPT := preload("res://scripts/npc.gd")
const GEOGRAPHIC_WORLD_SCRIPT := preload("res://scripts/geographic_world.gd")
const BICYCLE_SCRIPT := preload("res://scripts/bicycle.gd")

var player
var status_label: Label
var hint_label: Label
var inventory_panel: ColorRect
var inventory_label: Label
var geographic_world


func _ready() -> void:
	setup_input()
	build_environment()
	build_world()
	build_player()
	build_spawn_bicycle()
	build_ui()


func setup_input() -> void:
	var bindings := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"run": KEY_SHIFT,
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
	if not InputMap.has_action("punch"):
		InputMap.add_action("punch")
	var punch_event := InputEventMouseButton.new()
	punch_event.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("punch", punch_event)


func build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f9bd1")
	sky_material.sky_horizon_color = Color("d7e7e7")
	sky_material.ground_bottom_color = Color("6d725e")
	sky_material.ground_horizon_color = Color("d7e7e7")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c7d3d5")
	settings.ambient_light_energy = 0.55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	add_child(sun)


func build_world() -> void:
	# JaniGudaGate.tscn is instanced in main.tscn and is the editable source of
	# truth for the map. Only generate from code when that instance is missing.
	geographic_world = get_node_or_null("GeographicWorld")
	if geographic_world:
		geographic_world.load_runtime_data()
	else:
		geographic_world = Node3D.new()
		geographic_world.name = "GeographicWorld"
		geographic_world.set_script(GEOGRAPHIC_WORLD_SCRIPT)
		add_child(geographic_world)
		geographic_world.generate()
	build_geographic_gameplay()


func build_geographic_gameplay() -> void:
	build_gate_person()
	# Jharaput is the mapped hamlet closest to the selected centre point.
	var village: Vector3 = geographic_world.latlon_to_world(18.6907777, 82.8326193)
	village.y = geographic_world.height_at(village.x, village.z)
	var shop_position: Vector3 = village + Vector3(0, 0, -12)
	add_box("GameplayKirana", Vector3(6, 3.2, 5), shop_position + Vector3(0, 1.6, 0), Color("d7ad55"), true)
	add_box("GameplayShopFront", Vector3(3.2, 2.3, 0.10), shop_position + Vector3(0, 1.15, -2.55), Color("55747f"), false)
	add_box("GameplayAwning", Vector3(5.0, 0.22, 1.2), shop_position + Vector3(0, 2.45, -3.0), Color("b84d41"), false)
	add_world_label("किराना • JHARAPUT STORE", shop_position + Vector3(0, 3.0, -2.7), Color("fff1bd"))
	var counter := Area3D.new()
	counter.name = "GeographicShopCounter"
	counter.set_script(SHOP_SCRIPT)
	counter.position = shop_position + Vector3(0, 1.0, -3.2)
	var counter_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(4.5, 2.0, 1.5)
	counter_shape.shape = box_shape
	counter.add_child(counter_shape)
	add_child(counter)
	var npc_position: Vector3 = village + Vector3(12, 1.0, 5)
	npc_position.y = geographic_world.height_at(npc_position.x, npc_position.z) + 1.0
	build_npc(npc_position)


func build_gate_person() -> void:
	var frame: Dictionary = geographic_world.nearest_primary_frame(Vector3.ZERO)
	var direction: Vector3 = frame.direction
	var east: Vector3 = frame.side
	var gate_frame: Dictionary = geographic_world.nearest_primary_frame(direction * -7.5)
	var position: Vector3 = gate_frame.point - east * 6.7
	position.y = geographic_world.surface_height_at(position.x, position.z) + 1.0
	build_npc(position, true)


func build_fictional_world() -> void:
	add_box("Ground", Vector3(80, 0.3, 70), Vector3(0, -0.15, 0), Color("78945d"), true)
	build_roads()

	build_apartment()
	build_shop()
	build_warehouse()
	build_park()
	build_extended_neighbourhood()
	build_street_details()

	add_box("BoundaryNorth", Vector3(80, 1.4, 0.4), Vector3(0, 0.7, -35), Color("cdbf9f"), true)
	add_box("BoundarySouth", Vector3(80, 1.4, 0.4), Vector3(0, 0.7, 35), Color("cdbf9f"), true)
	add_box("BoundaryWest", Vector3(0.4, 1.4, 70), Vector3(-40, 0.7, 0), Color("cdbf9f"), true)
	add_box("BoundaryEast", Vector3(0.4, 1.4, 70), Vector3(40, 0.7, 0), Color("cdbf9f"), true)


func build_roads() -> void:
	var asphalt := Color("41454a")
	var pavement := Color("bbb4a5")
	add_box("MainRoad", Vector3(80, 0.06, 7.0), Vector3(0, 0.03, 0), asphalt, false)
	add_box("CrossRoad", Vector3(7.0, 0.065, 70), Vector3(18, 0.035, 0), asphalt, false)
	add_box("WestLane", Vector3(5.0, 0.065, 30), Vector3(-23, 0.035, 16), Color("565454"), false)
	add_box("NorthLane", Vector3(34, 0.065, 4.5), Vector3(1, 0.035, -21), Color("565454"), false)
	add_box("MainWalkNorth", Vector3(80, 0.14, 1.4), Vector3(0, 0.07, -4.2), pavement, false)
	add_box("MainWalkSouth", Vector3(80, 0.14, 1.4), Vector3(0, 0.07, 4.2), pavement, false)
	add_box("CrossWalkWest", Vector3(1.4, 0.14, 70), Vector3(13.8, 0.07, 0), pavement, false)
	add_box("CrossWalkEast", Vector3(1.4, 0.14, 70), Vector3(22.2, 0.07, 0), pavement, false)
	for x in range(-37, 39, 6):
		add_box("MainRoadMark", Vector3(3.0, 0.025, 0.13), Vector3(x, 0.075, 0), Color("e4d37c"), false)
	for z in range(-31, 33, 6):
		add_box("CrossRoadMark", Vector3(0.13, 0.025, 3.0), Vector3(18, 0.08, z), Color("e4d37c"), false)
	# Zebra crossing and familiar painted speed breakers.
	for x in range(11, 26, 2):
		add_box("Zebra", Vector3(0.9, 0.025, 3.0), Vector3(x, 0.09, 0), Color("ece9df"), false)
	for x in [-7.0, -6.5, -6.0, -5.5]:
		add_box("SpeedBreaker", Vector3(0.35, 0.10, 7.0), Vector3(x, 0.10, 0), Color("d8c545") if int(x * 2) % 2 == 0 else Color("e8e4d8"), false)
	# Asphalt repair patches stop the roads looking perfectly artificial.
	add_box("RoadPatch", Vector3(3.0, 0.018, 1.6), Vector3(-29, 0.073, 1.7), Color("34373b"), false)
	add_box("RoadPatch", Vector3(1.8, 0.018, 2.8), Vector3(19.5, 0.078, -13), Color("34373b"), false)


func build_apartment() -> void:
	var wall := Color("d78469")
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
	add_box("ApartmentTable", Vector3(1.0, 0.65, 0.8), Vector3(1.7, 0.4, -10.2), Color("785238"), true)
	add_box("ApartmentWindowL", Vector3(1.0, 1.0, 0.05), Vector3(-1.9, 1.75, -6.31), Color("8dc1d4"), false)
	add_box("ApartmentWindowR", Vector3(1.0, 1.0, 0.05), Vector3(1.9, 1.75, -6.31), Color("8dc1d4"), false)
	add_box("ApartmentParapet", Vector3(6.4, 0.55, 0.2), Vector3(0, 3.62, -6.4), Color("f0d7b2"), true)
	add_cylinder("WaterTank", 0.65, 1.25, Vector3(1.8, 4.0, -9.2), Color("25282b"), false)
	add_world_label("JANIGUDA APARTMENTS", Vector3(0, 4.25, -6.2), Color.WHITE)


func build_shop() -> void:
	add_box("ShopBuilding", Vector3(5.2, 3.2, 4.2), Vector3(-9, 1.6, 6.3), Color("e2b956"), true)
	add_box("ShopAwning", Vector3(4.3, 0.25, 1.0), Vector3(-9, 2.25, 3.0), Color("bd4c43"), true)
	add_box("ShopShutter", Vector3(2.4, 2.1, 0.10), Vector3(-9, 1.1, 4.15), Color("637d88"), false)
	add_box("ShopCrateL", Vector3(0.65, 0.65, 0.65), Vector3(-10.8, 0.35, 3.7), Color("8e603d"), true)
	add_box("ShopCrateR", Vector3(0.65, 0.9, 0.65), Vector3(-10.1, 0.48, 3.7), Color("8e603d"), true)
	add_world_label("किराना • JANIGUDA KIRANA", Vector3(-9, 2.85, 3.95), Color("fff1ba"))

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
	add_box("Warehouse", Vector3(6.2, 4.0, 5.0), Vector3(8.5, 2.0, 6.3), Color("6b7f8e"), true)
	add_box("WarehouseDoor", Vector3(2.8, 2.8, 0.12), Vector3(8.5, 1.4, 2.95), Color("343b42"), false)
	add_box("WarehouseVent", Vector3(0.9, 0.6, 0.1), Vector3(6.3, 3.0, 3.74), Color("29333b"), false)
	add_world_label("JANIGUDA GODOWN", Vector3(8.5, 3.45, 3.65), Color.WHITE)


func build_park() -> void:
	add_box("ParkLawn", Vector3(17, 0.08, 13), Vector3(1, 0.02, 18), Color("6c9d57"), false)
	add_box("ParkPath", Vector3(3.0, 0.06, 13), Vector3(1, 0.07, 18), Color("c6b898"), false)
	add_box("ParkCrossPath", Vector3(17, 0.06, 2.0), Vector3(1, 0.075, 18), Color("c6b898"), false)
	add_box("BenchSeat", Vector3(2.2, 0.18, 0.55), Vector3(4.5, 0.65, 15.0), Color("805a38"), true)
	add_box("BenchBack", Vector3(2.2, 0.8, 0.15), Vector3(4.5, 1.0, 15.25), Color("805a38"), true)
	add_box("ParkFenceNorth", Vector3(17, 0.65, 0.18), Vector3(1, 0.35, 11.5), Color("d8d0b8"), true)
	add_tree(Vector3(-5.5, 0, 14.0))
	add_tree(Vector3(7.0, 0, 14.5))
	add_tree(Vector3(-4.0, 0, 22.0))
	add_tree(Vector3(7.0, 0, 22.0))
	add_world_label("नगर पार्क • NAGAR PARK", Vector3(1, 2.4, 11.2), Color("efffdf"))
	build_npc(Vector3(-1.8, 1.0, 15.0))


func build_extended_neighbourhood() -> void:
	# Dense, varied blocks around the playable core create a believable Indian town.
	add_detailed_building("Clinic", "जन सेवा CLINIC", Vector3(-18, 2.7, -9), Vector3(7, 5.4, 7), Color("d9e1d2"), 1.0)
	add_detailed_building("Tailor", "RAJU TAILORS", Vector3(-28, 2.2, -8), Vector3(7, 4.4, 6), Color("68a6a0"), 1.0)
	add_detailed_building("MobileShop", "MOBILE REPAIR", Vector3(-35, 2.0, 8), Vector3(6, 4, 6), Color("7e6ca8"), -1.0)
	add_detailed_building("Pharmacy", "भारत MEDICALS", Vector3(-27, 2.4, 27), Vector3(7, 4.8, 7), Color("e4e5dc"), -1.0)
	add_detailed_building("SouthHomes", "SHANTI NIVAS", Vector3(-11, 3.5, 29), Vector3(10, 7, 8), Color("d28f74"), -1.0)
	add_detailed_building("EastFlats", "SAI RESIDENCY", Vector3(30, 5.0, 11), Vector3(10, 10, 10), Color("d6b98b"), -1.0)
	add_detailed_building("EastMarket", "JANIGUDA MARKET", Vector3(31, 3.0, -12), Vector3(12, 6, 8), Color("c77a69"), 1.0)
	add_detailed_building("School", "SARASWATI SCHOOL", Vector3(4, 4.2, -29), Vector3(17, 8.4, 8), Color("e1bc72"), 1.0)
	add_detailed_building("NorthHomes", "GANGA HOMES", Vector3(-12, 4.0, -28), Vector3(10, 8, 8), Color("9bb5c5"), 1.0)
	add_detailed_building("TeaHotel", "UDUPI HOTEL", Vector3(29, 2.5, 27), Vector3(9, 5, 8), Color("ce9d57"), -1.0)
	build_chai_stall(Vector3(-22, 0, 7))
	build_fruit_cart(Vector3(24, 0, -6))


func add_detailed_building(node_name: String, sign_text: String, position: Vector3, size: Vector3, color: Color, front_z: float) -> void:
	add_box(node_name, size, position, color, true)
	var front := position.z + front_z * (size.z * 0.5 + 0.04)
	add_box(node_name + "Door", Vector3(1.4, 2.2, 0.08), Vector3(position.x, 1.1, front), Color("4d3930"), false)
	for floor_index in range(1, maxi(2, int(size.y / 2.5))):
		var window_y := 1.5 + floor_index * 2.0
		if window_y < size.y - 0.3:
			add_box(node_name + "WindowL", Vector3(1.1, 0.9, 0.06), Vector3(position.x - size.x * 0.28, window_y, front), Color("77aebf"), false)
			add_box(node_name + "WindowR", Vector3(1.1, 0.9, 0.06), Vector3(position.x + size.x * 0.28, window_y, front), Color("77aebf"), false)
	add_box(node_name + "RoofTrim", Vector3(size.x + 0.25, 0.3, size.z + 0.25), Vector3(position.x, size.y + 0.15, position.z), color.lightened(0.18), true)
	add_cylinder(node_name + "Tank", 0.7, 1.3, Vector3(position.x + size.x * 0.25, size.y + 0.85, position.z), Color("292d30"), false)
	add_world_label(sign_text, Vector3(position.x, minf(size.y - 0.5, 3.3), front + front_z * 0.05), Color("fff4cc"))


func build_street_details() -> void:
	# Open concrete drains beside the main road.
	add_box("NorthDrain", Vector3(80, 0.16, 0.42), Vector3(0, 0.04, -5.05), Color("55564f"), false)
	add_box("SouthDrain", Vector3(80, 0.16, 0.42), Vector3(0, 0.04, 5.05), Color("55564f"), false)
	for x in [-34, -24, -14, 2, 10, 27, 36]:
		build_streetlight(Vector3(x, 0, -4.8))
	for x in [-30, -18, -2, 8, 30]:
		build_streetlight(Vector3(x, 0, 4.8))

	# Power poles and overhead cables along the northern edge.
	for x in [-34, -20, -6, 8, 22, 36]:
		build_utility_pole(Vector3(x, 0, -5.7))
	for x in [-27, -13, 1, 15, 29]:
		add_box("PowerCable", Vector3(13.8, 0.035, 0.035), Vector3(x, 5.05, -5.7), Color("242424"), false)

	build_auto_rickshaw(Vector3(-16, 0, 1.35))
	build_scooter(Vector3(6.2, 0, -2.6))
	build_scooter(Vector3(26, 0, 2.6))
	# Concrete roadside barriers and hand-painted curb colors.
	for x in range(-38, 39, 4):
		var curb_color := Color("f2e9d1") if int(x / 4) % 2 == 0 else Color("202020")
		add_box("Curb", Vector3(3.8, 0.18, 0.22), Vector3(x, 0.14, -4.75), curb_color, false)


func build_streetlight(position: Vector3) -> void:
	add_cylinder("LampPost", 0.09, 4.8, position + Vector3(0, 2.4, 0), Color("42484c"), false)
	add_box("LampArm", Vector3(0.85, 0.08, 0.08), position + Vector3(0.38, 4.65, 0), Color("42484c"), false)
	add_box("Lamp", Vector3(0.42, 0.16, 0.28), position + Vector3(0.78, 4.53, 0), Color("fff0aa"), false)


func build_utility_pole(position: Vector3) -> void:
	add_cylinder("UtilityPole", 0.13, 5.2, position + Vector3(0, 2.6, 0), Color("77736b"), true)
	add_box("PoleCrossbar", Vector3(1.3, 0.12, 0.12), position + Vector3(0, 4.8, 0), Color("665f55"), false)
	add_cylinder("InsulatorL", 0.06, 0.28, position + Vector3(-0.48, 5.0, 0), Color("d8d1c5"), false)
	add_cylinder("InsulatorR", 0.06, 0.28, position + Vector3(0.48, 5.0, 0), Color("d8d1c5"), false)


func build_chai_stall(position: Vector3) -> void:
	add_box("ChaiCounter", Vector3(3.5, 1.15, 1.2), position + Vector3(0, 0.58, 0), Color("477a65"), true)
	add_box("ChaiRoof", Vector3(4.2, 0.18, 2.8), position + Vector3(0, 2.65, 0), Color("3d6f91"), true)
	for x in [-1.65, 1.65]:
		add_box("ChaiPost", Vector3(0.12, 2.6, 0.12), position + Vector3(x, 1.3, 0), Color("5a4635"), true)
	add_cylinder("TeaPot", 0.22, 0.35, position + Vector3(-0.7, 1.35, -0.15), Color("a7a7a0"), false)
	add_world_label("चाय • CHAI ₹10", position + Vector3(0, 2.25, -1.45), Color("fff1b8"))


func build_fruit_cart(position: Vector3) -> void:
	add_box("FruitCart", Vector3(2.7, 0.28, 1.4), position + Vector3(0, 1.0, 0), Color("815632"), true)
	for offset in [Vector3(-0.8, 1.35, -0.3), Vector3(0, 1.35, -0.3), Vector3(0.8, 1.35, -0.3), Vector3(-0.4, 1.35, 0.3), Vector3(0.4, 1.35, 0.3)]:
		add_character_sphere(self, "Fruit", 0.2, position + offset, Color("e28b2f"))
	var wheel_l := add_cylinder("CartWheel", 0.42, 0.16, position + Vector3(-0.9, 0.5, 0), Color("292929"), false)
	wheel_l.rotation_degrees.z = 90
	var wheel_r := add_cylinder("CartWheel", 0.42, 0.16, position + Vector3(0.9, 0.5, 0), Color("292929"), false)
	wheel_r.rotation_degrees.z = 90
	add_world_label("ताज़े फल • FRESH FRUIT", position + Vector3(0, 2.0, 0), Color("fff0c2"))


func build_auto_rickshaw(position: Vector3) -> void:
	add_box("AutoBody", Vector3(2.2, 1.05, 1.5), position + Vector3(0, 0.8, 0), Color("e3c62d"), true)
	add_box("AutoCab", Vector3(1.25, 1.15, 1.42), position + Vector3(-0.35, 1.75, 0), Color("2e6b43"), false)
	add_box("AutoRoof", Vector3(1.7, 0.16, 1.55), position + Vector3(-0.15, 2.38, 0), Color("1f2421"), false)
	add_box("AutoWindshield", Vector3(0.08, 0.62, 1.1), position + Vector3(-1.01, 1.78, 0), Color("85b8c5"), false)
	for wheel_position in [Vector3(-0.75, 0.42, -0.75), Vector3(-0.75, 0.42, 0.75), Vector3(0.78, 0.42, 0)]:
		var wheel := add_cylinder("AutoWheel", 0.34, 0.18, position + wheel_position, Color("202020"), false)
		wheel.rotation_degrees.x = 90


func build_scooter(position: Vector3) -> void:
	add_box("ScooterBody", Vector3(1.35, 0.38, 0.42), position + Vector3(0, 0.68, 0), Color("b94d46"), false)
	add_box("ScooterSeat", Vector3(0.72, 0.16, 0.38), position + Vector3(0.18, 1.0, 0), Color("292929"), false)
	add_box("ScooterHandle", Vector3(0.12, 0.9, 0.12), position + Vector3(-0.48, 1.15, 0), Color("555b5e"), false)
	for x in [-0.52, 0.52]:
		var wheel := add_cylinder("ScooterWheel", 0.28, 0.13, position + Vector3(x, 0.35, 0), Color("202020"), false)
		wheel.rotation_degrees.x = 90


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


func add_cylinder(node_name: String, radius: float, height: float, position: Vector3, color: Color, collision: bool) -> Node3D:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = position
	add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = make_material(color)
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	if collision:
		var collider := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
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
	var spawn_height := 0.0
	if geographic_world:
		spawn_height = geographic_world.surface_height_at(0, 0)
	# Local X/Z zero is the exact supplied coordinate: 18.690209, 82.834109.
	player.position = Vector3(0, spawn_height + 1.0, 0)
	player.rotation_degrees.y = 180.0
	player.floor_snap_length = 0.45

	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
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
	if geographic_world:
		# Begin by looking across Nandapur Road toward the photographed gate.
		var spawn_frame: Dictionary = geographic_world.nearest_primary_frame(Vector3.ZERO)
		var gate_direction: Vector3 = spawn_frame.side
		camera_pivot.rotation.y = atan2(-gate_direction.x, -gate_direction.z)
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


func build_spawn_bicycle() -> void:
	var bicycle := CharacterBody3D.new()
	bicycle.name = "SpawnBicycle"
	bicycle.set_script(BICYCLE_SCRIPT)
	var frame: Dictionary = geographic_world.nearest_primary_frame(Vector3.ZERO)
	var road_point: Vector3 = frame.point
	var road_side: Vector3 = frame.side
	var road_direction: Vector3 = frame.direction
	# Player initially faces +Z; ensure the bicycle appears in front of the
	# camera even when the OSM way's stored direction runs the opposite way.
	if road_direction.dot(Vector3(0, 0, 1)) < 0.0:
		road_direction = -road_direction
		road_side = -road_side
	# Keep the bicycle on the asphalt and clear of the roadside buildings.
	var bicycle_position := road_point + road_direction * 4.2 + road_side * 1.2
	bicycle_position.y = geographic_world.surface_height_at(bicycle_position.x, bicycle_position.z) + 0.62
	bicycle.position = bicycle_position
	bicycle.basis = Basis(road_side, Vector3.UP, -road_direction)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.75, 1.5, 2.0)
	collider.shape = shape
	# Bottom of the collider aligns with the tyre contact point (~-0.55 m).
	# This keeps wheel centres above ground after CharacterBody settling.
	collider.position.y = 0.20
	bicycle.add_child(collider)

	var visual := Node3D.new()
	visual.name = "BikeVisual"
	bicycle.add_child(visual)
	add_bicycle_wheel(visual, "FrontWheel", Vector3(0, 0, -0.92))
	add_bicycle_wheel(visual, "RearWheel", Vector3(0, 0, 0.92))
	add_bicycle_bar(visual, Vector3(0, 0.05, 0.78), Vector3(0, 0.72, 0.18), 0.055, Color("297aa2"))
	add_bicycle_bar(visual, Vector3(0, 0.05, -0.78), Vector3(0, 0.72, 0.18), 0.055, Color("297aa2"))
	add_bicycle_bar(visual, Vector3(0, 0.05, 0.78), Vector3(0, 0.05, -0.78), 0.05, Color("297aa2"))
	add_bicycle_bar(visual, Vector3(0, 0.72, 0.18), Vector3(0, 0.05, -0.78), 0.05, Color("297aa2"))
	add_bicycle_bar(visual, Vector3(0, 0.72, 0.18), Vector3(0, 1.10, -0.78), 0.045, Color("55595c"))
	add_bicycle_bar(visual, Vector3(-0.42, 1.12, -0.82), Vector3(0.42, 1.12, -0.82), 0.04, Color("55595c"))
	add_character_box(visual, "BicycleSeat", Vector3(0.36, 0.12, 0.48), Vector3(0, 0.82, 0.26), Color("252525"))
	add_character_sphere(visual, "PedalHub", 0.13, Vector3(0, 0.36, 0.08), Color("55595c"))
	add_child(bicycle)


func add_bicycle_wheel(parent: Node3D, wheel_name: String, position: Vector3) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name = wheel_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.48
	mesh.outer_radius = 0.55
	mesh.rings = 24
	mesh.ring_segments = 10
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color("202020")
	mesh.material = wheel_material
	wheel.mesh = mesh
	wheel.position = position
	wheel.rotation_degrees.z = 90
	parent.add_child(wheel)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.10
	hub_mesh.bottom_radius = 0.10
	hub_mesh.height = 0.16
	hub_mesh.radial_segments = 12
	hub_mesh.material = make_material(Color("a7a7a2"))
	hub.mesh = hub_mesh
	wheel.add_child(hub)
	for spoke_rotation in [0.0, 45.0, 90.0, 135.0]:
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(1.02, 0.018, 0.025)
		spoke_mesh.material = make_material(Color("b3b5b3"))
		spoke.mesh = spoke_mesh
		spoke.rotation_degrees.y = spoke_rotation
		wheel.add_child(spoke)


func add_bicycle_bar(parent: Node3D, start: Vector3, finish: Vector3, radius: float, color: Color) -> void:
	var bar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 8
	mesh.material = make_material(color)
	bar.mesh = mesh
	bar.position = (start + finish) * 0.5
	bar.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	parent.add_child(bar)


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


func build_npc(position: Vector3, gate_person := false) -> void:
	var npc := Area3D.new()
	npc.name = "NeighbourNPC"
	npc.set_script(NPC_SCRIPT)
	npc.position = position
	npc.rotation_degrees.y = 180.0
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	shape_node.shape = shape
	npc.add_child(shape_node)
	build_stylized_character(npc)
	var npc_torso: MeshInstance3D = npc.get_node("CharacterRig/Torso")
	npc_torso.material_override = make_material(Color("e8e2d7") if gate_person else Color("6f467f"))
	if gate_person:
		npc.name = "GateWatchmanNPC"
		npc.get_node("CharacterRig/ShirtStripe").material_override = make_material(Color("9d3840"))
		npc.get_node("CharacterRig/LeftLeg/Trouser").material_override = make_material(Color("4772a2"))
		npc.get_node("CharacterRig/RightLeg/Trouser").material_override = make_material(Color("4772a2"))
		# Three-legged survey stand visible beside the person in the reference.
		var tripod := Node3D.new()
		tripod.name = "SurveyTripod"
		tripod.position = Vector3(-0.65, -0.85, -0.15)
		add_bicycle_bar(tripod, Vector3(0, 1.55, 0), Vector3(-0.48, 0, -0.35), 0.035, Color("d9d5c9"))
		add_bicycle_bar(tripod, Vector3(0, 1.55, 0), Vector3(0.48, 0, -0.35), 0.035, Color("d9d5c9"))
		add_bicycle_bar(tripod, Vector3(0, 1.55, 0), Vector3(0, 0, 0.48), 0.035, Color("d9d5c9"))
		add_character_box(tripod, "TripodHead", Vector3(0.38, 0.18, 0.28), Vector3(0, 1.62, 0), Color("454b4d"))
		npc.add_child(tripod)
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
	title.text = "JANIGUDA — VERSION 0.1"
	title.position = Vector2(34, 30)
	title.add_theme_font_size_override("font_size", 20)
	layer.add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(34, 63)
	status_label.text = "Money: $50   |   Cigarettes: 0   |   Smoked: 0"
	layer.add_child(status_label)

	var controls := Label.new()
	controls.position = Vector2(34, 88)
	controls.text = "WASD move • Shift run/boost • Space jump • Left click punch • E interact • F smoke"
	controls.modulate = Color("b7c2d0")
	layer.add_child(controls)

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-170, -75)
	hint_label.size = Vector2(340, 40)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(hint_label)

	var attribution := Label.new()
	attribution.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	attribution.position = Vector2(-365, -28)
	attribution.size = Vector2(350, 20)
	attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	attribution.text = "Map data © OpenStreetMap contributors • Elevation: SRTM"
	attribution.modulate = Color(0.9, 0.9, 0.9, 0.78)
	attribution.add_theme_font_size_override("font_size", 12)
	layer.add_child(attribution)

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

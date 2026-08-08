extends Node3D

const SHOP_SCRIPT := preload("res://scripts/shop.gd")

const CENTER_LAT := 18.690209
const CENTER_LON := 82.834109
const GRID_SPACING := 250.0
const SOURCE_GRID_SIZE := 9
const TERRAIN_SUBDIVISIONS := 32
const WORLD_HALF_SIZE := 1000.0

var elevations: Array = []
var base_elevation := 0.0
var road_segments: Array[PackedVector3Array] = []
var primary_road_segments: Array[PackedVector3Array] = []


func generate() -> void:
	load_elevation_data()
	build_terrain()
	build_roads()
	build_spawn_reference_cluster()
	build_center_roadside_settlement()
	build_parked_vehicles()
	build_mapped_places()
	build_farm_details()
	build_vegetation()
	build_grass_and_shrubs()
	build_roadside_utilities()


func load_elevation_data() -> void:
	var file := FileAccess.open("res://data/elevation_grid.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	elevations = data.elevations
	base_elevation = float(elevations[40])


func build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := WORLD_HALF_SIZE * 2.0 / TERRAIN_SUBDIVISIONS
	for row in range(TERRAIN_SUBDIVISIONS):
		for column in range(TERRAIN_SUBDIVISIONS):
			var x0 := -WORLD_HALF_SIZE + column * step
			var x1 := x0 + step
			var z0 := -WORLD_HALF_SIZE + row * step
			var z1 := z0 + step
			var a := Vector3(x0, height_at(x0, z0), z0)
			var b := Vector3(x1, height_at(x1, z0), z0)
			var c := Vector3(x1, height_at(x1, z1), z1)
			var d := Vector3(x0, height_at(x0, z1), z1)
			# Counter-clockwise from above so normals and one-sided concave
			# collision face upward. The old order caused terrain fall-through.
			add_triangle(surface, a, c, b)
			add_triangle(surface, a, d, c)
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var terrain_material := StandardMaterial3D.new()
	terrain_material.albedo_color = Color.WHITE
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.96
	terrain_mesh.surface_set_material(0, terrain_material)

	var terrain := StaticBody3D.new()
	terrain.name = "RealTerrain_2km"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = terrain_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh.get_faces())
	shape.backface_collision = true
	collider.shape = shape
	terrain.add_child(collider)
	add_child(terrain)


func add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		surface.set_color(terrain_color_at(point))
		surface.set_uv(Vector2((point.x + WORLD_HALF_SIZE) / 2000.0, (point.z + WORLD_HALF_SIZE) / 2000.0))
		surface.add_vertex(point)


func terrain_color_at(point: Vector3) -> Color:
	var variation := sin(point.x * 0.017) * cos(point.z * 0.013)
	if point.x < -40.0:
		return Color("294c2f").lightened(variation * 0.045)
	if point.x > 120.0:
		return Color("6d7047").lightened(variation * 0.055)
	return Color("48633b").lightened(variation * 0.05)


func build_roads() -> void:
	var file := FileAccess.open("res://data/location_osm.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	for element in data.elements:
		if element.type != "way" or not element.has("geometry"):
			continue
		var points := PackedVector3Array()
		for coordinate in element.geometry:
			var point := latlon_to_world(float(coordinate.lat), float(coordinate.lon))
			point.y = height_at(point.x, point.z) + 0.18
			points.append(point)
		if points.size() < 2:
			continue
		road_segments.append(points)
		var road_type: String = element.tags.get("highway", "unclassified")
		if road_type == "primary":
			primary_road_segments.append(points)
		var width := 6.5 if road_type == "primary" else 4.5
		build_road_strip(points, width + 3.0, Color("9a6748"), -0.10)
		build_road_strip(points, width, Color("5a5350"))
		if road_type == "primary":
			build_dashed_centerline(points)
			build_road_strip(offset_polyline(points, width * 0.5 - 0.22), 0.12, Color("dfc94d"), 0.04)
			build_road_strip(offset_polyline(points, -width * 0.5 + 0.22), 0.12, Color("dfc94d"), 0.04)


func build_road_strip(points: PackedVector3Array, width: float, color: Color, y_offset := 0.0) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var direction := Vector3(finish.x - start.x, 0, finish.z - start.z).normalized()
		var side := Vector3(-direction.z, 0, direction.x) * width * 0.5
		start.y += y_offset
		finish.y += y_offset
		add_triangle(surface, start - side, finish - side, finish + side)
		add_triangle(surface, start - side, finish + side, start + side)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "MappedRoad"
	instance.mesh = mesh
	add_child(instance)


func offset_polyline(points: PackedVector3Array, offset: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in range(points.size()):
		var previous := points[maxi(index - 1, 0)]
		var following := points[mini(index + 1, points.size() - 1)]
		var direction := Vector3(following.x - previous.x, 0, following.z - previous.z).normalized()
		var side := Vector3(-direction.z, 0, direction.x)
		result.append(points[index] + side * offset)
	return result


func build_dashed_centerline(points: PackedVector3Array) -> void:
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var length := start.distance_to(finish)
		var distance := 1.5
		while distance < length:
			var dash_start := start.lerp(finish, distance / length)
			var dash_end := start.lerp(finish, minf(distance + 2.5, length) / length)
			build_road_strip(PackedVector3Array([dash_start, dash_end]), 0.10, Color("d8d4c8"), 0.045)
			distance += 7.0


func build_spawn_reference_cluster() -> void:
	# Hand-built, stylized reconstruction of the supplied Street View references.
	# Local +Z points east (shops); -Z points west (the wooded compound).
	if primary_road_segments.is_empty():
		return
	var frame := nearest_primary_frame(Vector3.ZERO)
	var direction: Vector3 = frame.direction
	var east: Vector3 = frame.side
	build_spawn_shop_row(direction, east)
	build_spawn_compound(direction, east)
	build_spawn_street_furniture(direction, east)


func make_local_root(name_text: String, along: float, across: float, direction: Vector3, east: Vector3, static_body := true) -> Node3D:
	var frame := nearest_primary_frame(direction * along)
	var point: Vector3 = frame.point + east * across
	point.y = surface_height_at(point.x, point.z)
	var root: Node3D = StaticBody3D.new() if static_body else Node3D.new()
	root.name = name_text
	root.position = point
	root.basis = Basis(direction, Vector3.UP, east)
	add_child(root)
	return root


func add_local_box(parent: Node3D, size: Vector3, position: Vector3, color: Color, collision := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color)
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	if collision and parent is StaticBody3D:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		collider.position = position
		parent.add_child(collider)
	return instance


func build_spawn_shop_row(direction: Vector3, east: Vector3) -> void:
	# Roadside kiosks: corrugated roofs, deep open counters, hanging packets and signs.
	var shop_colors := [Color("d9c637"), Color("4d8881"), Color("477896"), Color("d6a75d"), Color("559c72")]
	var shop_names := ["SUKANTI GEN STORE", "R.K. TRADERS", "TEA & SNACKS", "DAILY NEEDS", "COLD DRINKS"]
	for index in range(5):
		var along := -14.0 + index * 6.2
		var shop := make_local_root("ReferenceShop_%d" % index, along, 7.7, direction, east)
		var color: Color = shop_colors[index]
		add_local_box(shop, Vector3(5.9, 2.75, 4.0), Vector3(0, 1.375, 0), color, true)
		add_local_box(shop, Vector3(5.6, 2.05, 0.12), Vector3(0, 1.12, -2.07), Color("24211d"))
		add_local_box(shop, Vector3(6.35, 0.18, 5.15), Vector3(0, 2.92, -0.48), Color("81766d"))
		add_local_box(shop, Vector3(5.7, 0.55, 0.13), Vector3(0, 2.46, -2.10), Color("a43e31") if index % 2 == 0 else Color("285d7b"))
		add_local_box(shop, Vector3(5.2, 0.22, 1.0), Vector3(0, 0.11, -2.42), Color("aa7555"), true)
		for packet in range(9):
			var packet_color: Color = [Color("e54b38"), Color("f2ca3c"), Color("328f71"), Color("6a63a8")][packet % 4]
			add_local_box(shop, Vector3(0.24, 0.52, 0.08), Vector3(-2.2 + packet * 0.55, 1.78 - (packet % 2) * 0.25, -2.16), packet_color)
		var sign_position: Vector3 = shop.global_position - east * 2.22 + Vector3.UP * 2.48
		add_label(shop_names[index], sign_position, Color("fff2c7"), 22)
	add_shop_interaction(nearest_primary_frame(Vector3.ZERO).point + east * 5.0)

	# Distinctive multi-storey homes directly behind the low shop roofs.
	build_reference_house(-13.0, 14.0, direction, east, Vector3(10.5, 8.6, 8.0), Color("2669a2"), Color("eee6d5"), 0)
	build_reference_house(-1.0, 15.0, direction, east, Vector3(10.0, 7.1, 8.5), Color("d5a041"), Color("eee8d7"), 1)
	build_reference_house(10.5, 16.0, direction, east, Vector3(7.2, 10.0, 7.0), Color("b8d7cf"), Color("37687c"), 2)
	build_reference_house(20.5, 15.5, direction, east, Vector3(10.5, 7.8, 8.5), Color("d8c6aa"), Color("416b85"), 3)


func build_reference_house(along: float, across: float, direction: Vector3, east: Vector3, size: Vector3, body_color: Color, trim_color: Color, variant: int) -> void:
	var house := make_local_root("ReferenceHouse_%d" % variant, along, across, direction, east)
	add_local_box(house, size, Vector3(0, size.y * 0.5, 0), body_color, true)
	add_local_box(house, Vector3(size.x + 0.45, 0.28, size.z + 0.45), Vector3(0, size.y + 0.14, 0), trim_color)
	# Street-facing balconies and strong white/blue facade bands seen in the photos.
	for floor_index in range(1, int(size.y / 2.7)):
		var y := floor_index * 2.65
		add_local_box(house, Vector3(size.x * 0.82, 0.20, 1.25), Vector3(0, y, -size.z * 0.5 - 0.52), trim_color)
		add_local_box(house, Vector3(size.x * 0.82, 0.65, 0.10), Vector3(0, y + 0.53, -size.z * 0.5 - 1.08), trim_color)
	for window_index in range(3):
		var x := -size.x * 0.30 + window_index * size.x * 0.30
		add_local_box(house, Vector3(1.15, 1.35, 0.10), Vector3(x, size.y * 0.62, -size.z * 0.5 - 0.06), Color("243c48"))
	if variant == 0:
		add_local_box(house, Vector3(size.x * 0.62, 2.2, 0.12), Vector3(0, size.y - 1.3, -size.z * 0.5 - 0.08), Color("175487"))
		add_local_box(house, Vector3(size.x * 0.66, 0.20, 0.16), Vector3(0, size.y - 0.25, -size.z * 0.5 - 0.12), Color("f1e8d6"))
	build_water_tank(house.global_position + Vector3.UP * (size.y + 1.0))
	if variant >= 2:
		build_satellite_dish(house.global_position + direction * 1.8 + Vector3.UP * (size.y + 0.65))


func build_satellite_dish(position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "SatelliteDish"
	root.position = position
	var dish := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.65
	mesh.height = 0.25
	mesh.radial_segments = 12
	mesh.rings = 4
	mesh.material = material(Color("5e6262"))
	dish.mesh = mesh
	dish.rotation_degrees.x = 28
	root.add_child(dish)
	add_box_part(root, Vector3(0.10, 0.85, 0.10), Vector3(0, -0.40, 0), Color("555858"))
	add_child(root)


func build_spawn_compound(direction: Vector3, east: Vector3) -> void:
	# Weathered west-side wall and the four ochre gateposts frame a red-earth lane.
	for along in [-37.0, -29.0, -21.0, 13.0, 22.0, 31.0, 40.0]:
		var wall := make_local_root("CompoundWall", along, -8.2, direction, east)
		add_local_box(wall, Vector3(8.8, 2.35, 0.42), Vector3(0, 1.175, 0), Color("9a8275"), true)
		add_local_box(wall, Vector3(8.8, 0.15, 0.55), Vector3(0, 2.38, 0), Color("6e625b"))
	for along in [-14.5, -9.5, 3.0, 8.0]:
		var pillar := make_local_root("OchreGatePillar", along, -8.35, direction, east)
		add_local_box(pillar, Vector3(1.0, 3.25, 1.0), Vector3(0, 1.625, 0), Color("b65c3c"), true)
		add_local_box(pillar, Vector3(1.28, 0.24, 1.28), Vector3(0, 3.32, 0), Color("d7b09a"))
	var gate := make_local_root("IronCompoundGate", -3.2, -8.55, direction, east)
	for bar in range(11):
		add_local_box(gate, Vector3(0.08, 2.1, 0.08), Vector3(-5.4 + bar * 1.08, 1.15, 0), Color("51463e"))
	add_local_box(gate, Vector3(11.0, 0.10, 0.10), Vector3(0, 0.25, 0), Color("51463e"))
	add_local_box(gate, Vector3(11.0, 0.10, 0.10), Vector3(0, 2.20, 0), Color("51463e"))
	# Small diagonal braces give the gate the hand-welded look in the reference.
	for brace_x in [-3.8, 0.0, 3.8]:
		var brace := add_local_box(gate, Vector3(2.8, 0.08, 0.08), Vector3(brace_x, 1.2, -0.02), Color("51463e"))
		brace.rotation.z = 0.52
	var lane_start: Vector3 = nearest_primary_frame(Vector3.ZERO).point - east * 5.0
	build_ground_strip(lane_start, lane_start - east * 72.0, 11.0, Color("8d5237"), 0.22)
	# Painted Odia-style signboards, drain edge and a partly collapsed foreground wall.
	var sign_root := make_local_root("CompoundSignboards", -18.5, -8.55, direction, east, false)
	add_local_box(sign_root, Vector3(5.2, 1.7, 0.16), Vector3(0, 1.45, -0.22), Color("3e5147"))
	add_local_box(sign_root, Vector3(3.4, 0.9, 0.14), Vector3(1.0, 0.20, -0.25), Color("39704c"))
	var sign_world := sign_root.global_position - east * 0.38 + Vector3.UP * 1.5
	add_label("ଜଙ୍ଗଲ ପ୍ରବେଶ • JANIGUDA", sign_world, Color("eee0a9"), 21)
	var broken := make_local_root("BrokenForegroundWall", 36.0, -5.9, direction, east)
	add_local_box(broken, Vector3(7.5, 1.65, 0.55), Vector3(0, 0.825, 0), Color("907867"), true)
	add_local_box(broken, Vector3(2.2, 0.9, 0.62), Vector3(-4.5, 0.45, 0), Color("7c6a5c"), true)
	for rubbish_index in range(18):
		var litter := make_local_root("RoadsideLeafLitter", -26.0 + rubbish_index * 3.5, -5.5 - float(rubbish_index % 3), direction, east, false)
		add_local_box(litter, Vector3(0.16 + (rubbish_index % 2) * 0.14, 0.05, 0.22), Vector3(0, 0.04, 0), [Color("d8cfb0"), Color("538758"), Color("c26a4b")][rubbish_index % 3])

	# Lime-green roadside room and dense eucalyptus grove beyond the gate.
	var hut := make_local_root("LimeGreenRoadHut", 48.0, -9.2, direction, east)
	add_local_box(hut, Vector3(7.2, 3.2, 5.2), Vector3(0, 1.6, 0), Color("8fcf35"), true)
	add_local_box(hut, Vector3(7.7, 0.22, 5.7), Vector3(0, 3.31, 0), Color("78a92e"))
	add_local_box(hut, Vector3(1.4, 2.25, 0.12), Vector3(0, 1.12, -2.66), Color("24241e"))
	add_local_box(hut, Vector3(7.8, 0.18, 1.25), Vector3(0, 2.68, -3.1), Color("75a92c"))
	var grove: Array[Vector3] = []
	for row in range(5):
		for column in range(13):
			var along := -55.0 + column * 9.5 + sin(row * 4.1 + column) * 2.0
			var frame := nearest_primary_frame(direction * along)
			var tree_position: Vector3 = frame.point - east * (18.0 + row * 10.5 + cos(column * 2.3) * 2.5)
			tree_position.y = height_at(tree_position.x, tree_position.z)
			grove.append(tree_position)
	build_eucalyptus_grove(grove)


func build_eucalyptus_grove(positions: Array[Vector3]) -> void:
	for index in range(positions.size()):
		var root := Node3D.new()
		root.position = positions[index]
		var height := 12.0 + float(index % 5) * 1.5
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.28
		trunk_mesh.bottom_radius = 0.42
		trunk_mesh.height = height
		trunk_mesh.radial_segments = 6
		trunk_mesh.material = material(Color("b9aa94") if index % 3 == 0 else Color("775e48"))
		trunk.mesh = trunk_mesh
		trunk.position.y = height * 0.5
		root.add_child(trunk)
		for crown_index in range(3):
			var crown := MeshInstance3D.new()
			var crown_mesh := SphereMesh.new()
			crown_mesh.radius = 2.0 + crown_index * 0.35
			crown_mesh.height = crown_mesh.radius * 1.65
			crown_mesh.radial_segments = 7
			crown_mesh.rings = 4
			crown_mesh.material = material(Color("274e2c").lightened(float((index + crown_index) % 3) * 0.05))
			crown.mesh = crown_mesh
			crown.position = Vector3((crown_index - 1) * 1.35, height - 1.0 + crown_index * 0.55, sin(index) * 0.8)
			root.add_child(crown)
		add_child(root)


func build_spawn_street_furniture(direction: Vector3, east: Vector3) -> void:
	for along in [-32.0, 1.0, 34.0]:
		var frame := nearest_primary_frame(direction * along)
		var position: Vector3 = frame.point + east * 5.8
		position.y = surface_height_at(position.x, position.z)
		build_power_pole(position)
	var center := nearest_primary_frame(Vector3.ZERO)
	var auto_position: Vector3 = center.point - direction * 28.0 + east * 5.5
	auto_position.y = surface_height_at(auto_position.x, auto_position.z)
	build_auto_rickshaw(auto_position, direction, east)
	build_palm_tree(center.point + direction * 4.0 + east * 21.0)


func build_palm_tree(position: Vector3) -> void:
	position.y = surface_height_at(position.x, position.z)
	var root := Node3D.new()
	root.position = position
	var trunk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.38
	mesh.height = 13.0
	mesh.radial_segments = 8
	mesh.material = material(Color("766044"))
	trunk.mesh = mesh
	trunk.position.y = 6.5
	root.add_child(trunk)
	for leaf_index in range(8):
		var angle := TAU * leaf_index / 8.0
		var leaf := add_local_box(root, Vector3(0.35, 0.12, 5.2), Vector3(cos(angle) * 1.8, 13.1, sin(angle) * 1.8), Color("2c682f"))
		leaf.rotation.y = -angle
		leaf.rotation.x = -0.18
	add_child(root)


func build_center_roadside_settlement() -> void:
	if primary_road_segments.is_empty():
		return
	var center_frame := nearest_primary_frame(Vector3.ZERO)
	var direction: Vector3 = center_frame.direction
	var building_specs := [
		[-235.0, 9.0, 7.0, 3.4, Color("c48667"), "GENERAL STORE"],
		[-205.0, 8.0, 6.0, 3.2, Color("d6b46d"), "CHAI & SNACKS"],
		[-175.0, 11.0, 8.0, 4.2, Color("83a6a1"), "SHREE HOMESTAY"],
		[-138.0, 7.0, 6.0, 3.3, Color("bb785f"), "MOBILE REPAIR"],
		[-105.0, 10.0, 7.0, 4.0, Color("d0a472"), "JANIGUDA HOTEL"],
		[-70.0, 8.0, 6.0, 3.2, Color("7995aa"), "MEDICAL STORE"],
		[-38.0, 10.0, 7.0, 4.2, Color("d18c71"), "UTTARA ANNEX"],
		[0.0, 11.0, 8.0, 4.8, Color("d7b785"), "UTTARA NIVAS, JANIGUDA"],
		[38.0, 8.0, 6.0, 3.4, Color("75a28a"), "KIRANA STORE"],
		[70.0, 9.0, 7.0, 3.8, Color("c99b62"), "TIFFIN CENTRE"],
		[105.0, 11.0, 8.0, 4.4, Color("9d8bac"), "JANIGUDA HOUSE"],
		[142.0, 8.0, 6.0, 3.2, Color("cb7563"), "CYCLE REPAIR"],
		[178.0, 10.0, 7.0, 4.0, Color("c7b275"), "PROVISION STORE"],
		[215.0, 9.0, 7.0, 3.6, Color("79a1a0"), "FAMILY DHABA"],
	]
	for index in range(building_specs.size()):
		var spec: Array = building_specs[index]
		if absf(float(spec[0])) < 120.0:
			continue
		var target := direction * float(spec[0])
		var frame := nearest_primary_frame(target)
		var side: Vector3 = frame.side
		var setback := 10.0 + float(index % 3) * 2.5
		var building_position: Vector3 = frame.point + side * setback
		building_position.y = height_at(building_position.x, building_position.z)
		build_roadside_building(building_position, frame.direction, side, float(spec[1]), float(spec[2]), float(spec[3]), spec[4], spec[5], index)
		if "STORE" in String(spec[5]):
			add_shop_interaction(building_position - side * (float(spec[2]) * 0.5 + 1.2))
		if index % 2 == 0:
			build_small_tree(building_position + side * 7.0 + frame.direction * 5.0, 0.9)
	build_infill_roadside_homes(direction)
	build_forest_edge(direction)


func build_infill_roadside_homes(direction: Vector3) -> void:
	var infill_offsets := [-220.0, -190.0, -156.0, -121.0, -87.0, -54.0, -19.0, 19.0, 54.0, 87.0, 123.0, 160.0, 196.0]
	var colors := [Color("b87862"), Color("c69d6e"), Color("7d9b92"), Color("c58b68"), Color("9c8da8")]
	for index in range(infill_offsets.size()):
		if absf(float(infill_offsets[index])) < 110.0:
			continue
		var frame := nearest_primary_frame(direction * float(infill_offsets[index]))
		var side: Vector3 = frame.side
		var position: Vector3 = frame.point + side * (10.5 + float(index % 2) * 2.0)
		position.y = height_at(position.x, position.z)
		var label_text: String = "" if index % 3 != 0 else ["PAN SHOP", "VEGETABLES", "TEA STALL", "XEROX", "DAILY NEEDS"][index % 5]
		build_roadside_building(position, frame.direction, side, 6.5, 5.2, 3.1 + float(index % 3) * 0.35, colors[index % colors.size()], label_text, 100 + index)


func build_forest_edge(direction: Vector3) -> void:
	# Dense tree wall immediately west of Nandapur Road, matching the supplied
	# satellite reference rather than distributing every tree uniformly.
	var edge_trees: Array[Vector3] = []
	for along in range(-600, 601, 14):
		var frame := nearest_primary_frame(direction * float(along))
		for setback in [16.0, 27.0, 39.0, 54.0, 72.0]:
			var jitter := sin(float(along) * 0.31 + setback) * 5.0
			var position: Vector3 = frame.point - frame.side * (setback + jitter) + frame.direction * sin(setback) * 5.0
			position.y = height_at(position.x, position.z)
			edge_trees.append(position)
	build_tree_multimesh(edge_trees, Color("28532f"), 1.28)


func nearest_primary_frame(target: Vector3) -> Dictionary:
	var best_distance := INF
	var best_point := Vector3.ZERO
	var best_direction := Vector3(0, 0, -1)
	for road in primary_road_segments:
		for index in range(road.size() - 1):
			var start := road[index]
			var finish := road[index + 1]
			var closest := Geometry3D.get_closest_point_to_segment(target, start, finish)
			var distance := Vector2(target.x, target.z).distance_to(Vector2(closest.x, closest.z))
			if distance < best_distance:
				best_distance = distance
				best_point = closest
				best_direction = Vector3(finish.x - start.x, 0, finish.z - start.z).normalized()
	var side := Vector3(-best_direction.z, 0, best_direction.x)
	if side.x < 0.0:
		side = -side
	return {"point": best_point, "direction": best_direction, "side": side}


func build_roadside_building(position: Vector3, direction: Vector3, side: Vector3, width: float, depth: float, height: float, color: Color, label_text: String, variant: int) -> void:
	var root := StaticBody3D.new()
	root.name = "RoadsideBuilding_" + str(variant)
	root.position = position
	root.basis = Basis(direction, Vector3.UP, side)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(width, height, depth)
	body_mesh.material = material(color)
	body.mesh = body_mesh
	body.position.y = height * 0.5
	root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_mesh.size
	collision.shape = shape
	collision.position.y = height * 0.5
	root.add_child(collision)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(width + 0.5, 0.3, depth + 0.5)
	roof_mesh.material = material(color.lightened(0.15))
	roof.mesh = roof_mesh
	roof.position.y = height + 0.15
	root.add_child(roof)
	var shutter := MeshInstance3D.new()
	var shutter_mesh := BoxMesh.new()
	shutter_mesh.size = Vector3(width * 0.48, 2.3, 0.10)
	shutter_mesh.material = material(Color("536a70") if variant % 2 == 0 else Color("694a39"))
	shutter.mesh = shutter_mesh
	shutter.position = Vector3(0, 1.15, -depth * 0.5 - 0.06)
	root.add_child(shutter)
	var awning := MeshInstance3D.new()
	var awning_mesh := BoxMesh.new()
	awning_mesh.size = Vector3(width * 0.75, 0.18, 1.3)
	awning_mesh.material = material(Color("b84d3f") if variant % 3 == 0 else Color("e0bb53"))
	awning.mesh = awning_mesh
	awning.position = Vector3(0, 2.65, -depth * 0.5 - 0.58)
	root.add_child(awning)
	var step := MeshInstance3D.new()
	var step_mesh := BoxMesh.new()
	step_mesh.size = Vector3(width * 0.7, 0.24, 1.0)
	step_mesh.material = material(Color("aaa08d"))
	step.mesh = step_mesh
	step.position = Vector3(0, 0.12, -depth * 0.5 - 0.48)
	root.add_child(step)
	var signboard := MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(width * 0.82, 0.62, 0.10)
	sign_mesh.material = material(Color("2e5f76") if variant % 2 == 0 else Color("9c4037"))
	signboard.mesh = sign_mesh
	signboard.position = Vector3(0, minf(height - 0.45, 3.45), -depth * 0.5 - 0.10)
	root.add_child(signboard)
	for window_x in [-width * 0.30, width * 0.30]:
		var window := MeshInstance3D.new()
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(1.2, 0.9, 0.08)
		window_mesh.material = material(Color("79aebc"))
		window.mesh = window_mesh
		window.position = Vector3(window_x, minf(height - 0.9, 3.2), -depth * 0.5 - 0.07)
		root.add_child(window)
	# Roof parapets, side barrels and stacked goods add readable street-scale detail.
	for edge_z in [-depth * 0.5, depth * 0.5]:
		var parapet := MeshInstance3D.new()
		var parapet_mesh := BoxMesh.new()
		parapet_mesh.size = Vector3(width + 0.3, 0.38, 0.16)
		parapet_mesh.material = material(color.lightened(0.10))
		parapet.mesh = parapet_mesh
		parapet.position = Vector3(0, height + 0.34, edge_z)
		root.add_child(parapet)
	for crate_index in range(2):
		var crate := MeshInstance3D.new()
		var crate_mesh := BoxMesh.new()
		crate_mesh.size = Vector3(0.65, 0.55 + crate_index * 0.18, 0.65)
		crate_mesh.material = material(Color("84603d"))
		crate.mesh = crate_mesh
		crate.position = Vector3(-width * 0.38 + crate_index * 0.75, crate_mesh.size.y * 0.5, -depth * 0.5 - 0.65)
		root.add_child(crate)
	add_child(root)
	var sign_position := position + side * (-depth * 0.5 - 0.75) + Vector3(0, height - 0.35, 0)
	if not label_text.is_empty():
		add_label(label_text, sign_position, Color("fff1bc"), 28)
	if height > 4.0:
		build_water_tank(position + Vector3(0, height + 0.85, 0))


func build_water_tank(position: Vector3) -> void:
	var tank := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.7
	mesh.height = 1.4
	mesh.radial_segments = 12
	mesh.material = material(Color("292d2f"))
	tank.mesh = mesh
	tank.position = position
	add_child(tank)


func add_shop_interaction(position: Vector3) -> void:
	var shop := Area3D.new()
	shop.name = "RoadsideKiranaInteraction"
	shop.set_script(SHOP_SCRIPT)
	shop.position = position + Vector3(0, 1.0, 0)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	collision.shape = shape
	shop.add_child(collision)
	add_child(shop)


func build_parked_vehicles() -> void:
	if primary_road_segments.is_empty():
		return
	var center_frame := nearest_primary_frame(Vector3.ZERO)
	var road_direction: Vector3 = center_frame.direction
	for along in [-115.0, 82.0, 170.0]:
		var frame := nearest_primary_frame(road_direction * along)
		var position: Vector3 = frame.point + frame.side * 5.4
		position.y = height_at(position.x, position.z)
		if along == 82.0:
			build_auto_rickshaw(position, frame.direction, frame.side)
		else:
			build_parked_scooter(position, frame.direction, frame.side, int(abs(along)))


func build_auto_rickshaw(position: Vector3, direction: Vector3, side: Vector3) -> void:
	var root := Node3D.new()
	root.name = "ParkedAutoRickshaw"
	root.position = position
	root.basis = Basis(direction, Vector3.UP, side)
	add_box_part(root, Vector3(2.3, 1.0, 1.5), Vector3(0, 0.82, 0), Color("e1c62c"))
	add_box_part(root, Vector3(1.35, 1.15, 1.4), Vector3(-0.25, 1.75, 0), Color("286542"))
	add_box_part(root, Vector3(1.8, 0.17, 1.55), Vector3(-0.10, 2.38, 0), Color("202321"))
	add_box_part(root, Vector3(0.08, 0.65, 1.08), Vector3(-0.95, 1.78, 0), Color("80afba"))
	for wheel_position in [Vector3(-0.72, 0.38, -0.77), Vector3(-0.72, 0.38, 0.77), Vector3(0.78, 0.38, 0)]:
		add_wheel_part(root, wheel_position, 0.34)
	add_child(root)


func build_parked_scooter(position: Vector3, direction: Vector3, side: Vector3, variant: int) -> void:
	var root := Node3D.new()
	root.name = "ParkedScooter"
	root.position = position
	root.basis = Basis(direction, Vector3.UP, side)
	var color := Color("b84b43") if variant % 2 == 0 else Color("396f91")
	add_box_part(root, Vector3(1.4, 0.38, 0.42), Vector3(0, 0.65, 0), color)
	add_box_part(root, Vector3(0.75, 0.16, 0.38), Vector3(0.18, 0.98, 0), Color("252525"))
	add_box_part(root, Vector3(0.12, 0.85, 0.12), Vector3(-0.50, 1.12, 0), Color("55595a"))
	add_wheel_part(root, Vector3(-0.52, 0.34, 0), 0.28)
	add_wheel_part(root, Vector3(0.52, 0.34, 0), 0.28)
	add_child(root)


func add_box_part(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color)
	part.mesh = mesh
	part.position = position
	parent.add_child(part)


func add_wheel_part(parent: Node3D, position: Vector3, radius: float) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.15
	mesh.radial_segments = 10
	mesh.material = material(Color("202020"))
	wheel.mesh = mesh
	wheel.position = position
	wheel.rotation_degrees.x = 90
	parent.add_child(wheel)


func build_mapped_places() -> void:
	var file := FileAccess.open("res://data/location_osm.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	for element in data.elements:
		if element.type != "node":
			continue
		var position := latlon_to_world(float(element.lat), float(element.lon))
		position.y = height_at(position.x, position.z)
		var tags: Dictionary = element.tags
		if tags.has("place"):
			build_village_cluster(position, tags.get("name", "Village"))
		elif tags.get("amenity", "") == "school":
			build_landmark_building(position, Vector3(22, 6, 12), Color("d9b86d"), tags.get("name", "Primary School"))
		elif tags.get("amenity", "") == "place_of_worship":
			build_temple(position, tags.get("name", "Temple"))


func build_village_cluster(center: Vector3, village_name: String) -> void:
	add_label(village_name, center + Vector3(0, 8, 0), Color("fff1c9"), 54)
	var offsets := [
		Vector2(-42, -25), Vector2(-15, -38), Vector2(20, -24),
		Vector2(45, 5), Vector2(18, 30), Vector2(-24, 26), Vector2(-50, 10)
	]
	for index in range(offsets.size()):
		var offset: Vector2 = offsets[index]
		var house_position := center + Vector3(offset.x, 0, offset.y)
		house_position.y = height_at(house_position.x, house_position.z)
		build_house(house_position, index)
	add_red_soil_patch(center, 70.0)


func build_house(position: Vector3, variant: int) -> void:
	var colors := [Color("c98264"), Color("d7ae74"), Color("92a9a0"), Color("d6c497")]
	var root := StaticBody3D.new()
	root.name = "ApproximateVillageHouse"
	root.position = position
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(8, 3.2, 6)
	body_mesh.material = material(colors[variant % colors.size()])
	body.mesh = body_mesh
	body.position.y = 1.6
	root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_mesh.size
	collision.shape = shape
	collision.position.y = 1.6
	root.add_child(collision)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(8.5, 0.35, 6.5)
	roof_mesh.material = material(Color("765443"))
	roof.mesh = roof_mesh
	roof.position.y = 3.35
	root.add_child(roof)
	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.4, 2.2, 0.10)
	door_mesh.material = material(Color("4b3528"))
	door.mesh = door_mesh
	door.position = Vector3(0, 1.1, -3.06)
	root.add_child(door)
	add_child(root)


func build_landmark_building(position: Vector3, size: Vector3, color: Color, label_text: String) -> void:
	var root := StaticBody3D.new()
	root.position = position
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material(color)
	mesh_instance.mesh = box
	mesh_instance.position.y = size.y * 0.5
	root.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = size.y * 0.5
	root.add_child(collider)
	add_child(root)
	add_label(label_text, position + Vector3(0, size.y + 2.0, 0), Color.WHITE, 38)


func build_temple(position: Vector3, label_text: String) -> void:
	build_landmark_building(position, Vector3(12, 4, 10), Color("e5a84d"), label_text)
	var tower := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.15
	cone.bottom_radius = 2.2
	cone.height = 5.5
	cone.radial_segments = 8
	cone.material = material(Color("d56838"))
	tower.mesh = cone
	tower.position = position + Vector3(0, 6.75, 0)
	add_child(tower)


func add_red_soil_patch(position: Vector3, radius: float) -> void:
	var patch := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 24
	mesh.material = material(Color("9a6344"))
	patch.mesh = mesh
	patch.position = position + Vector3(0, 0.06, 0)
	add_child(patch)


func build_farm_details() -> void:
	# Field boundaries and cultivation rows on the eastern side visible in the
	# satellite reference. Every strip follows the sampled terrain height.
	for x in range(140, 901, 120):
		build_ground_strip(Vector3(x, 0, -900), Vector3(x, 0, 900), 1.1, Color("776446"), 0.07)
	for z in range(-850, 851, 140):
		build_ground_strip(Vector3(100, 0, z), Vector3(930, 0, z), 1.0, Color("776446"), 0.07)
	for x in range(175, 880, 22):
		build_ground_strip(Vector3(x, 0, 180), Vector3(x, 0, 720), 0.28, Color("ad9360"), 0.06)
	# Unpaved paths through woodland and farmland.
	build_ground_strip(Vector3(-850, 0, -520), Vector3(-80, 0, 160), 2.2, Color("956442"), 0.10)
	build_ground_strip(Vector3(-680, 0, 720), Vector3(-120, 0, 80), 1.7, Color("956442"), 0.10)
	build_ground_strip(Vector3(140, 0, -720), Vector3(780, 0, -180), 2.8, Color("9f7950"), 0.10)


func build_ground_strip(start: Vector3, finish: Vector3, width: float, color: Color, y_offset: float) -> void:
	start.y = height_at(start.x, start.z) + y_offset
	finish.y = height_at(finish.x, finish.z) + y_offset
	var points := PackedVector3Array([start, finish])
	build_road_strip(points, width, color)


func build_vegetation() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 834109
	var forest_positions: Array[Vector3] = []
	var mixed_positions: Array[Vector3] = []
	# Dense woodland west of Nandapur Road.
	for _index in range(5600):
		var point := Vector3(random.randf_range(-980, -25), 0, random.randf_range(-980, 980))
		if is_near_road(point, 11.0):
			continue
		point.y = height_at(point.x, point.z)
		forest_positions.append(point)
	# Scattered roadside and field trees, denser close to the central settlement.
	for _index in range(1200):
		var point := Vector3(random.randf_range(-80, 930), 0, random.randf_range(-950, 950))
		if is_near_road(point, 9.0):
			continue
		if point.x > 180.0 and random.randf() < 0.62:
			continue
		point.y = height_at(point.x, point.z)
		mixed_positions.append(point)
	build_tree_multimesh(forest_positions, Color("315f38"), 1.18)
	build_tree_multimesh(mixed_positions, Color("4c7842"), 1.0)


func build_tree_multimesh(positions: Array[Vector3], crown_color: Color, base_scale: float) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 3.2
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = material(Color("6f4e35"))
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.55
	crown_mesh.height = 2.8
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	crown_mesh.material = material(crown_color)
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = positions.size()
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = crown_mesh
	crowns.instance_count = positions.size()
	for index in range(positions.size()):
		var scale := base_scale * (0.78 + float((index * 37) % 43) / 100.0)
		var trunk_basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		var crown_basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		trunks.set_instance_transform(index, Transform3D(trunk_basis, positions[index] + Vector3(0, 1.6 * scale, 0)))
		crowns.set_instance_transform(index, Transform3D(crown_basis, positions[index] + Vector3(0, 3.8 * scale, 0)))
	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.multimesh = trunks
	add_child(trunk_instance)
	var crown_instance := MultiMeshInstance3D.new()
	crown_instance.multimesh = crowns
	add_child(crown_instance)


func build_small_tree(position: Vector3, scale: float) -> void:
	position.y = height_at(position.x, position.z)
	var points: Array[Vector3] = [position]
	build_tree_multimesh(points, Color("477642"), scale)


func build_grass_and_shrubs() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 690209
	var grass_positions: Array[Vector3] = []
	var shrub_positions: Array[Vector3] = []
	for _index in range(14000):
		var point := Vector3(random.randf_range(-980, 980), 0, random.randf_range(-980, 980))
		if is_near_road(point, 6.0):
			continue
		point.y = height_at(point.x, point.z)
		grass_positions.append(point)
	for _index in range(620):
		var point := Vector3(random.randf_range(-950, 500), 0, random.randf_range(-950, 950))
		if is_near_road(point, 8.0):
			continue
		point.y = height_at(point.x, point.z)
		shrub_positions.append(point)

	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.22, 0.9, 0.22)
	grass_mesh.material = material(Color("557c3d"))
	var grass_multimesh := MultiMesh.new()
	grass_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass_multimesh.mesh = grass_mesh
	grass_multimesh.instance_count = grass_positions.size()
	for index in range(grass_positions.size()):
		var scale := 0.65 + float((index * 17) % 50) / 100.0
		grass_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(scale, scale, scale)), grass_positions[index] + Vector3(0, 0.35 * scale, 0)))
	var grass_instance := MultiMeshInstance3D.new()
	grass_instance.name = "GrassTufts"
	grass_instance.multimesh = grass_multimesh
	add_child(grass_instance)

	var shrub_mesh := SphereMesh.new()
	shrub_mesh.radius = 0.65
	shrub_mesh.height = 1.0
	shrub_mesh.radial_segments = 7
	shrub_mesh.rings = 4
	shrub_mesh.material = material(Color("3f6e3d"))
	var shrub_multimesh := MultiMesh.new()
	shrub_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	shrub_multimesh.mesh = shrub_mesh
	shrub_multimesh.instance_count = shrub_positions.size()
	for index in range(shrub_positions.size()):
		shrub_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, shrub_positions[index] + Vector3(0, 0.48, 0)))
	var shrub_instance := MultiMeshInstance3D.new()
	shrub_instance.name = "Shrubs"
	shrub_instance.multimesh = shrub_multimesh
	add_child(shrub_instance)


func build_roadside_utilities() -> void:
	if primary_road_segments.is_empty():
		return
	var center_frame := nearest_primary_frame(Vector3.ZERO)
	var direction: Vector3 = center_frame.direction
	for along in range(-420, 421, 60):
		var frame := nearest_primary_frame(direction * float(along))
		var pole_position: Vector3 = frame.point - frame.side * 7.0
		pole_position.y = height_at(pole_position.x, pole_position.z)
		build_power_pole(pole_position)
	# Bus shelter and roadside direction board near the exact start coordinate.
	var start_frame := nearest_primary_frame(Vector3.ZERO)
	var shelter_position: Vector3 = start_frame.point - start_frame.side * 8.5 + start_frame.direction * 18.0
	shelter_position.y = height_at(shelter_position.x, shelter_position.z)
	build_bus_shelter(shelter_position, start_frame.direction, start_frame.side)


func build_power_pole(position: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = 6.5
	pole_mesh.radial_segments = 8
	pole_mesh.material = material(Color("686762"))
	pole.mesh = pole_mesh
	pole.position = position + Vector3(0, 3.25, 0)
	add_child(pole)
	var crossbar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.5, 0.12, 0.12)
	bar_mesh.material = material(Color("4a4640"))
	crossbar.mesh = bar_mesh
	crossbar.position = position + Vector3(0, 6.05, 0)
	add_child(crossbar)


func build_bus_shelter(position: Vector3, direction: Vector3, side: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = "JanigudaBusStop"
	root.position = position
	root.basis = Basis(direction, Vector3.UP, side)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(5.0, 0.2, 2.3)
	roof_mesh.material = material(Color("3f7290"))
	roof.mesh = roof_mesh
	roof.position.y = 2.7
	root.add_child(roof)
	for x in [-2.15, 2.15]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.14, 2.7, 0.14)
		post_mesh.material = material(Color("4c4f4f"))
		post.mesh = post_mesh
		post.position = Vector3(x, 1.35, 0)
		root.add_child(post)
	var bench := MeshInstance3D.new()
	var bench_mesh := BoxMesh.new()
	bench_mesh.size = Vector3(3.6, 0.22, 0.55)
	bench_mesh.material = material(Color("805738"))
	bench.mesh = bench_mesh
	bench.position = Vector3(0, 0.7, 0.55)
	root.add_child(bench)
	add_child(root)
	add_label("JANIGUDA BUS STOP", position + Vector3(0, 3.25, 0), Color("fff0b6"), 30)


func is_near_road(point: Vector3, distance: float) -> bool:
	for road in road_segments:
		for index in range(road.size() - 1):
			var closest := Geometry3D.get_closest_point_to_segment(point, road[index], road[index + 1])
			if Vector2(point.x, point.z).distance_to(Vector2(closest.x, closest.z)) < distance:
				return true
	return false


func latlon_to_world(latitude: float, longitude: float) -> Vector3:
	var meters_per_lon := 111320.0 * cos(deg_to_rad(CENTER_LAT))
	return Vector3((longitude - CENTER_LON) * meters_per_lon, 0, -(latitude - CENTER_LAT) * 110540.0)


func height_at(x: float, z: float) -> float:
	if elevations.is_empty():
		return 0.0
	var grid_x := clampf(x / GRID_SPACING + 4.0, 0.0, 8.0)
	var grid_z := clampf(-z / GRID_SPACING + 4.0, 0.0, 8.0)
	var x0 := int(floor(grid_x))
	var z0 := int(floor(grid_z))
	var x1 := mini(x0 + 1, 8)
	var z1 := mini(z0 + 1, 8)
	var tx := grid_x - x0
	var tz := grid_z - z0
	var a := float(elevations[z0 * SOURCE_GRID_SIZE + x0])
	var b := float(elevations[z0 * SOURCE_GRID_SIZE + x1])
	var c := float(elevations[z1 * SOURCE_GRID_SIZE + x0])
	var d := float(elevations[z1 * SOURCE_GRID_SIZE + x1])
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz) - base_elevation


func surface_height_at(x: float, z: float) -> float:
	# Match the exact two triangles generated for each 62.5 m terrain cell.
	# This is used for physics spawns so bodies never begin below a one-sided face.
	var step := WORLD_HALF_SIZE * 2.0 / TERRAIN_SUBDIVISIONS
	var column := clampi(int(floor((x + WORLD_HALF_SIZE) / step)), 0, TERRAIN_SUBDIVISIONS - 1)
	var row := clampi(int(floor((z + WORLD_HALF_SIZE) / step)), 0, TERRAIN_SUBDIVISIONS - 1)
	var x0 := -WORLD_HALF_SIZE + column * step
	var z0 := -WORLD_HALF_SIZE + row * step
	var fx := clampf((x - x0) / step, 0.0, 1.0)
	var fz := clampf((z - z0) / step, 0.0, 1.0)
	var a := height_at(x0, z0)
	var b := height_at(x0 + step, z0)
	var c := height_at(x0 + step, z0 + step)
	var d := height_at(x0, z0 + step)
	if fx >= fz:
		return a + fx * (b - a) + fz * (c - b)
	return a + fx * (c - d) + fz * (d - a)


func add_label(text: String, position: Vector3, color: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = size
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result

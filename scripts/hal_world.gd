extends Node3D

## Real-world base for the HAL Stadium / Sunabeda area.
##
## Independent of geographic_world.gd (Ratan's Janiguda area) so the two can be
## built separately and merged later, per the team's plan. Same proven data
## pipeline: real OSM roads/buildings, real SRTM elevation.
##
## World origin (0,0,0) = 18.724522, 82.826247 (given by the team - decoded
## from 18°43'28.28"N 82°49'34.49"E).

const CENTER_LAT := 18.724522
const CENTER_LON := 82.826247
const GRID_SPACING := 250.0
const TERRAIN_SUBDIVISIONS := 48
const WORLD_HALF_SIZE := 1000.0

## Real OSM way id for "HAL Stadium" (leisure=stadium), confirmed mapped.
## Its footprint is drawn as a highlighted patch - this is the real boundary
## to build the stands and pitch inside, to real scale.
const STADIUM_WAY_ID := 231036048

var elevations: Array = []
var road_segments: Array[PackedVector3Array] = []


func generate() -> void:
	load_elevation_data()
	build_terrain()
	build_roads_and_footprints()
	build_origin_marker()


func load_elevation_data() -> void:
	var file := FileAccess.open("res://data/hal_stadium_elevation.json", FileAccess.READ)
	if file == null:
		push_warning("hal_world: elevation data missing, terrain will be flat")
		return
	var data = JSON.parse_string(file.get_as_text())
	elevations = data.results


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
			add_triangle(surface, a, c, b)
			add_triangle(surface, a, d, c)
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var terrain_material := StandardMaterial3D.new()
	terrain_material.albedo_color = Color.WHITE
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.95
	terrain_mesh.surface_set_material(0, terrain_material)

	var terrain := StaticBody3D.new()
	terrain.name = "HalTerrain"
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
		surface.set_color(Color("4c6b3c").lightened(sin(point.x * 0.02) * cos(point.z * 0.017) * 0.05))
		surface.set_uv(Vector2((point.x + WORLD_HALF_SIZE) / 2000.0, (point.z + WORLD_HALF_SIZE) / 2000.0))
		surface.add_vertex(point)


## Reads real OSM ways (out geom format: coordinates embedded per element).
## Roads get a driveable strip; the HAL Stadium way gets a highlighted ground
## patch instead, since it's the thing to build on top of, not drive over.
func build_roads_and_footprints() -> void:
	var file := FileAccess.open("res://data/hal_stadium_osm.json", FileAccess.READ)
	if file == null:
		push_warning("hal_world: OSM data missing, no roads/footprints built")
		return
	var data = JSON.parse_string(file.get_as_text())
	for element in data.elements:
		if element.type != "way" or not element.has("geometry"):
			continue
		var points := PackedVector3Array()
		for coordinate in element.geometry:
			var point := latlon_to_world(float(coordinate.lat), float(coordinate.lon))
			point.y = height_at(point.x, point.z)
			points.append(point)
		if points.size() < 2:
			continue

		var tags: Dictionary = element.get("tags", {})
		if element.id == STADIUM_WAY_ID:
			build_footprint_patch(points, Color("d98f3f"), "StadiumFootprint")
			continue
		if tags.has("highway"):
			_build_road(points, tags)
		elif tags.has("building"):
			build_footprint_patch(points, Color("8a7e6c"), "BuildingFootprint_%d" % element.id)
		elif tags.get("leisure") == "pitch":
			build_footprint_patch(points, Color("5a8a4a"), "PitchFootprint_%d" % element.id)


func _build_road(points: PackedVector3Array, tags: Dictionary) -> void:
	for i in range(points.size()):
		points[i].y += 0.18
	road_segments.append(points)
	var road_type: String = tags.get("highway", "unclassified")
	var width := 6.5 if road_type == "primary" else 4.0
	build_road_strip(points, width + 2.5, Color("9a6748"), -0.08)
	build_road_strip(points, width, Color("5a5350"))


func build_road_strip(points: PackedVector3Array, width: float, color: Color, y_offset := 0.0) -> void:
	if points.size() < 2:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var direction := Vector3(finish.x - start.x, 0, finish.z - start.z).normalized()
		if direction.length_squared() < 0.0001:
			continue
		var side := Vector3(-direction.z, 0, direction.x) * width * 0.5
		start.y += y_offset
		finish.y += y_offset
		add_triangle(surface, start - side, finish - side, finish + side)
		add_triangle(surface, start - side, finish + side, start + side)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "MappedRoad"
	instance.mesh = mesh
	add_child(instance)


## Flat colored ground patch tracing a real OSM polygon (stadium, building
## footprint, pitch). This is the buildable reference outline - stands, walls
## and pitch markings go on top of it, to the real mapped shape.
func build_footprint_patch(points: PackedVector3Array, color: Color, node_name: String) -> void:
	if points.size() < 3:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := points[0]
	for i in range(1, points.size() - 1):
		var a := origin
		a.y += 0.05
		var b := points[i]
		b.y += 0.05
		var c := points[i + 1]
		c.y += 0.05
		add_triangle(surface, a, b, c)
		add_triangle(surface, a, c, b)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)


## A visible marker at world origin (0,0,0) = the exact coordinate the team
## gave. Useful while building - confirms the map data lines up correctly.
func build_origin_marker() -> void:
	var marker := MeshInstance3D.new()
	marker.name = "OriginMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.15
	mesh.height = 4.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ff3030")
	material.emission_enabled = true
	material.emission = Color("ff3030")
	material.emission_energy_multiplier = 1.5
	mesh.material = material
	marker.mesh = mesh
	marker.position = Vector3(0, height_at(0, 0) + 2.0, 0)
	add_child(marker)


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
	var h00: float = elevations[z0 * 9 + x0].elevation
	var h10: float = elevations[z0 * 9 + x1].elevation
	var h01: float = elevations[z1 * 9 + x0].elevation
	var h11: float = elevations[z1 * 9 + x1].elevation
	var h0 := lerpf(h00, h10, tx)
	var h1 := lerpf(h01, h11, tx)
	return lerpf(h0, h1, tz) - base_elevation()


func base_elevation() -> float:
	if elevations.is_empty():
		return 0.0
	return float(elevations[40].elevation)


## Height at world origin, in real metres above sea level (before the
## base_elevation subtraction that keeps the playable ground near y=0).
func origin_elevation_meters() -> float:
	if elevations.is_empty():
		return 0.0
	return float(elevations[40].elevation)

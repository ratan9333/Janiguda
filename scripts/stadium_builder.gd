@tool
extends Node3D

## HAL ground, Sunabeda. A @tool script: everything renders in the EDITOR and
## rebuilds live when you change the placement values below.
##
## The dirt ground outline and the roads are REAL (from OpenStreetMap). The
## football complex, basketball court and hockey ground are placed by you using
## the grouped offset + rotation values in the Inspector - drag them to line up
## with the satellite reference.
##
## Axes: +X = east, +Z = south (-Z = north, -X = west). 1 unit = 1 metre.
## Rotation is around Y (top-down); positive spins one way, negative the other.

@export_group("Football complex (field + gallery + lights)")
@export var complex_offset: Vector3 = Vector3.ZERO:
	set(v): complex_offset = v; _request_rebuild()
@export_range(-180, 180) var complex_rotation_deg: float = -35.0:
	set(v): complex_rotation_deg = v; _request_rebuild()

@export_group("Basketball court")
@export var court_offset: Vector3 = Vector3.ZERO:
	set(v): court_offset = v; _request_rebuild()
@export_range(-180, 180) var court_rotation_deg: float = -35.0:
	set(v): court_rotation_deg = v; _request_rebuild()

@export_group("Hockey ground")
@export var hockey_offset: Vector3 = Vector3.ZERO:
	set(v): hockey_offset = v; _request_rebuild()
@export_range(-180, 180) var hockey_rotation_deg: float = -35.0:
	set(v): hockey_rotation_deg = v; _request_rebuild()

const FIELD_MAT := preload("res://materials/field_dirt.tres")
const LINE_MAT := preload("res://materials/pitch_lines.tres")
const CONCRETE_MAT := preload("res://materials/stand_concrete.tres")
const POLE_MAT := preload("res://materials/pole_metal.tres")
const COURT_MAT := preload("res://materials/court_surface.tres")
const GROUND_MAT := preload("res://materials/ground_base.tres")
const GRASS_MAT := preload("res://materials/grass_green.tres")
const ROAD_MAT := preload("res://materials/road_surface.tres")

const FIELD_HALF_X := 37.5
const FIELD_HALF_Z := 54.0
const LINE_W := 0.12
const LINE_Y := 0.06

# Default base positions (offsets add to these). Court to the SW, hockey to NE.
const COURT_BASE := Vector3(-62.0, 0, 58.0)
const HOCKEY_BASE := Vector3(78.0, 0, -60.0)

const OSM_CENTER_LAT := 18.7244769
const OSM_CENTER_LON := 82.82651795
const STADIUM_WAY_ID := 231036048

var _root: Node3D


func _ready() -> void:
	_rebuild()


func _request_rebuild() -> void:
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	var existing := get_node_or_null("Generated")
	if existing:
		existing.free()
	_root = Node3D.new()
	_root.name = "Generated"
	add_child(_root)
	build_ground_base()
	build_real_roads()
	build_real_compound()
	build_boundary_trees()
	build_football_complex()
	build_basketball_court()
	build_hockey_ground()


# --- real, fixed ---

func build_ground_base() -> void:
	_slab("GroundBase", Vector3(2600, 0.4, 2600), Vector3(0, -0.35, 0), GROUND_MAT)


func build_real_roads() -> void:
	var data = _load_osm()
	if data == null:
		return
	var roads := _group("RealRoads")
	for element in data.elements:
		if element.type != "way" or not element.has("geometry"):
			continue
		var tags: Dictionary = element.get("tags", {})
		if not tags.has("highway"):
			continue
		var points := PackedVector3Array()
		for coordinate in element.geometry:
			points.append(_ll_to_world(float(coordinate.lat), float(coordinate.lon)))
		if points.size() < 2:
			continue
		var kind: String = tags.get("highway", "")
		var width := 7.0
		if kind in ["residential", "unclassified", "tertiary"]:
			width = 5.0
		elif kind in ["service", "track", "path", "footway"]:
			width = 3.0
		_road_strip(roads, points, width)


func build_real_compound() -> void:
	var pts := _compound_points()
	if pts.size() < 3:
		return
	var ground := _group("RealGround")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := pts[0]
	origin.y = 0.04
	for i in range(1, pts.size() - 1):
		var b := pts[i]; b.y = 0.04
		var c := pts[i + 1]; c.y = 0.04
		for tri in [[origin, b, c], [origin, c, b]]:
			for p in tri:
				surface.set_uv(Vector2(p.x * 0.05, p.z * 0.05))
				surface.add_vertex(p)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, FIELD_MAT)
	var instance := MeshInstance3D.new()
	instance.name = "GroundFill"
	instance.mesh = mesh
	ground.add_child(instance)


## Trees lining the real ground boundary (as in the satellite - a ring of
## eucalyptus hugging the outline), plus a little scatter.
func build_boundary_trees() -> void:
	var pts := _compound_points()
	if pts.size() < 3:
		return
	var trees := _group("BoundaryTrees")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var n := maxi(1, int(seg / 9.0))
		for j in range(n):
			var p := a.lerp(b, float(j) / n)
			var outward := Vector3(p.x, 0, p.z).normalized() * 5.0
			p += outward + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			_eucalyptus(trees, Vector3(p.x, 0, p.z), rng.randf_range(10.0, 16.0))


# --- placeable (offset + rotation) ---

func build_football_complex() -> void:
	var complex := _group("FootballComplex")
	complex.position = complex_offset
	complex.rotation.y = deg_to_rad(complex_rotation_deg)

	# Field markings.
	var hx := FIELD_HALF_X
	var hz := FIELD_HALF_Z
	_line(complex, Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz))
	_line(complex, Vector3(-hx, 0, hz), Vector3(hx, 0, hz))
	_line(complex, Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz))
	_line(complex, Vector3(hx, 0, -hz), Vector3(hx, 0, hz))
	_line(complex, Vector3(-hx, 0, 0), Vector3(hx, 0, 0))
	_circle(complex, 9.15, 48)
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * hz
		_slab("GoalPostL", Vector3(0.12, 2.44, 0.12), Vector3(-3.66, 1.22, z), LINE_MAT, complex)
		_slab("GoalPostR", Vector3(0.12, 2.44, 0.12), Vector3(3.66, 1.22, z), LINE_MAT, complex)
		_slab("GoalBar", Vector3(7.32, 0.12, 0.12), Vector3(0, 2.44, z), LINE_MAT, complex)

	# Open L-gallery on the west + south sides.
	var rows := 10
	var depth := 0.8
	var rise := 0.36
	var west_front := -(hx + 10.0)
	for i in range(rows):
		_slab("WestRow%d" % i, Vector3(depth, rise, hz * 2.0),
			Vector3(west_front - i * depth, i * rise + rise * 0.5, 0), CONCRETE_MAT, complex)
	var south_front := hz + 10.0
	for i in range(rows):
		_slab("SouthRow%d" % i, Vector3(hx * 2.0, rise, depth),
			Vector3(0, i * rise + rise * 0.5, south_front + i * depth), CONCRETE_MAT, complex)

	# Floodlight poles at the field corners.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(float(sx) * (hx + 8.0), 0, float(sz) * (hz + 4.0))
			_slab("Pole", Vector3(0.35, 15.0, 0.35), base + Vector3(0, 7.5, 0), POLE_MAT, complex)
			_slab("Lights", Vector3(2.2, 0.9, 0.5), base + Vector3(0, 15.0, 0), POLE_MAT, complex)


func build_basketball_court() -> void:
	var court := _group("BasketballCourt")
	court.position = COURT_BASE + court_offset
	court.rotation.y = deg_to_rad(court_rotation_deg)
	_slab("CourtSurface", Vector3(15.0, 0.15, 30.0), Vector3(0, 0.02, 0), COURT_MAT, court)
	_court_line(court, Vector3(-7.5, 0, -15), Vector3(7.5, 0, -15))
	_court_line(court, Vector3(-7.5, 0, 15), Vector3(7.5, 0, 15))
	_court_line(court, Vector3(-7.5, 0, -15), Vector3(-7.5, 0, 15))
	_court_line(court, Vector3(7.5, 0, -15), Vector3(7.5, 0, 15))
	_court_line(court, Vector3(-7.5, 0, 0), Vector3(7.5, 0, 0))
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * 14.0
		_slab("HoopPole", Vector3(0.2, 3.05, 0.2), Vector3(0, 1.52, z), POLE_MAT, court)
		_slab("Backboard", Vector3(1.8, 1.05, 0.1), Vector3(0, 3.05, z - sign * 0.3), POLE_MAT, court)


func build_hockey_ground() -> void:
	var hockey := _group("OldHockeyGround")
	hockey.position = HOCKEY_BASE + hockey_offset
	hockey.rotation.y = deg_to_rad(hockey_rotation_deg)
	var hx := 45.5
	var hz := 27.5
	_slab("HockeyField", Vector3(hx * 2, 0.16, hz * 2), Vector3(0, -0.08, 0), GRASS_MAT, hockey)
	for pair in [[Vector3(-hx,0,-hz), Vector3(hx,0,-hz)], [Vector3(-hx,0,hz), Vector3(hx,0,hz)],
			[Vector3(-hx,0,-hz), Vector3(-hx,0,hz)], [Vector3(hx,0,-hz), Vector3(hx,0,hz)],
			[Vector3(0,0,-hz), Vector3(0,0,hz)]]:
		_thin_line(hockey, pair[0], pair[1], 0.1, 0.1)


# --- helpers ---

func _compound_points() -> PackedVector3Array:
	var data = _load_osm()
	var out := PackedVector3Array()
	if data == null:
		return out
	for element in data.elements:
		if element.type == "way" and int(element.id) == STADIUM_WAY_ID and element.has("geometry"):
			for coordinate in element.geometry:
				out.append(_ll_to_world(float(coordinate.lat), float(coordinate.lon)))
			break
	return out


func _load_osm():
	var file := FileAccess.open("res://data/hal_stadium_osm.json", FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _ll_to_world(latitude: float, longitude: float) -> Vector3:
	var meters_per_lon := 111320.0 * cos(deg_to_rad(OSM_CENTER_LAT))
	return Vector3((longitude - OSM_CENTER_LON) * meters_per_lon, 0.03, -(latitude - OSM_CENTER_LAT) * 110540.0)


func _road_strip(parent: Node, points: PackedVector3Array, width: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var direction := Vector3(finish.x - start.x, 0, finish.z - start.z)
		if direction.length_squared() < 0.0001:
			continue
		var side := Vector3(-direction.z, 0, direction.x).normalized() * width * 0.5
		for tri in [[start - side, finish - side, finish + side], [start - side, finish + side, start + side]]:
			for p in tri:
				surface.set_uv(Vector2(p.x * 0.05, p.z * 0.05))
				surface.add_vertex(p)
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null:
		return
	mesh.surface_set_material(0, ROAD_MAT)
	var instance := MeshInstance3D.new()
	instance.name = "Road"
	instance.mesh = mesh
	parent.add_child(instance)


func _group(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	_root.add_child(node)
	return node


func _eucalyptus(parent: Node, pos: Vector3, height: float) -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("7a6a55")
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color("39502a")
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = height
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0, height * 0.5, 0)
	parent.add_child(trunk)
	for k in range(2):
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 2.2
		crown_mesh.height = 7.0
		crown_mesh.material = foliage_mat
		crown.mesh = crown_mesh
		crown.position = pos + Vector3(0, height + k * 2.5 - 1.0, 0)
		parent.add_child(crown)


func _slab(node_name: String, size: Vector3, position: Vector3, material: Material, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	if parent == null:
		parent = _root
	parent.add_child(body)
	return body


func _line(parent: Node, a: Vector3, b: Vector3) -> void:
	_thin_line(parent, a, b, LINE_W, LINE_Y)


func _court_line(parent: Node, a: Vector3, b: Vector3) -> void:
	_thin_line(parent, a, b, 0.08, 0.11)


func _thin_line(parent: Node, a: Vector3, b: Vector3, width: float, y: float) -> void:
	var length := a.distance_to(b)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.04, width)
	mesh.material = LINE_MAT
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Line"
	mesh_instance.mesh = mesh
	mesh_instance.position = (a + b) * 0.5 + Vector3(0, y, 0)
	mesh_instance.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	parent.add_child(mesh_instance)


func _circle(parent: Node, radius: float, segments: int) -> void:
	var previous := Vector3(radius, 0, 0)
	for i in range(1, segments + 1):
		var angle := TAU * i / segments
		var point := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_line(parent, previous, point)
		previous = point

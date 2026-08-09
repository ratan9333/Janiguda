@tool
extends Node3D

## HAL ground, Sunabeda - a rural open sports ground.
##
## This is a @tool script: it runs IN THE EDITOR, so the whole ground is visible
## in the editor viewport without pressing play, and it rebuilds live when you
## change a placement offset below.
##
## To place things yourself: select this StadiumBuild node, and in the Inspector
## change Field/Gallery/Court/Hockey Offset. The ground updates immediately.
##
## Axes: +X = east, +Z = south (-Z = north, -X = west). 1 unit = 1 metre.

@export_group("Placement — drag these numbers to move pieces (live)")
@export var field_offset: Vector3 = Vector3.ZERO:
	set(value):
		field_offset = value
		_request_rebuild()
@export var gallery_offset: Vector3 = Vector3.ZERO:
	set(value):
		gallery_offset = value
		_request_rebuild()
@export var court_offset: Vector3 = Vector3.ZERO:
	set(value):
		court_offset = value
		_request_rebuild()
@export var hockey_offset: Vector3 = Vector3.ZERO:
	set(value):
		hockey_offset = value
		_request_rebuild()

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

# Base positions (offsets add to these). Hockey sits just north of the field.
const COURT_BASE := Vector3(-58.0, 0, 44.0)
const HOCKEY_BASE := Vector3(18.0, 0, -86.0)

# Real-world centre = the HAL Stadium footprint centroid (from OSM). Roads and
# the real ground outline are placed relative to this, so the scene origin sits
# at the middle of the actual ground.
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
	# _root has no owner, so none of the generated geometry is saved into the
	# .tscn - it is rebuilt fresh from this script every time.
	build_ground_base()
	build_real_roads()        # actual OSM road network (~1 km)
	build_real_compound()     # actual HAL ground outline, filled as dirt
	build_hockey_ground()
	build_football_field()    # markings + goals on the real ground (placeable)
	build_open_gallery()
	build_basketball_court()
	build_trees()
	build_floodlights()


# --- fixed shell ---

func build_ground_base() -> void:
	# Large enough to sit under the ~1 km road network.
	_slab("GroundBase", Vector3(2600, 0.4, 2600), Vector3(0, -0.35, 0), GROUND_MAT)


## Real road network from OpenStreetMap (© OpenStreetMap contributors, ODbL),
## everything within the ~1.2 km query radius, positioned relative to the ground.
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
		if kind == "residential" or kind == "unclassified" or kind == "tertiary":
			width = 5.0
		elif kind == "service" or kind == "track" or kind == "path" or kind == "footway":
			width = 3.0
		_road_strip(roads, points, width)


## The real HAL ground outline (OSM way), filled with dirt - the exact shape and
## size of the bare-earth ground from the map.
func build_real_compound() -> void:
	var data = _load_osm()
	if data == null:
		return
	var stadium
	for element in data.elements:
		if element.type == "way" and int(element.id) == STADIUM_WAY_ID:
			stadium = element
			break
	if stadium == null or not stadium.has("geometry"):
		return
	var pts := PackedVector3Array()
	for coordinate in stadium.geometry:
		pts.append(_ll_to_world(float(coordinate.lat), float(coordinate.lon)))
	if pts.size() < 3:
		return
	var ground := _group("RealGround")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := pts[0]
	origin.y = 0.04
	for i in range(1, pts.size() - 1):
		var a := origin
		var b := pts[i]; b.y = 0.04
		var c := pts[i + 1]; c.y = 0.04
		for tri in [[a, b, c], [a, c, b]]:  # double-sided
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


func build_trees() -> void:
	var trees := _group("Trees")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4747
	var count := 44
	for i in range(count):
		var angle := TAU * float(i) / count
		var rx := 66.0 + rng.randf_range(-4.0, 4.0)
		var rz := 116.0 + rng.randf_range(-6.0, 6.0)
		var pos := Vector3(cos(angle) * rx, 0, sin(angle) * rz - 18.0)
		_eucalyptus(trees, pos, rng.randf_range(11.0, 17.0))


func build_floodlights() -> void:
	var poles := _group("Floodlights")
	var px := FIELD_HALF_X + 20.0
	var pz := FIELD_HALF_Z + 6.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(float(sx) * px, 0, float(sz) * pz) + field_offset
			_slab("Pole", Vector3(0.35, 15.0, 0.35), base + Vector3(0, 7.5, 0), POLE_MAT, poles)
			_slab("Lights", Vector3(2.2, 0.9, 0.5), base + Vector3(0, 15.0, 0), POLE_MAT, poles)


# --- placeable elements ---

func build_football_field() -> void:
	# Markings + goals only; the dirt ground comes from the real OSM outline.
	var field := _group("FootballField")
	field.position = field_offset
	var hx := FIELD_HALF_X
	var hz := FIELD_HALF_Z
	_line(field, Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz))
	_line(field, Vector3(-hx, 0, hz), Vector3(hx, 0, hz))
	_line(field, Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz))
	_line(field, Vector3(hx, 0, -hz), Vector3(hx, 0, hz))
	_line(field, Vector3(-hx, 0, 0), Vector3(hx, 0, 0))
	_circle(field, 9.15, 48)
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * hz
		_slab("GoalPostL", Vector3(0.12, 2.44, 0.12), Vector3(-3.66, 1.22, z), LINE_MAT, field)
		_slab("GoalPostR", Vector3(0.12, 2.44, 0.12), Vector3(3.66, 1.22, z), LINE_MAT, field)
		_slab("GoalBar", Vector3(7.32, 0.12, 0.12), Vector3(0, 2.44, z), LINE_MAT, field)


func build_open_gallery() -> void:
	var gallery := _group("OpenGallery")
	gallery.position = field_offset + gallery_offset
	var rows := 10
	var depth := 0.8
	var rise := 0.36
	var west_front := -(FIELD_HALF_X + 12.0)
	for i in range(rows):
		_slab("WestRow%d" % i, Vector3(depth, rise, FIELD_HALF_Z * 2.0),
			Vector3(west_front - i * depth, i * rise + rise * 0.5, 0), CONCRETE_MAT, gallery)
	var south_front := FIELD_HALF_Z + 12.0
	for i in range(rows):
		_slab("SouthRow%d" % i, Vector3(FIELD_HALF_X * 2.0, rise, depth),
			Vector3(0, i * rise + rise * 0.5, south_front + i * depth), CONCRETE_MAT, gallery)


func build_basketball_court() -> void:
	var court := _group("BasketballCourt")
	court.position = COURT_BASE + court_offset
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
	var hx := 45.5
	var hz := 27.5
	_slab("HockeyField", Vector3(hx * 2, 0.16, hz * 2), Vector3(0, -0.08, 0), GRASS_MAT, hockey)
	for pair in [[Vector3(-hx,0,-hz), Vector3(hx,0,-hz)], [Vector3(-hx,0,hz), Vector3(hx,0,hz)],
			[Vector3(-hx,0,-hz), Vector3(-hx,0,hz)], [Vector3(hx,0,-hz), Vector3(hx,0,hz)],
			[Vector3(0,0,-hz), Vector3(0,0,hz)]]:
		_thin_line(hockey, pair[0], pair[1], 0.1, 0.1)


# --- helpers ---

func _group(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	_root.add_child(node)
	return node


func _load_osm():
	var file := FileAccess.open("res://data/hal_stadium_osm.json", FileAccess.READ)
	if file == null:
		push_warning("stadium_builder: OSM data not found")
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

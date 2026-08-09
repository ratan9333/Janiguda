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
	build_roads()
	build_perimeter()
	build_running_track()
	build_hockey_ground()
	build_football_field()
	build_open_gallery()
	build_basketball_court()
	build_trees()
	build_floodlights()


# --- fixed shell ---

func build_ground_base() -> void:
	_slab("GroundBase", Vector3(420, 0.4, 420), Vector3(0, -0.35, 0), GROUND_MAT)


func build_roads() -> void:
	_slab("RoadWest", Vector3(8, 0.1, 260), Vector3(-84, 0.02, -30), ROAD_MAT)
	_slab("RoadSouth", Vector3(180, 0.1, 8), Vector3(-10, 0.02, 104), ROAD_MAT)
	_slab("RoadEast", Vector3(8, 0.1, 200), Vector3(80, 0.02, -20), ROAD_MAT)


func build_perimeter() -> void:
	var wall := _group("PerimeterBoundary")
	var x0 := -74.0
	var x1 := 74.0
	var z0 := -128.0
	var z1 := 94.0
	var h := 1.6
	_slab("WallN", Vector3(x1 - x0, h, 0.3), Vector3((x0 + x1) * 0.5, h * 0.5, z0), CONCRETE_MAT, wall)
	_slab("WallS", Vector3(x1 - x0, h, 0.3), Vector3((x0 + x1) * 0.5, h * 0.5, z1), CONCRETE_MAT, wall)
	_slab("WallW", Vector3(0.3, h, z1 - z0), Vector3(x0, h * 0.5, (z0 + z1) * 0.5), CONCRETE_MAT, wall)
	_slab("WallE", Vector3(0.3, h, z1 - z0), Vector3(x1, h * 0.5, (z0 + z1) * 0.5), CONCRETE_MAT, wall)


## Rectangular dirt running-track loop around the football field (4 straights).
func build_running_track() -> void:
	var track := _group("RunningTrack")
	var ix := FIELD_HALF_X + 9.0
	var iz := FIELD_HALF_Z + 9.0
	var w := 6.0
	var c := field_offset
	# North & south straights.
	_slab("TrackN", Vector3((ix + w) * 2, 0.1, w), c + Vector3(0, 0.05, -(iz + w * 0.5)), FIELD_MAT, track)
	_slab("TrackS", Vector3((ix + w) * 2, 0.1, w), c + Vector3(0, 0.05, iz + w * 0.5), FIELD_MAT, track)
	# East & west straights.
	_slab("TrackW", Vector3(w, 0.1, iz * 2), c + Vector3(-(ix + w * 0.5), 0.05, 0), FIELD_MAT, track)
	_slab("TrackE", Vector3(w, 0.1, iz * 2), c + Vector3(ix + w * 0.5, 0.05, 0), FIELD_MAT, track)


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
	var field := _group("FootballField")
	field.position = field_offset
	_slab("FieldPad", Vector3(FIELD_HALF_X * 2 + 4, 0.2, FIELD_HALF_Z * 2 + 4), Vector3(0, -0.1, 0), FIELD_MAT, field)
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

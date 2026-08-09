extends Node3D

## HAL ground, Sunabeda - a rural open sports ground, not a formal stadium.
##
## This script builds the fixed SHELL around the ground: dry-grass terrain, a
## closed boundary, surrounding roads, the dirt running-track loop, eucalyptus
## trees, floodlight poles, and the green hockey ground to the NE.
##
## The football field, open gallery and basketball court are placed via the
## exported offsets below so you can position them yourself: select the
## StadiumBuild node, nudge the offsets in the Inspector, press F5.
##
## Axes: +X = east, +Z = south (-Z = north, -X = west).

@export_group("Placement — nudge, then press F5")
@export var field_offset: Vector3 = Vector3.ZERO
@export var gallery_offset: Vector3 = Vector3.ZERO
@export var court_offset: Vector3 = Vector3.ZERO
@export var hockey_offset: Vector3 = Vector3.ZERO

const FIELD_MAT := preload("res://materials/field_dirt.tres")
const LINE_MAT := preload("res://materials/pitch_lines.tres")
const CONCRETE_MAT := preload("res://materials/stand_concrete.tres")
const POLE_MAT := preload("res://materials/pole_metal.tres")
const COURT_MAT := preload("res://materials/court_surface.tres")
const GROUND_MAT := preload("res://materials/ground_base.tres")
const GRASS_MAT := preload("res://materials/grass_green.tres")
const ROAD_MAT := preload("res://materials/road_surface.tres")

# Football field (metres). Long axis along Z.
const FIELD_HALF_X := 37.5
const FIELD_HALF_Z := 54.0
const LINE_W := 0.12
const LINE_Y := 0.06

# Default base positions (offsets add to these).
const COURT_BASE := Vector3(-58.0, 0, 44.0)
const HOCKEY_BASE := Vector3(30.0, 0, -118.0)


func _ready() -> void:
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
	# Rural roads/paths around the ground (matches the annotated satellite).
	_slab("RoadWest", Vector3(8, 0.1, 260), Vector3(-84, 0.02, -30), ROAD_MAT)
	_slab("RoadSouth", Vector3(180, 0.1, 8), Vector3(-10, 0.02, 104), ROAD_MAT)
	_slab("RoadEast", Vector3(8, 0.1, 200), Vector3(80, 0.02, -20), ROAD_MAT)


func build_perimeter() -> void:
	# Closed boundary enclosing the whole complex.
	var wall := Node3D.new()
	wall.name = "PerimeterBoundary"
	add_child(wall)
	var x0 := -74.0
	var x1 := 74.0
	var z0 := -150.0
	var z1 := 94.0
	var h := 1.6
	_slab("WallN", Vector3(x1 - x0, h, 0.3), Vector3((x0 + x1) * 0.5, h * 0.5, z0), CONCRETE_MAT, wall)
	_slab("WallS", Vector3(x1 - x0, h, 0.3), Vector3((x0 + x1) * 0.5, h * 0.5, z1), CONCRETE_MAT, wall)
	_slab("WallW", Vector3(0.3, h, z1 - z0), Vector3(x0, h * 0.5, (z0 + z1) * 0.5), CONCRETE_MAT, wall)
	_slab("WallE", Vector3(0.3, h, z1 - z0), Vector3(x1, h * 0.5, (z0 + z1) * 0.5), CONCRETE_MAT, wall)


## Dirt running-track loop around the football field.
func build_running_track() -> void:
	var rx := FIELD_HALF_X + 9.0
	var rz := FIELD_HALF_Z + 9.0
	var width := 6.0
	var segments := 72
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var inner0 := Vector3(cos(a0) * rx, 0.05, sin(a0) * rz) + field_offset
		var outer0 := Vector3(cos(a0) * (rx + width), 0.05, sin(a0) * (rz + width)) + field_offset
		var inner1 := Vector3(cos(a1) * rx, 0.05, sin(a1) * rz) + field_offset
		var outer1 := Vector3(cos(a1) * (rx + width), 0.05, sin(a1) * (rz + width)) + field_offset
		for tri in [[inner0, outer1, outer0], [inner0, inner1, outer1]]:
			for p in tri:
				surface.set_uv(Vector2(p.x * 0.1, p.z * 0.1))
				surface.add_vertex(p)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, FIELD_MAT)
	var instance := MeshInstance3D.new()
	instance.name = "RunningTrack"
	instance.mesh = mesh
	add_child(instance)


func build_trees() -> void:
	var trees := Node3D.new()
	trees.name = "Trees"
	add_child(trees)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4747
	# Ring of eucalyptus just inside the perimeter.
	var count := 46
	for i in range(count):
		var t := float(i) / count
		var angle := TAU * t
		var rx := 66.0 + rng.randf_range(-4.0, 4.0)
		var rz := 128.0 + rng.randf_range(-6.0, 6.0)
		var pos := Vector3(cos(angle) * rx, 0, sin(angle) * rz - 28.0)
		_eucalyptus(trees, pos, rng.randf_range(11.0, 17.0))


func build_floodlights() -> void:
	var poles := Node3D.new()
	poles.name = "Floodlights"
	add_child(poles)
	var px := FIELD_HALF_X + 20.0
	var pz := FIELD_HALF_Z + 6.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(float(sx) * px, 0, float(sz) * pz) + field_offset
			# Thin rural pole with a small light cluster on top.
			_slab("Pole", Vector3(0.35, 15.0, 0.35), base + Vector3(0, 7.5, 0), POLE_MAT, poles)
			_slab("Lights", Vector3(2.2, 0.9, 0.5), base + Vector3(0, 15.0, 0), POLE_MAT, poles)


# --- placeable elements (moved by the exported offsets) ---

func build_football_field() -> void:
	var field := Node3D.new()
	field.name = "FootballField"
	field.position = field_offset
	add_child(field)
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


## Open, low concrete terracing (rural style) on two adjacent sides - an L at
## the SW of the field. No roof.
func build_open_gallery() -> void:
	var gallery := Node3D.new()
	gallery.name = "OpenGallery"
	gallery.position = field_offset + gallery_offset
	add_child(gallery)
	var rows := 10
	var depth := 0.8
	var rise := 0.36
	# West arm (runs along Z).
	var west_front := -(FIELD_HALF_X + 12.0)
	for i in range(rows):
		_slab("WestRow%d" % i, Vector3(depth, rise, FIELD_HALF_Z * 2.0),
			Vector3(west_front - i * depth, i * rise + rise * 0.5, 0), CONCRETE_MAT, gallery)
	# South arm (runs along X), meeting the west arm.
	var south_front := FIELD_HALF_Z + 12.0
	for i in range(rows):
		_slab("SouthRow%d" % i, Vector3(FIELD_HALF_X * 2.0, rise, depth),
			Vector3(0, i * rise + rise * 0.5, south_front + i * depth), CONCRETE_MAT, gallery)


func build_basketball_court() -> void:
	var court := Node3D.new()
	court.name = "BasketballCourt"
	var origin := COURT_BASE + court_offset
	court.position = origin
	add_child(court)
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
	var hockey := Node3D.new()
	hockey.name = "OldHockeyGround"
	hockey.position = HOCKEY_BASE + hockey_offset
	add_child(hockey)
	var hx := 45.5
	var hz := 27.5
	_slab("HockeyField", Vector3(hx * 2, 0.16, hz * 2), Vector3(0, -0.08, 0), GRASS_MAT, hockey)
	for pair in [[Vector3(-hx,0,-hz), Vector3(hx,0,-hz)], [Vector3(-hx,0,hz), Vector3(hx,0,hz)],
			[Vector3(-hx,0,-hz), Vector3(-hx,0,hz)], [Vector3(hx,0,-hz), Vector3(hx,0,hz)],
			[Vector3(0,0,-hz), Vector3(0,0,hz)]]:
		_thin_line(hockey, pair[0], pair[1], 0.1, 0.1)


# --- helpers ---

func _eucalyptus(parent: Node, pos: Vector3, height: float) -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("7a6a55")
	trunk_mat.roughness = 1.0
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color("39502a")
	foliage_mat.roughness = 1.0

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = height
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0, height * 0.5, 0)
	parent.add_child(trunk)
	# Tall, narrow eucalyptus crown from a couple of stretched spheres.
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
	if parent:
		parent.add_child(body)
	else:
		add_child(body)
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

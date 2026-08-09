extends Node3D

## Blocks out the real HAL Stadium ground (SAI Football Stadium, Sunabeda) to
## match the satellite layout: a bare-EARTH field (smaller than regulation), a
## covered grandstand with a corrugated roof down the west side, lower open
## terracing on the east, floodlight poles, and a boundary wall.
##
## Placeholder materials are real .tres resources in res://materials/ so every
## surface (dirt, concrete, roof metal) can be textured in the Inspector.
##
## Built at the scene origin; will be moved to the real footprint when
## integrated into hal_world.

const FIELD_MAT := preload("res://materials/field_dirt.tres")
const LINE_MAT := preload("res://materials/pitch_lines.tres")
const CONCRETE_MAT := preload("res://materials/stand_concrete.tres")
const ROOF_MAT := preload("res://materials/roof_metal.tres")
const POLE_MAT := preload("res://materials/pole_metal.tres")

# Real ground is smaller than a regulation pitch. Long axis runs along Z.
const FIELD_HALF_X := 31.0   # half-width  (62 m)
const FIELD_HALF_Z := 48.0   # half-length (96 m)
const LINE_W := 0.12
const LINE_Y := 0.06

# West grandstand (covered).
const WEST_ROWS := 18
const EAST_ROWS := 7
const ROW_DEPTH := 0.75
const ROW_RISE := 0.40
const STAND_LEN := 86.0       # along Z
const RUNOFF := 6.0           # gap between field edge and first row


func _ready() -> void:
	build_field()
	build_markings()
	build_goals()
	build_west_grandstand()
	build_east_terrace()
	build_floodlights()
	build_boundary_wall()


func build_field() -> void:
	_slab("Field", Vector3(FIELD_HALF_X * 2 + 6, 0.2, FIELD_HALF_Z * 2 + 6), Vector3(0, -0.1, 0), FIELD_MAT)


func build_markings() -> void:
	var hx := FIELD_HALF_X
	var hz := FIELD_HALF_Z
	# Boundary.
	_line(Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz))
	_line(Vector3(-hx, 0, hz), Vector3(hx, 0, hz))
	_line(Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz))
	_line(Vector3(hx, 0, -hz), Vector3(hx, 0, hz))
	# Halfway line (across the short axis) + centre circle.
	_line(Vector3(-hx, 0, 0), Vector3(hx, 0, 0))
	_circle(Vector3.ZERO, 8.0, 40)
	# Penalty areas at each end (scaled to the smaller pitch).
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z_line := sign * (hz - 14.0)
		var pw := 18.0
		_line(Vector3(-pw, 0, z_line), Vector3(pw, 0, z_line))
		_line(Vector3(-pw, 0, sign * hz), Vector3(-pw, 0, z_line))
		_line(Vector3(pw, 0, sign * hz), Vector3(pw, 0, z_line))


func build_goals() -> void:
	# Goals sit on the short ends (z = +/- half-length).
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * FIELD_HALF_Z
		_slab("GoalPostL", Vector3(0.12, 2.44, 0.12), Vector3(-3.66, 1.22, z), LINE_MAT)
		_slab("GoalPostR", Vector3(0.12, 2.44, 0.12), Vector3(3.66, 1.22, z), LINE_MAT)
		_slab("GoalBar", Vector3(7.32, 0.12, 0.12), Vector3(0, 2.44, z), LINE_MAT)


## The signature covered gallery on the west (-x) long side: raked concrete
## terracing rising away from the field, under a sloped corrugated roof on
## columns.
func build_west_grandstand() -> void:
	var stand := Node3D.new()
	stand.name = "WestGrandstand"
	add_child(stand)
	var front_x := -(FIELD_HALF_X + RUNOFF)
	for i in range(WEST_ROWS):
		var x := front_x - i * ROW_DEPTH
		var y := i * ROW_RISE
		_slab("Row%d" % i, Vector3(ROW_DEPTH, ROW_RISE, STAND_LEN),
			Vector3(x, y + ROW_RISE * 0.5, 0), CONCRETE_MAT, stand)
	var back_x := front_x - WEST_ROWS * ROW_DEPTH
	var top_y := WEST_ROWS * ROW_RISE
	# Back wall.
	_slab("BackWall", Vector3(0.4, top_y + 1.6, STAND_LEN + 1.0),
		Vector3(back_x, (top_y + 1.6) * 0.5, 0), CONCRETE_MAT, stand)

	# Roof: sloped corrugated slab over the terracing, on a row of columns.
	var roof_depth := (front_x - back_x) + 3.0  # covers front runoff to back wall
	var roof_center_x := (front_x - back_x) * 0.5 + back_x + 1.0
	var roof := _slab("Roof", Vector3(absf(roof_depth), 0.25, STAND_LEN + 2.0),
		Vector3(roof_center_x, top_y + 3.5, 0), ROOF_MAT, stand)
	# Slope it so the front edge (over the field) sits lower than the back.
	roof.rotation.z = deg_to_rad(-9.0)
	# Front columns holding the roof up.
	var col_z := STAND_LEN * 0.5 - 3.0
	var z := -col_z
	while z <= col_z:
		_slab("Column", Vector3(0.4, top_y + 3.0, 0.4),
			Vector3(front_x + 0.5, (top_y + 3.0) * 0.5, z), POLE_MAT, stand)
		z += 8.0


## Lower, open terracing on the east (+x) side.
func build_east_terrace() -> void:
	var stand := Node3D.new()
	stand.name = "EastTerrace"
	add_child(stand)
	var front_x := FIELD_HALF_X + RUNOFF
	for i in range(EAST_ROWS):
		var x := front_x + i * ROW_DEPTH
		var y := i * ROW_RISE
		_slab("Row%d" % i, Vector3(ROW_DEPTH, ROW_RISE, STAND_LEN * 0.8),
			Vector3(x, y + ROW_RISE * 0.5, 0), CONCRETE_MAT, stand)


func build_floodlights() -> void:
	var poles := Node3D.new()
	poles.name = "Floodlights"
	add_child(poles)
	var px := FIELD_HALF_X + 12.0
	var pz := FIELD_HALF_Z - 4.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(float(sx) * px, 0, float(sz) * pz)
			_slab("Pole", Vector3(0.5, 18.0, 0.5), base + Vector3(0, 9.0, 0), POLE_MAT, poles)
			# Light housing angled toward the field.
			var housing := _slab("Lights", Vector3(3.0, 1.4, 0.6),
				base + Vector3(-float(sx) * 1.2, 17.5, 0), POLE_MAT, poles)
			housing.rotation.z = deg_to_rad(float(sx) * 20.0)


func build_boundary_wall() -> void:
	var wall := Node3D.new()
	wall.name = "BoundaryWall"
	add_child(wall)
	var wx := FIELD_HALF_X + 22.0
	var wz := FIELD_HALF_Z + 14.0
	var h := 2.2
	_slab("WallN", Vector3(wx * 2, h, 0.4), Vector3(0, h * 0.5, -wz), CONCRETE_MAT, wall)
	_slab("WallS", Vector3(wx * 2, h, 0.4), Vector3(0, h * 0.5, wz), CONCRETE_MAT, wall)
	_slab("WallE", Vector3(0.4, h, wz * 2), Vector3(wx, h * 0.5, 0), CONCRETE_MAT, wall)
	_slab("WallW", Vector3(0.4, h, wz * 2), Vector3(-wx, h * 0.5, 0), CONCRETE_MAT, wall)


## A box mesh + collider (StaticBody so it's walkable once integrated). Returns
## the body so callers can rotate it (roof slope, light housings).
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


func _line(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.04, LINE_W)
	mesh.material = LINE_MAT
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Line"
	mesh_instance.mesh = mesh
	mesh_instance.position = (a + b) * 0.5 + Vector3(0, LINE_Y, 0)
	mesh_instance.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	add_child(mesh_instance)


func _circle(centre: Vector3, radius: float, segments: int) -> void:
	var previous := centre + Vector3(radius, 0, 0)
	for i in range(1, segments + 1):
		var angle := TAU * i / segments
		var point := centre + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_line(previous, point)
		previous = point

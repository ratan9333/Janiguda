extends Node3D

## Blocks out the HAL Stadium field to real scale: a regulation football pitch
## with markings, and one gallery stand (concrete terracing + walls) down the
## long side. Placeholder materials are real .tres resources in res://materials/
## so they can be textured in the Inspector without touching code.
##
## Built at the scene origin. When integrated into hal_world it will be moved to
## the real stadium footprint centre.

const PITCH_MAT := preload("res://materials/pitch.tres")
const LINE_MAT := preload("res://materials/pitch_lines.tres")
const CONCRETE_MAT := preload("res://materials/stand_concrete.tres")

# Regulation dimensions (metres).
const PITCH_L := 105.0
const PITCH_W := 68.0
const LINE_W := 0.12
const LINE_Y := 0.08

# Gallery stand.
const STAND_ROWS := 16
const STAND_ROW_DEPTH := 0.8
const STAND_ROW_RISE := 0.42
const STAND_LENGTH := 108.0


func _ready() -> void:
	build_pitch()
	build_markings()
	build_goals()
	build_stand()


func build_pitch() -> void:
	# A little apron of grass around the lines so the pitch isn't cut off sharp.
	_slab("Pitch", Vector3(PITCH_L + 10.0, 0.2, PITCH_W + 10.0), Vector3(0, -0.1, 0), PITCH_MAT)


func build_markings() -> void:
	var hl := PITCH_L * 0.5
	var hw := PITCH_W * 0.5
	# Boundary.
	_line(Vector3(-hl, 0, -hw), Vector3(hl, 0, -hw))
	_line(Vector3(-hl, 0, hw), Vector3(hl, 0, hw))
	_line(Vector3(-hl, 0, -hw), Vector3(-hl, 0, hw))
	_line(Vector3(hl, 0, -hw), Vector3(hl, 0, hw))
	# Halfway line + centre circle + spot.
	_line(Vector3(0, 0, -hw), Vector3(0, 0, hw))
	_circle(Vector3.ZERO, 9.15, 48)
	_slab("CentreSpot", Vector3(0.3, 0.04, 0.3), Vector3(0, LINE_Y, 0), LINE_MAT)
	# Penalty areas (16.5 m deep, 40.3 m wide) at each end.
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var x_line := sign * (hl - 16.5)
		var pw := 40.3 * 0.5
		_line(Vector3(x_line, 0, -pw), Vector3(x_line, 0, pw))
		_line(Vector3(sign * hl, 0, -pw), Vector3(x_line, 0, -pw))
		_line(Vector3(sign * hl, 0, pw), Vector3(x_line, 0, pw))


func build_goals() -> void:
	var hl := PITCH_L * 0.5
	# 7.32 m wide, 2.44 m tall.
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var x := sign * hl
		_slab("GoalPostL", Vector3(0.12, 2.44, 0.12), Vector3(x, 1.22, -3.66), LINE_MAT)
		_slab("GoalPostR", Vector3(0.12, 2.44, 0.12), Vector3(x, 1.22, 3.66), LINE_MAT)
		_slab("GoalBar", Vector3(0.12, 0.12, 7.32), Vector3(x, 2.44, 0), LINE_MAT)


## Raked concrete terracing down the +z long side, plus back and side walls.
## This is the piece to texture with a real concrete material.
func build_stand() -> void:
	var stand := Node3D.new()
	stand.name = "GalleryStand"
	add_child(stand)
	var z_front := PITCH_W * 0.5 + 6.0  # 6 m runoff between pitch and stand
	for i in range(STAND_ROWS):
		var z := z_front + i * STAND_ROW_DEPTH
		var y := i * STAND_ROW_RISE
		# Each terrace step: a tread you can imagine people sitting on.
		_slab("Row%d" % i, Vector3(STAND_LENGTH, STAND_ROW_RISE, STAND_ROW_DEPTH),
			Vector3(0, y + STAND_ROW_RISE * 0.5, z), CONCRETE_MAT, stand)
	# Back wall behind the top row.
	var back_z := z_front + STAND_ROWS * STAND_ROW_DEPTH
	var top_y := STAND_ROWS * STAND_ROW_RISE
	_slab("BackWall", Vector3(STAND_LENGTH + 1.0, top_y + 1.5, 0.4),
		Vector3(0, (top_y + 1.5) * 0.5, back_z), CONCRETE_MAT, stand)
	# Side walls (triangular profile approximated by a thin sloped-top block).
	for side in [-1.0, 1.0]:
		var sign := float(side)
		_slab("SideWall", Vector3(0.4, top_y, STAND_ROWS * STAND_ROW_DEPTH),
			Vector3(sign * STAND_LENGTH * 0.5, top_y * 0.5, z_front + STAND_ROWS * STAND_ROW_DEPTH * 0.5),
			CONCRETE_MAT, stand)


## A box mesh with a material. Uses StaticBody so it's walkable once integrated.
func _slab(node_name: String, size: Vector3, position: Vector3, material: Material, parent: Node = null) -> void:
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

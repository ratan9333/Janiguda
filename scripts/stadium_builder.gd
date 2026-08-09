extends Node3D

## HAL Stadium ground (Sunabeda), laid out to match the team's annotated
## satellite reference:
##   - Football ground (dirt) in the centre
##   - Open L-shaped gallery on two adjacent sides (west + south-west), no roof
##   - Basketball court at the SW corner, by the gallery/entrance
##   - Old hockey ground to the NE, separate
##   - Main entrance (SW), closed gate (W), back gate (E)
##   - Floodlight poles, boundary wall, surrounding ground
##
## Axes: +X = east, +Z = south (so -Z = north, -X = west).
## Built at the scene origin; moves to the real footprint when integrated.

const FIELD_MAT := preload("res://materials/field_dirt.tres")
const LINE_MAT := preload("res://materials/pitch_lines.tres")
const CONCRETE_MAT := preload("res://materials/stand_concrete.tres")
const POLE_MAT := preload("res://materials/pole_metal.tres")
const COURT_MAT := preload("res://materials/court_surface.tres")
const GROUND_MAT := preload("res://materials/ground_base.tres")

# Football field (metres). Long axis along Z.
const FIELD_HALF_X := 37.5   # 75 m wide
const FIELD_HALF_Z := 54.0   # 108 m long
const BOUND_HALF_X := 41.5   # 83 m boundary
const BOUND_HALF_Z := 61.0   # 122 m boundary
const LINE_W := 0.12
const LINE_Y := 0.06

# Open gallery terracing.
const GALLERY_ROWS := 12
const ROW_DEPTH := 0.75
const ROW_RISE := 0.38
const GALLERY_GAP := 2.5     # boundary to first row


func _ready() -> void:
	build_ground_base()
	build_football_field()
	build_markings()
	build_goals()
	build_open_gallery()
	build_basketball_court()
	build_hockey_ground()
	build_floodlights()
	build_boundary_with_gates()


func build_ground_base() -> void:
	_slab("GroundBase", Vector3(400, 0.4, 400), Vector3(0, -0.35, 0), GROUND_MAT)


func build_football_field() -> void:
	_slab("FootballField", Vector3(BOUND_HALF_X * 2, 0.2, BOUND_HALF_Z * 2), Vector3(0, -0.1, 0), FIELD_MAT)


func build_markings() -> void:
	var hx := FIELD_HALF_X
	var hz := FIELD_HALF_Z
	_line(Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz))
	_line(Vector3(-hx, 0, hz), Vector3(hx, 0, hz))
	_line(Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz))
	_line(Vector3(hx, 0, -hz), Vector3(hx, 0, hz))
	_line(Vector3(-hx, 0, 0), Vector3(hx, 0, 0))
	_circle(Vector3.ZERO, 9.15, 48)
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z_line := sign * (hz - 16.5)
		var pw := 20.15
		_line(Vector3(-pw, 0, z_line), Vector3(pw, 0, z_line))
		_line(Vector3(-pw, 0, sign * hz), Vector3(-pw, 0, z_line))
		_line(Vector3(pw, 0, sign * hz), Vector3(pw, 0, z_line))


func build_goals() -> void:
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * FIELD_HALF_Z
		_slab("GoalPostL", Vector3(0.12, 2.44, 0.12), Vector3(-3.66, 1.22, z), LINE_MAT)
		_slab("GoalPostR", Vector3(0.12, 2.44, 0.12), Vector3(3.66, 1.22, z), LINE_MAT)
		_slab("GoalBar", Vector3(7.32, 0.12, 0.12), Vector3(0, 2.44, z), LINE_MAT)


## Open concrete terracing on two adjacent sides forming an L at the SW corner:
## a west arm (runs along Z) and a south arm (runs along X). No roof.
func build_open_gallery() -> void:
	var gallery := Node3D.new()
	gallery.name = "OpenGallery"
	add_child(gallery)

	# West arm: rises toward -X, runs most of the field length.
	var west_front := -(BOUND_HALF_X + GALLERY_GAP)
	var west_len := BOUND_HALF_Z * 1.8
	for i in range(GALLERY_ROWS):
		var x := west_front - i * ROW_DEPTH
		var y := i * ROW_RISE
		_slab("WestRow%d" % i, Vector3(ROW_DEPTH, ROW_RISE, west_len),
			Vector3(x, y + ROW_RISE * 0.5, 0), CONCRETE_MAT, gallery)

	# South arm: rises toward +Z, runs the field width, meeting the west arm.
	var south_front := BOUND_HALF_Z + GALLERY_GAP
	var south_len := BOUND_HALF_X * 1.8
	for i in range(GALLERY_ROWS):
		var z := south_front + i * ROW_DEPTH
		var y := i * ROW_RISE
		_slab("SouthRow%d" % i, Vector3(south_len, ROW_RISE, ROW_DEPTH),
			Vector3(0, y + ROW_RISE * 0.5, z), CONCRETE_MAT, gallery)


## Basketball court (15 x 30 m) at the SW corner, by the gallery and entrance.
func build_basketball_court() -> void:
	var court := Node3D.new()
	court.name = "BasketballCourt"
	var origin := Vector3(-(BOUND_HALF_X + 14.0), 0, BOUND_HALF_Z - 6.0)
	court.position = origin
	add_child(court)
	# 30 long (z) x 15 wide (x).
	_slab("CourtSurface", Vector3(15.0, 0.15, 30.0), Vector3(0, 0.02, 0), COURT_MAT, court)
	_court_line(court, Vector3(-7.5, 0, -15), Vector3(7.5, 0, -15))
	_court_line(court, Vector3(-7.5, 0, 15), Vector3(7.5, 0, 15))
	_court_line(court, Vector3(-7.5, 0, -15), Vector3(-7.5, 0, 15))
	_court_line(court, Vector3(7.5, 0, -15), Vector3(7.5, 0, 15))
	_court_line(court, Vector3(-7.5, 0, 0), Vector3(7.5, 0, 0))
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * 14.0
		_slab("HoopPole", Vector3(0.2, 3.05, 0.2), origin + Vector3(0, 1.52, z), POLE_MAT, court)
		_slab("Backboard", Vector3(1.8, 1.05, 0.1), origin + Vector3(0, 3.05, z - sign * 0.3), POLE_MAT, court)


## Old hockey ground (~91 x 55 m) to the NE (+X, -Z), separate from the football
## ground with a gap between them.
func build_hockey_ground() -> void:
	var hockey := Node3D.new()
	hockey.name = "OldHockeyGround"
	var origin := Vector3(28.0, 0, -(BOUND_HALF_Z + 52.0))
	hockey.position = origin
	add_child(hockey)
	var hx := 45.5
	var hz := 27.5
	_slab("HockeyField", Vector3(hx * 2, 0.16, hz * 2), Vector3(0, -0.08, 0), FIELD_MAT, hockey)
	# Simple boundary markings.
	_hockey_line(hockey, Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz))
	_hockey_line(hockey, Vector3(-hx, 0, hz), Vector3(hx, 0, hz))
	_hockey_line(hockey, Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz))
	_hockey_line(hockey, Vector3(hx, 0, -hz), Vector3(hx, 0, hz))
	_hockey_line(hockey, Vector3(0, 0, -hz), Vector3(0, 0, hz))


func build_floodlights() -> void:
	var poles := Node3D.new()
	poles.name = "Floodlights"
	add_child(poles)
	var px := BOUND_HALF_X + 6.0
	var pz := BOUND_HALF_Z - 8.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(float(sx) * px, 0, float(sz) * pz)
			_slab("Pole", Vector3(0.5, 18.0, 0.5), base + Vector3(0, 9.0, 0), POLE_MAT, poles)
			var housing := _slab("Lights", Vector3(3.0, 1.4, 0.6),
				base + Vector3(-float(sx) * 1.2, 17.5, 0), POLE_MAT, poles)
			housing.rotation.z = deg_to_rad(float(sx) * 20.0)


## Boundary wall on the 122 x 83 m line, with gaps for the three gates:
## main entrance (south wall, west end), closed gate (west wall), back gate (east).
func build_boundary_with_gates() -> void:
	var wall := Node3D.new()
	wall.name = "BoundaryWall"
	add_child(wall)
	var wx := BOUND_HALF_X
	var wz := BOUND_HALF_Z
	var h := 1.4

	# North wall (solid).
	_wall_x(wall, -wz, -wx, wx, h)
	# South wall with main-entrance gap near the west end.
	_wall_x(wall, wz, -wx, -18.0, h)
	_gate_posts(wall, Vector3(-18.0, 0, wz), Vector3(-10.0, 0, wz), h, "MainEntrance")
	_wall_x(wall, wz, -10.0, wx, h)
	# West wall with a closed gate in the middle (gap + a closed panel).
	_wall_z(wall, -wx, -wz, -6.0, h)
	_slab("ClosedGate", Vector3(0.5, h, 12.0), Vector3(-wx, h * 0.5, 0), CONCRETE_MAT, wall)
	_wall_z(wall, -wx, 6.0, wz, h)
	# East wall with back-gate gap in the middle.
	_wall_z(wall, wx, -wz, -6.0, h)
	_gate_posts(wall, Vector3(wx, 0, -6.0), Vector3(wx, 0, 6.0), h, "BackGate")
	_wall_z(wall, wx, 6.0, wz, h)


# --- helpers ---

func _wall_x(parent: Node, z: float, x0: float, x1: float, h: float) -> void:
	var length := absf(x1 - x0)
	if length < 0.1:
		return
	_slab("Wall", Vector3(length, h, 0.3), Vector3((x0 + x1) * 0.5, h * 0.5, z), CONCRETE_MAT, parent)


func _wall_z(parent: Node, x: float, z0: float, z1: float, h: float) -> void:
	var length := absf(z1 - z0)
	if length < 0.1:
		return
	_slab("Wall", Vector3(0.3, h, length), Vector3(x, h * 0.5, (z0 + z1) * 0.5), CONCRETE_MAT, parent)


func _gate_posts(parent: Node, a: Vector3, b: Vector3, h: float, node_name: String) -> void:
	for p in [a, b]:
		_slab(node_name + "Post", Vector3(0.6, h + 0.8, 0.6), p + Vector3(0, (h + 0.8) * 0.5, 0), POLE_MAT, parent)


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
	_thin_line(self, a, b, LINE_W, LINE_Y)


func _court_line(parent: Node, a: Vector3, b: Vector3) -> void:
	_thin_line(parent, a, b, 0.08, 0.11)


func _hockey_line(parent: Node, a: Vector3, b: Vector3) -> void:
	_thin_line(parent, a, b, 0.1, 0.1)


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


func _circle(centre: Vector3, radius: float, segments: int) -> void:
	var previous := centre + Vector3(radius, 0, 0)
	for i in range(1, segments + 1):
		var angle := TAU * i / segments
		var point := centre + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		_line(previous, point)
		previous = point

@tool
extends Node3D

## HAL ground, Sunabeda. A @tool script: everything renders in the EDITOR.
##
## The dirt ground outline and roads are REAL (OpenStreetMap). The football
## field, gallery, basketball court and hockey ground are each parented to a
## draggable ANCHOR node (FieldAnchor, GalleryAnchor, CourtAnchor, HockeyAnchor).
##
## To place a piece: click its anchor in the Scene panel, press W (move) or
## E (rotate), and drag it in the viewport. The geometry moves with the anchor -
## no numbers, no running. Each piece is independent (gallery is NOT attached to
## the field).
##
## Axes: +X = east, +Z = south. 1 unit = 1 metre.

## Curved-gallery shape controls. Drag these in the Inspector to experiment:
## bigger radius = gentler curve; bigger arc = wraps further around.
@export_group("Curved gallery shape")
@export_range(20, 200) var gallery_curve_radius: float = 70.0:
	set(v): gallery_curve_radius = v; _request_rebuild()
@export_range(5, 120) var gallery_curve_arc_deg: float = 40.0:
	set(v): gallery_curve_arc_deg = v; _request_rebuild()

## Sizes in metres. Drag these instead of scaling the nodes - this keeps the
## real-world scale correct (1 unit = 1 metre).
@export_group("Sizes (metres)")
@export_range(30, 130) var field_width_m: float = 75.0:
	set(v): field_width_m = v; _request_rebuild()
@export_range(40, 130) var field_length_m: float = 108.0:
	set(v): field_length_m = v; _request_rebuild()
@export_range(10, 160) var gallery_length_m: float = 90.0:
	set(v): gallery_length_m = v; _request_rebuild()
@export_range(1, 40) var gallery_rows: int = 15:
	set(v): gallery_rows = v; _request_rebuild()

const FIELD_MAT := preload("res://materials/field_dirt.tres")
const LINE_MAT := preload("res://materials/pitch_lines.tres")
const CONCRETE_MAT := preload("res://materials/stand_concrete.tres")
const POLE_MAT := preload("res://materials/pole_metal.tres")
const COURT_MAT := preload("res://materials/court_surface.tres")
const GROUND_MAT := preload("res://materials/ground_base.tres")
const GRASS_MAT := preload("res://materials/grass_green.tres")
const ROAD_MAT := preload("res://materials/road_surface.tres")
const GATE_MAT := preload("res://materials/gate_metal.tres")

## The compound (all your placed pieces) stays at ground level y=0. The outside
## world - surrounding ground and roads - sits this far BELOW, so the stadium
## reads as elevated. A sloped embankment and entrance stairs connect the two.
const OUTER_LEVEL := -4.0

const LINE_W := 0.12
const LINE_Y := 0.06

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
	# Fixed, real geometry under a throwaway node.
	var existing := get_node_or_null("Generated")
	if existing:
		existing.free()
	_root = Node3D.new()
	_root.name = "Generated"
	add_child(_root)
	build_ground_base()
	build_real_roads()
	build_real_compound()
	build_embankment()
	build_boundary_wall()
	build_boundary_trees()

	# Placeable geometry parented under the draggable anchors.
	_populate("FieldAnchor", _build_field)
	_populate("GalleryStraightAnchor", _build_gallery_straight)
	_populate("GalleryCurvedAnchor", _build_gallery_curved)
	_populate("CourtAnchor", _build_court)
	_populate("HockeyAnchor", _build_hockey)
	_populate("MarketAnchor", _build_market)
	_populate("MarketCurvedAnchor", _build_market)
	_populate("StairsAnchor", _build_stairs)
	_populate("GateAnchor", _build_gate)
	_populate("RoadPlazaAnchor", _build_road_plaza)
	_populate("ComplexRoadAnchor", _build_complex_road)


## Clear an anchor's old geometry and rebuild it there. Geometry is a child of
## the anchor, so dragging the anchor later moves it with no rebuild needed.
func _populate(anchor_name: String, builder: Callable) -> void:
	var anchor := get_node_or_null(anchor_name)
	if anchor == null:
		return
	for child in anchor.get_children():
		child.free()
	builder.call(anchor)


# --- real, fixed ---

func build_ground_base() -> void:
	# The outer world floor, dropped below the compound so the stadium is raised.
	_slab("GroundBase", Vector3(2600, 0.4, 2600), Vector3(0, OUTER_LEVEL - 0.2, 0), GROUND_MAT)


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
		# Broaden roads that pass close to the stadium so the approach is wide.
		var nearest := INF
		for p in points:
			nearest = minf(nearest, Vector2(p.x, p.z).length())
		if nearest < 70.0:
			width = maxf(width * 1.8, 14.0)
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
	# The compound is the playable floor at y=0, so it needs collision to stand on.
	var body := StaticBody3D.new()
	body.name = "GroundFill"
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	body.add_child(instance)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	shape.backface_collision = true
	collider.shape = shape
	body.add_child(collider)
	ground.add_child(body)


## The sloped earth bank around the compound, from the ground edge (y~0) down to
## the lower outer world. This is what makes the stadium sit on raised ground.
func build_embankment() -> void:
	var pts := _compound_points()
	if pts.size() < 3:
		return
	var group := _group("Embankment")
	var run := 8.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		var a := pts[i]; a.y = 0.02
		var b := pts[i + 1]; b.y = 0.02
		var oa := a + Vector3(a.x, 0, a.z).normalized() * run; oa.y = OUTER_LEVEL
		var ob := b + Vector3(b.x, 0, b.z).normalized() * run; ob.y = OUTER_LEVEL
		for tri in [[a, b, ob], [a, ob, oa], [a, ob, b], [a, oa, ob]]:  # double-sided
			for p in tri:
				surface.set_uv(Vector2(p.x * 0.06, p.z * 0.06))
				surface.add_vertex(p)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, GROUND_MAT)
	var body := StaticBody3D.new()
	body.name = "EmbankmentBody"
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	body.add_child(instance)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	shape.backface_collision = true
	collider.shape = shape
	body.add_child(collider)
	group.add_child(body)


## Old-style cemented compound wall following the real brown outline: ~3 m
## panels, each with a small triangular coping on top, joined all the way round.
## Gaps are left for the three gates (main entrance SW, closed gate W, back E).
func build_boundary_wall() -> void:
	var pts := _compound_points()
	if pts.size() < 2:
		return
	var wall := _group("CementBoundary")
	var panel_w := 3.0
	var wall_h := 2.2
	var thick := 0.3
	# Zones (compass angle from centre, half-width in degrees) where NO wall is
	# built: the three gates, plus wherever a market complex sits (the market
	# replaces the wall there). E = 0, S = 90, W = 180, N = -90, SW = 135.
	var skip := [[135.0, 8.0], [180.0, 8.0], [0.0, 8.0]]
	for market_name in ["MarketAnchor", "MarketCurvedAnchor"]:
		var m := get_node_or_null(market_name)
		if m and m is Node3D:
			skip.append([rad_to_deg(atan2(m.position.z, m.position.x)), 14.0])
	for i in range(pts.size() - 1):
		var a := pts[i]; a.y = 0.0
		var b := pts[i + 1]; b.y = 0.0
		var edge := b - a
		var length := edge.length()
		if length < 0.1:
			continue
		var dir := edge.normalized()
		var count := maxi(1, int(round(length / panel_w)))
		var step := length / count
		for j in range(count):
			var centre := a + dir * (step * (j + 0.5))
			var ang := rad_to_deg(atan2(centre.z, centre.x))
			var skip_here := false
			for zone in skip:
				if absf(_angle_diff(ang, zone[0])) < zone[1]:
					skip_here = true
					break
			if skip_here:
				continue
			_wall_panel(wall, centre, dir, step * 0.98, wall_h, thick)


func _wall_panel(parent: Node, centre: Vector3, dir: Vector3, width: float, height: float, thick: float) -> void:
	var yaw := -atan2(dir.z, dir.x)
	var panel := _slab("Panel", Vector3(width, height, thick), centre + Vector3(0, height * 0.5, 0), CONCRETE_MAT, parent)
	panel.rotation.y = yaw
	# Small triangular coping (PrismMesh) capping the panel.
	var cap := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(width, 0.35, thick)
	prism.material = CONCRETE_MAT
	cap.mesh = prism
	cap.position = centre + Vector3(0, height + 0.175, 0)
	cap.rotation.y = yaw
	parent.add_child(cap)


func _angle_diff(a: float, b: float) -> float:
	var d := a - b
	while d > 180.0:
		d -= 360.0
	while d < -180.0:
		d += 360.0
	return d


func build_boundary_trees() -> void:
	var pts := _compound_points()
	if pts.size() < 3:
		return
	var trees := _group("BoundaryTrees")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Keep the entrance clear of trees (around the gate) - you'll plant the
	# south side yourself.
	var clear_angle := 1000.0
	var gate := get_node_or_null("GateAnchor")
	if gate and gate is Node3D:
		clear_angle = rad_to_deg(atan2(gate.position.z, gate.position.x))
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var n := maxi(1, int(seg / 9.0))
		for j in range(n):
			var p := a.lerp(b, float(j) / n)
			if clear_angle < 900.0 and absf(_angle_diff(rad_to_deg(atan2(p.z, p.x)), clear_angle)) < 24.0:
				continue
			var outward := Vector3(p.x, 0, p.z).normalized() * 5.0
			p += outward + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			_eucalyptus(trees, Vector3(p.x, 0, p.z), rng.randf_range(10.0, 16.0))


# --- placeable pieces (built under their anchor, local coords) ---

func _build_field(anchor: Node) -> void:
	var hx := field_width_m * 0.5
	var hz := field_length_m * 0.5
	_line(anchor, Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz))
	_line(anchor, Vector3(-hx, 0, hz), Vector3(hx, 0, hz))
	_line(anchor, Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz))
	_line(anchor, Vector3(hx, 0, -hz), Vector3(hx, 0, hz))
	_line(anchor, Vector3(-hx, 0, 0), Vector3(hx, 0, 0))
	_circle(anchor, 9.15, 48)
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * hz
		_slab("GoalPostL", Vector3(0.12, 2.44, 0.12), Vector3(-3.66, 1.22, z), LINE_MAT, anchor)
		_slab("GoalPostR", Vector3(0.12, 2.44, 0.12), Vector3(3.66, 1.22, z), LINE_MAT, anchor)
		_slab("GoalBar", Vector3(7.32, 0.12, 0.12), Vector3(0, 2.44, z), LINE_MAT, anchor)
	# Floodlight poles at the field corners.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(float(sx) * (hx + 8.0), 0, float(sz) * (hz + 4.0))
			_slab("Pole", Vector3(0.35, 15.0, 0.35), base + Vector3(0, 7.5, 0), POLE_MAT, anchor)
			_slab("Lights", Vector3(2.2, 0.9, 0.5), base + Vector3(0, 15.0, 0), POLE_MAT, anchor)


## Cemented entrance stairs, from the compound edge (y=0) down to the lower
## outer world, descending along +Z. ~15 steps, old cement look.
func _build_stairs(anchor: Node) -> void:
	var drop := -OUTER_LEVEL           # total drop to the road level
	var steps := maxi(12, int(drop / 0.18))
	var rise := drop / steps
	var run := 0.35
	var width := 7.0
	for i in range(steps):
		var top := -i * rise
		# Solid block from this step's top down to the bottom, so no gaps.
		var h := top - OUTER_LEVEL
		_slab("Step%d" % i, Vector3(width, h, run),
			Vector3(0, (top + OUTER_LEVEL) * 0.5, i * run), CONCRETE_MAT, anchor)
	# Low side walls flanking the flight.
	for sx in [-1.0, 1.0]:
		_slab("StairWall", Vector3(0.4, drop + 0.6, steps * run),
			Vector3(float(sx) * (width * 0.5 + 0.2), OUTER_LEVEL * 0.5, steps * run * 0.5 - run * 0.5), CONCRETE_MAT, anchor)


## A broad road / plaza at the LOWER outer level (the road level below the
## stadium). Place it over the road area at the base of the stairs. It builds at
## the outer level regardless of the anchor's own height.
func _build_road_plaza(anchor: Node) -> void:
	_slab("Plaza", Vector3(60.0, 0.2, 40.0), Vector3(0, OUTER_LEVEL + 0.1, 0), ROAD_MAT, anchor)


## The ELEVATED road serving the stadium complex, on top of the raised ground
## (y=0). Runs along local X. Drag/rotate it along the complex.
func _build_complex_road(anchor: Node) -> void:
	_slab("ComplexRoad", Vector3(70.0, 0.16, 9.0), Vector3(0, 0.12, 0), ROAD_MAT, anchor)


## Dark-green metal gate: two posts, a top bar, and two gate leaves.
func _build_gate(anchor: Node) -> void:
	_slab("PostL", Vector3(0.45, 3.2, 0.45), Vector3(-2.6, 1.6, 0), CONCRETE_MAT, anchor)
	_slab("PostR", Vector3(0.45, 3.2, 0.45), Vector3(2.6, 1.6, 0), CONCRETE_MAT, anchor)
	_slab("TopBar", Vector3(5.65, 0.35, 0.3), Vector3(0, 3.0, 0), GATE_MAT, anchor)
	_slab("LeafL", Vector3(2.3, 2.3, 0.12), Vector3(-1.2, 1.25, 0), GATE_MAT, anchor)
	_slab("LeafR", Vector3(2.3, 2.3, 0.12), Vector3(1.2, 1.25, 0), GATE_MAT, anchor)


## A STRAIGHT stand: terrace rows are boxes in a line. Each higher row steps
## back (+Z) and up (+Y). This is the simplest kind of stand.
func _build_gallery_straight(anchor: Node) -> void:
	var rows := gallery_rows
	var depth := 0.8            # how deep each step is (m)
	var rise := 0.36           # how tall each step is (m)
	var length := gallery_length_m   # how long the stand runs, in metres
	for i in range(rows):
		# Each step is a SOLID block from the ground up to its height, so there
		# is no hollow void beneath the terracing - as it really is.
		var h := (i + 1) * rise
		_slab("Row%d" % i, Vector3(length, h, depth),
			Vector3(0, h * 0.5, i * depth), CONCRETE_MAT, anchor)


## A CURVED stand: same idea, but instead of a straight line, each row is a ring
## of short boxes placed along an ARC. We step an ANGLE across the arc and rotate
## each box to follow the curve. Bigger radius = gentler curve.
func _build_gallery_curved(anchor: Node) -> void:
	var rows := gallery_rows
	var depth := 0.8
	var rise := 0.36
	var radius := gallery_curve_radius
	var arc := deg_to_rad(gallery_curve_arc_deg)
	var segments := 26
	for r in range(rows):
		var ring_radius := radius + r * depth
		var h := (r + 1) * rise   # solid down to the ground, no void
		for s in range(segments):
			var t := float(s) / (segments - 1)
			var angle := -arc * 0.5 + arc * t
			# Point on the arc, shifted so the front-centre sits at the anchor.
			var pos := Vector3(sin(angle) * ring_radius, h * 0.5, cos(angle) * ring_radius - radius)
			var seg_width := ring_radius * (arc / segments) * 1.2
			var box := _slab("Curve_%d_%d" % [r, s], Vector3(seg_width, h, depth), pos, CONCRETE_MAT, anchor)
			box.rotation.y = -angle  # turn each box to follow the curve


func _build_court(anchor: Node) -> void:
	_slab("CourtSurface", Vector3(15.0, 0.15, 30.0), Vector3(0, 0.02, 0), COURT_MAT, anchor)
	_court_line(anchor, Vector3(-7.5, 0, -15), Vector3(7.5, 0, -15))
	_court_line(anchor, Vector3(-7.5, 0, 15), Vector3(7.5, 0, 15))
	_court_line(anchor, Vector3(-7.5, 0, -15), Vector3(-7.5, 0, 15))
	_court_line(anchor, Vector3(7.5, 0, -15), Vector3(7.5, 0, 15))
	_court_line(anchor, Vector3(-7.5, 0, 0), Vector3(7.5, 0, 0))
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * 14.0
		_slab("HoopPole", Vector3(0.2, 3.05, 0.2), Vector3(0, 1.52, z), POLE_MAT, anchor)
		_slab("Backboard", Vector3(1.8, 1.05, 0.1), Vector3(0, 3.05, z - sign * 0.3), POLE_MAT, anchor)


## A small old-style market complex: a row of shop units, in line, matching the
## length of the straight gallery. Sits behind the gallery (its own anchor -
## drag it into place). Local +Z faces the shop fronts.
func _build_market(anchor: Node) -> void:
	var total_length := gallery_length_m
	var units := maxi(4, int(total_length / 5.5))
	var unit_w := total_length / units
	# A continuous back wall / roof slab tying the shops together.
	_slab("MarketRoof", Vector3(total_length, 0.3, 5.4), Vector3(0, 3.3, 0.2), CONCRETE_MAT, anchor)
	for i in range(units):
		var x := -total_length * 0.5 + unit_w * (i + 0.5)
		# Shop box.
		_slab("Shop%d" % i, Vector3(unit_w * 0.94, 3.2, 5.0), Vector3(x, 1.6, 0), CONCRETE_MAT, anchor)
		# Coloured shutter/awning on the front, alternating so the row reads as
		# separate shops.
		var awning := StandardMaterial3D.new()
		awning.albedo_color = [Color("9c4b3b"), Color("3f6f7a"), Color("caa63f"), Color("6a7b52")][i % 4]
		awning.roughness = 0.9
		# Shopfronts face +Z (the outer-road side), away from the stadium.
		var front := _slab("Front%d" % i, Vector3(unit_w * 0.94, 1.4, 0.2), Vector3(x, 1.1, 2.6), CONCRETE_MAT, anchor)
		front.get_child(0).material_override = awning
		# Little awning ledge above the shopfront.
		_slab("Ledge%d" % i, Vector3(unit_w * 0.94, 0.18, 1.1), Vector3(x, 2.5, 3.0), CONCRETE_MAT, anchor)


func _build_hockey(anchor: Node) -> void:
	var hx := 45.5
	var hz := 27.5
	_slab("HockeyField", Vector3(hx * 2, 0.16, hz * 2), Vector3(0, -0.08, 0), GRASS_MAT, anchor)
	for pair in [[Vector3(-hx,0,-hz), Vector3(hx,0,-hz)], [Vector3(-hx,0,hz), Vector3(hx,0,hz)],
			[Vector3(-hx,0,-hz), Vector3(-hx,0,hz)], [Vector3(hx,0,-hz), Vector3(hx,0,hz)],
			[Vector3(0,0,-hz), Vector3(0,0,hz)]]:
		_thin_line(anchor, pair[0], pair[1], 0.1, 0.1)


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
	# Roads sit on the lower outer world (the compound above is reached by stairs).
	var meters_per_lon := 111320.0 * cos(deg_to_rad(OSM_CENTER_LAT))
	return Vector3((longitude - OSM_CENTER_LON) * meters_per_lon, OUTER_LEVEL + 0.06, -(latitude - OSM_CENTER_LAT) * 110540.0)


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

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

## Tick to make the generated geometry selectable and movable like ordinary
## nodes. It then appears in the Scene panel and saves with the scene. This is a
## deliberate mode switch: while it is on NOTHING regenerates, so every slider
## below stops having any effect and your edits are safe. Untick to throw the
## baked nodes away and go back to generating from the script.
##
## Deliberately declared before the first @export_group, so it stays at the TOP
## of the Inspector rather than being buried inside a foldout.
##
## Ticking alone is not enough: SAVE the scene (Cmd/Ctrl+S) and reload it. Only
## after that round trip do the pieces become ordinary saved nodes that the
## editor will let you click and drag.
@export var bake_for_editing: bool = false:
	set(v):
		bake_for_editing = v
		if v:
			_bake()
		else:
			_request_rebuild()

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
## Goal frame size as a multiple of regulation (7.32 x 2.44 m). 1.0 is a real
## football goal; the pitch here is oversized, so a larger frame reads better.
@export_range(1.0, 4.0) var goal_scale: float = 1.6:
	set(v): goal_scale = v; _request_rebuild()
## Basketball hoop size as a multiple of regulation (0.45 m ring at 3.05 m).
## Scales the ring, backboard and pole together - note this raises the ring too.
@export_range(1.0, 4.0) var hoop_scale: float = 1.6:
	set(v): hoop_scale = v; _request_rebuild()

## A rectangular bite taken out of the raised compound, positioned by dragging
## CutAnchor in the viewport (rotate it too - the rectangle follows its yaw).
## The earth inside is removed completely, down to the outer world level, and the
## retaining wall, boundary wall and trees all follow the new edge.
@export_group("Ground cut")
@export var enable_ground_cut: bool = true:
	set(v): enable_ground_cut = v; _request_rebuild()
@export_range(2.0, 120.0) var ground_cut_width_m: float = 30.0:
	set(v): ground_cut_width_m = v; _request_rebuild()
@export_range(2.0, 120.0) var ground_cut_depth_m: float = 26.0:
	set(v): ground_cut_depth_m = v; _request_rebuild()

const FIELD_MAT := preload("res://materials/field_dirt.tres")
const LINE_MAT := preload("res://materials/pitch_lines.tres")
const CONCRETE_MAT := preload("res://materials/stand_concrete.tres")
const POLE_MAT := preload("res://materials/pole_metal.tres")
const COURT_MAT := preload("res://materials/court_surface.tres")
const GROUND_MAT := preload("res://materials/ground_base.tres")
const GRASS_MAT := preload("res://materials/grass_green.tres")
const ROAD_MAT := preload("res://materials/road_surface.tres")
const GATE_MAT := preload("res://materials/gate_metal.tres")
const PITCH_MAT := preload("res://materials/soccer_pitch.tres")
const BBALL_MAT := preload("res://materials/basketball_court.tres")

## Imported ground models to skin, node name -> material. Applied from here
## rather than as a material_override saved in the scene, because the editor
## rewrites the whole .tscn on save and drops overrides on instanced children.
const GROUND_SKINS := {
	"SoccerField": PITCH_MAT,
	"BasketballGround": BBALL_MAT,
}

## Elevation controls, live in the Inspector. The compound (all your placed
## pieces) stays at y=0; the outer world sits elevation_m BELOW it. embankment_run
## is how far the connecting slope spreads outward.
@export_group("Elevation (metres)")
@export_range(0.0, 10.0) var elevation_m: float = 4.0:
	set(v):
		elevation_m = v
		_request_rebuild()

# Derived each rebuild from elevation_m (the outer world's Y level).
var OUTER_LEVEL := -4.0

const LINE_W := 0.12
const LINE_Y := 0.06

const OSM_CENTER_LAT := 18.7244769
const OSM_CENTER_LON := 82.82651795
const STADIUM_WAY_ID := 231036048

var _root: Node3D


func _ready() -> void:
	# Skinning runs either way: the ground models are instanced scenes, so baking
	# does not claim them and they would otherwise stay untextured.
	_skin_grounds()
	# Deferred, and from the scene root, so it settles after every child has had
	# its say - see _claim_viewport().
	_claim_viewport.call_deferred()
	if bake_for_editing:
		return          # keep the baked nodes that were saved with the scene
	_rebuild()


## Put the pitch / court shaders on the imported ground models, sizing each one
## from what it actually measures in the world. Doing it here means rescaling or
## rotating the node keeps the markings correct, and an editor save can no
## longer lose the assignment.
func _skin_grounds() -> void:
	for node_name in GROUND_SKINS:
		var node := get_node_or_null(NodePath(node_name)) as Node3D
		if node == null:
			continue
		for mesh in _mesh_children(node):
			if mesh.mesh == null:
				continue
			var material: ShaderMaterial = GROUND_SKINS[node_name].duplicate()
			var size := mesh.mesh.get_aabb().size
			var basis := mesh.global_transform.basis
			material.set_shader_parameter("plane_size_m", Vector2(
				(basis * Vector3(size.x, 0, 0)).length(),
				(basis * Vector3(0, 0, size.z)).length()))
			mesh.material_override = material


## Hand the viewport to the real Player and stand down any stowaway ones.
##
## Scenes instanced alongside this one - Playground, CharacterTest - each ship a
## complete Player: a Camera3D flagged `current`, plus a controller reading the
## same WASD actions. Setting `visible = false` on them is not enough, because a
## hidden Camera3D still claims the viewport on entering the tree and a hidden
## controller still runs. The symptom is a world that renders while the view sits
## parked on a character you cannot see, and phantom input going to it.
##
## Whichever camera enters last would otherwise win, so this runs deferred from
## the scene root: _ready() fires bottom-up, meaning the root queues after every
## child, and the deferred queue is FIFO.
func _claim_viewport() -> void:
	var player := get_node_or_null("Player") as Node3D
	if player == null:
		return
	for child in get_children():
		if child == player or not (child is Node3D):
			continue
		# A sibling carrying a camera rig is a stowaway player, not scenery.
		if child.find_child("CameraPivot", true, false) != null:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := player.find_child("Camera3D", true, false) as Camera3D
	if camera:
		camera.make_current()


func _mesh_children(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_mesh_children(child))
	return found


func _request_rebuild() -> void:
	if bake_for_editing:
		return          # baked: regenerating here would wipe hand edits
	if is_inside_tree():
		_skin_grounds()
		_rebuild()


## Hand the generated geometry an owner. Nodes a @tool script creates have no
## owner, which is why they never show up in the Scene panel and cannot be
## clicked in the viewport - only the anchors can. Claiming them makes every
## piece a normal, selectable, movable scene node.
##
## Rebuilding is switched off while baked, because _rebuild() frees the lot and
## regenerates it: without this, moving a wall and then touching any Inspector
## slider would silently throw the edit away.
func _bake() -> void:
	var scene_root: Node = owner if owner != null else self
	_claim(self, scene_root)


func _claim(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		# Never reach inside an instanced scene (Player, Football): claiming its
		# internals would flatten the instance into this scene on save.
		if not child.scene_file_path.is_empty():
			continue
		if child.owner == null and child != scene_root:
			child.owner = scene_root      # parent first: owner must be an ancestor
		_claim(child, scene_root)


func _rebuild() -> void:
	OUTER_LEVEL = -elevation_m
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
	build_retaining_wall()
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
	_populate("StairsAnchor2", _build_stairs)
	_populate("GateAnchor", _build_gate)
	_populate("RoadPlazaAnchor", _build_road_plaza)
	_populate("ComplexRoadAnchor", _build_complex_road)
	_populate("SportsComplexAnchor", _build_sports_complex)
	_populate("ToiletAnchor", _build_toilet)
	_populate("WelcomeArchAnchor", _build_welcome_arch)
	_populate("RoundaboutAnchor", _build_roundabout)


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
	# The outer world floor (green grass), dropped below the raised compound.
	_slab("GroundBase", Vector3(2600, 0.4, 2600), Vector3(0, OUTER_LEVEL - 0.2, 0), GRASS_MAT)


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
	# Proper ear-clipping rather than a fan from pts[0]: once CutAnchor carves a
	# notch the outline is concave, and a fan would fill the notch back in.
	var flat := PackedVector2Array()
	for i in range(pts.size() - 1):        # drop the repeated closing point
		flat.append(Vector2(pts[i].x, pts[i].z))
	var indices := Geometry2D.triangulate_polygon(flat)
	if indices.is_empty():
		return
	for i in range(0, indices.size(), 3):
		var a := Vector3(flat[indices[i]].x, 0.04, flat[indices[i]].y)
		var b := Vector3(flat[indices[i + 1]].x, 0.04, flat[indices[i + 1]].y)
		var c := Vector3(flat[indices[i + 2]].x, 0.04, flat[indices[i + 2]].y)
		for tri in [[a, b, c], [a, c, b]]:
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


## Vertical cement retaining wall around the compound edge, holding back the
## raised earth: it drops straight down from the ground (y=0) to the lower outer
## world. A gap is left at the gate, where the stairs come down.
func build_retaining_wall() -> void:
	var pts := _compound_points()
	if pts.size() < 3:
		return
	var group := _group("RetainingWall")
	# Leave a gap at the gate for the stairs.
	var gate_angle := 1000.0
	var gate := get_node_or_null("GateAnchor")
	if gate and gate is Node3D:
		gate_angle = rad_to_deg(atan2(gate.position.z, gate.position.x))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		var a := pts[i]; a.y = 0.1
		var b := pts[i + 1]; b.y = 0.1
		var mid := (a + b) * 0.5
		if gate_angle < 900.0 and absf(_angle_diff(rad_to_deg(atan2(mid.z, mid.x)), gate_angle)) < 9.0:
			continue
		# Push the wall face slightly outward so it sits just outside the ground fill.
		var out := Vector3(mid.x, 0, mid.z).normalized() * 0.4
		var at := a + out; var bt := b + out
		var ab := at; ab.y = OUTER_LEVEL
		var bb := bt; bb.y = OUTER_LEVEL
		for tri in [[at, bt, bb], [at, bb, ab], [at, bb, bt], [at, ab, bb]]:  # double-sided
			for p in tri:
				surface.set_uv(Vector2((p.x + p.z) * 0.15, p.y * 0.15))
				surface.add_vertex(p)
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh == null:
		return
	mesh.surface_set_material(0, CONCRETE_MAT)
	var body := StaticBody3D.new()
	body.name = "RetainingWallBody"
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
		# Regulation is 7.32 x 2.44 m; goal_scale multiplies that, posts included,
		# so the frame keeps its proportions as it grows.
		var goal_w := 7.32 * goal_scale
		var goal_h := 2.44 * goal_scale
		var post := 0.12 * goal_scale
		_slab("GoalPostL", Vector3(post, goal_h, post), Vector3(-goal_w * 0.5, goal_h * 0.5, z), LINE_MAT, anchor)
		_slab("GoalPostR", Vector3(post, goal_h, post), Vector3(goal_w * 0.5, goal_h * 0.5, z), LINE_MAT, anchor)
		# Bar runs post thickness wider so it closes the corners instead of
		# stopping at the post centres, and sits ON the posts rather than being
		# centred on them - goal height is measured to the crossbar's underside.
		_slab("GoalBar", Vector3(goal_w + post, post, post), Vector3(0, goal_h + post * 0.5, z), LINE_MAT, anchor)
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
	# Thin, with its top flush with the real roads (which sit at OUTER_LEVEL+0.06),
	# so it reads as ground, not a floating layer.
	_slab("Plaza", Vector3(60.0, 0.12, 40.0), Vector3(0, OUTER_LEVEL, 0), ROAD_MAT, anchor)


## The ELEVATED road serving the stadium complex. It carries its own raised
## earth platform down to the outer level (so it never floats), with the road
## surface on top and a line of trees planted beside it. Runs along local X.
func _build_complex_road(anchor: Node) -> void:
	var length := 70.0
	var width := 9.0
	var road_top := 0.12
	# Earth platform: fills from the road top straight down to the outer level.
	var earth_h := road_top - OUTER_LEVEL
	_slab("RoadEarth", Vector3(length, earth_h, width), Vector3(0, (road_top + OUTER_LEVEL) * 0.5, 0), FIELD_MAT, anchor)
	# Road surface on top, a little narrower so earth shows at the verges.
	_slab("ComplexRoad", Vector3(length, 0.16, width - 1.5), Vector3(0, road_top, 0), ROAD_MAT, anchor)


## Two-storey indoor sports centre, hollow and walk-in (rear faces the stadium,
## -Z). Behind it (-Z) is the quiet hideout spot for dealing.
##
## Built at the ANCHOR's own level, not OUTER_LEVEL, so it stands ON the raised
## compound and overlaps the stadium ground. The shell is made of separate wall
## slabs rather than one solid box: the front wall carries a door-height gap, an
## internal stair climbs to the mid floor, and the mid floor is laid as two
## strips so the stairwell stays open.
func _build_sports_complex(anchor: Node) -> void:
	var hx := 9.0              # half width, local X
	var hz := 6.0              # half depth, local Z
	var wt := 0.3              # wall thickness
	var floor_h := 3.5         # storey height (player is 1.8 m)
	var total_h := floor_h * 2.0
	var door_w := 2.4
	var door_h := 2.6
	var well_w := 3.5          # stairwell footprint, hard against the -X wall
	var well_d := 6.0

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2c3a30")

	# Shell: back and side walls run the full two storeys.
	_slab("WallBack", Vector3(hx * 2.0, total_h, wt), Vector3(0, total_h * 0.5, -hz), CONCRETE_MAT, anchor)
	_slab("WallLeft", Vector3(wt, total_h, hz * 2.0), Vector3(-hx, total_h * 0.5, 0), CONCRETE_MAT, anchor)
	_slab("WallRight", Vector3(wt, total_h, hz * 2.0), Vector3(hx, total_h * 0.5, 0), CONCRETE_MAT, anchor)

	# Front wall (+Z), split either side of the doorway, with a lintel over it.
	for sx in [-1.0, 1.0]:
		_slab("WallFront", Vector3(hx - door_w * 0.5, total_h, wt),
			Vector3(float(sx) * (hx + door_w * 0.5) * 0.5, total_h * 0.5, hz), CONCRETE_MAT, anchor)
	_slab("DoorLintel", Vector3(door_w, total_h - door_h, wt),
		Vector3(0, (door_h + total_h) * 0.5, hz), CONCRETE_MAT, anchor)

	# Mid floor, in two strips so the stairwell corner is left open.
	var slab_y := floor_h - wt * 0.5
	_slab("MidFloorA", Vector3(hx * 2.0 - well_w, wt, hz * 2.0),
		Vector3(-hx + well_w + (hx * 2.0 - well_w) * 0.5, slab_y, 0), CONCRETE_MAT, anchor)
	_slab("MidFloorB", Vector3(well_w, wt, hz * 2.0 - well_d),
		Vector3(-hx + well_w * 0.5, slab_y, -hz + well_d + (hz * 2.0 - well_d) * 0.5), CONCRETE_MAT, anchor)

	# Internal stair to the upper floor: solid blocks, so there are no gaps to
	# catch the capsule. 0.19 m risers are low enough to walk straight up.
	var steps := 18
	var rise := floor_h / steps
	var run := well_d / steps
	for i in range(steps):
		var top := (i + 1) * rise
		_slab("Step%d" % i, Vector3(well_w - wt, top, run),
			Vector3(-hx + wt + (well_w - wt) * 0.5, top * 0.5, -hz + i * run + run * 0.5), CONCRETE_MAT, anchor)

	_slab("Roof", Vector3(hx * 2.0 + 1.0, 0.4, hz * 2.0 + 1.0), Vector3(0, total_h + 0.2, 0), CONCRETE_MAT, anchor)

	# Upper-floor windows, sitting just proud of the front wall.
	for wx in [-6.0, -3.0, 3.0, 6.0]:
		var w := _slab("Window", Vector3(1.6, 1.4, 0.16), Vector3(wx, floor_h + 1.7, hz + 0.06), CONCRETE_MAT, anchor)
		w.get_child(0).material_override = dark


## Small public toilet block, always closed.
func _build_toilet(anchor: Node) -> void:
	var base := OUTER_LEVEL
	_slab("Toilet", Vector3(3.0, 2.6, 2.4), Vector3(0, base + 1.3, 0), CONCRETE_MAT, anchor)
	_slab("ToiletRoof", Vector3(3.3, 0.22, 2.7), Vector3(0, base + 2.7, 0), CONCRETE_MAT, anchor)
	var closed := StandardMaterial3D.new()
	closed.albedo_color = Color("2c3a30")
	var d := _slab("Door", Vector3(0.9, 1.9, 0.15), Vector3(0, base + 0.95, 1.25), CONCRETE_MAT, anchor)
	d.get_child(0).material_override = closed


## West secondary gate (closed) with a WELCOME arch over it. Sits at compound
## level (in the wall line), same green metal as the main gate.
func _build_welcome_arch(anchor: Node) -> void:
	_slab("ArchPostL", Vector3(0.6, 4.2, 0.6), Vector3(-3.4, 2.1, 0), CONCRETE_MAT, anchor)
	_slab("ArchPostR", Vector3(0.6, 4.2, 0.6), Vector3(3.4, 2.1, 0), CONCRETE_MAT, anchor)
	_slab("ArchBeam", Vector3(7.4, 1.1, 0.7), Vector3(0, 4.6, 0), GATE_MAT, anchor)
	# Closed gate leaves.
	_slab("GateL", Vector3(3.1, 2.8, 0.12), Vector3(-1.55, 1.4, 0), GATE_MAT, anchor)
	_slab("GateR", Vector3(3.1, 2.8, 0.12), Vector3(1.55, 1.4, 0), GATE_MAT, anchor)
	# "WELCOME" sign on the arch beam.
	var label := Label3D.new()
	label.text = "WELCOME"
	label.font_size = 96
	label.pixel_size = 0.012
	label.modulate = Color("f2f2e6")
	label.outline_size = 12
	label.position = Vector3(0, 4.6, 0.4)
	anchor.add_child(label)


## Small roundabout island (1 m) with a light pole, at a road junction (ground
## level).
func _build_roundabout(anchor: Node) -> void:
	var base := OUTER_LEVEL
	var island := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6a7b52")
	cyl.material = mat
	island.mesh = cyl
	island.position = Vector3(0, base + 0.15, 0)
	anchor.add_child(island)
	_slab("LightPole", Vector3(0.2, 6.0, 0.2), Vector3(0, base + 3.0, 0), POLE_MAT, anchor)
	# Glowing lamp head.
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color("fff3cf")
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("fff3cf")
	lamp_mat.emission_energy_multiplier = 2.0
	sphere.material = lamp_mat
	lamp.mesh = sphere
	lamp.position = Vector3(0, base + 6.0, 0)
	anchor.add_child(lamp)


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
	# Hoops. Regulation is a 0.45 m rim at 3.05 m; hoop_scale multiplies the whole
	# assembly, so pole, backboard and rim keep their proportions.
	var rim_r := 0.225 * hoop_scale
	var board_w := 1.8 * hoop_scale
	var board_h := 1.05 * hoop_scale
	var board_t := 0.1 * hoop_scale
	var rim_y := 3.05 * hoop_scale
	var pole_t := 0.2 * hoop_scale
	for side in [-1.0, 1.0]:
		var sign := float(side)
		var z := sign * 14.0
		_slab("HoopPole", Vector3(pole_t, rim_y, pole_t), Vector3(0, rim_y * 0.5, z), POLE_MAT, anchor)
		var board_z := z - sign * 0.3 * hoop_scale
		_slab("Backboard", Vector3(board_w, board_h, board_t), Vector3(0, rim_y + board_h * 0.35, board_z), POLE_MAT, anchor)
		# The ring itself, hung off the face of the board at rim height.
		var rim := MeshInstance3D.new()
		rim.name = "HoopRing"
		var torus := TorusMesh.new()
		torus.outer_radius = rim_r
		torus.inner_radius = rim_r - maxf(0.02, 0.02 * hoop_scale)
		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = Color("d4541f")
		rim_mat.roughness = 0.5
		torus.material = rim_mat
		rim.mesh = torus
		rim.position = Vector3(0, rim_y, board_z - sign * (board_t * 0.5 + rim_r))
		anchor.add_child(rim)


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
	return _carve_ground_cut(out)


## Subtract CutAnchor's rectangle from the compound outline. Everything that
## draws the compound - ground fill, retaining wall, boundary wall, boundary
## trees - reads the outline through here, so one carve moves all of them.
##
## The bite must touch the compound EDGE. A rectangle floating entirely inside
## would need a hole, and the consumers walk a single ring (pts[i] -> pts[i + 1]),
## which cannot express one; in that case the carve is skipped rather than
## silently producing a mangled outline.
func _carve_ground_cut(pts: PackedVector3Array) -> PackedVector3Array:
	if not enable_ground_cut or pts.size() < 4:
		return pts
	var anchor := get_node_or_null("CutAnchor") as Node3D
	if anchor == null:
		return pts

	var subject := PackedVector2Array()
	for i in range(pts.size() - 1):        # drop the repeated closing point
		subject.append(Vector2(pts[i].x, pts[i].z))

	# CutAnchor's rectangle, in world XZ, following the anchor's yaw.
	var basis := anchor.global_transform.basis
	var right := Vector2(basis.x.x, basis.x.z).normalized() * ground_cut_width_m * 0.5
	var forward := Vector2(basis.z.x, basis.z.z).normalized() * ground_cut_depth_m * 0.5
	var centre := Vector2(anchor.position.x, anchor.position.z)
	var rect := PackedVector2Array([
		centre - right - forward,
		centre + right - forward,
		centre + right + forward,
		centre - right + forward,
	])

	var pieces := Geometry2D.clip_polygons(subject, rect)
	if pieces.is_empty():
		return pts

	# Keep the largest outer ring; discard holes and slivers.
	var best := PackedVector2Array()
	var best_area := 0.0
	for piece in pieces:
		if Geometry2D.is_polygon_clockwise(piece):
			continue                        # a hole - not representable here
		var a := _polygon_area(piece)
		if a > best_area:
			best_area = a
			best = piece
	if best.size() < 3:
		return pts

	var y := pts[0].y
	var out := PackedVector3Array()
	for p in best:
		out.append(Vector3(p.x, y, p.y))
	out.append(Vector3(best[0].x, y, best[0].y))   # re-close the ring
	return out


func _polygon_area(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


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

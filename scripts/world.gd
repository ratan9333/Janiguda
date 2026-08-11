extends Node3D
## Loads the Janiguda map and spawns the player on it.
##
## World origin (0,0,0) is 18°43'28.36"N 82°49'35.57"E - the centre of HAL
## Stadium, Sunabeda - at ground level. 1 Godot unit = 1 metre.
##
## The map is built in Blender (see ../JanigudaBlender) from:
##   terrain    SRTM/NASADEM ~30 m, resampled to a 15.6 m grid, 4 x 4 km
##   imagery    Esri World Imagery at 1.13 m/px, draped as the ground texture
##   roads      OSM - 123 km of centreline, lane counts, medians, street lights
##   stadium    OSM footprint + reference photos
##   buildings  Overture Maps ML footprints (real outlines, inferred heights)
## Re-export with terrain/export_godot.py inside Blender.

const CENTER_LAT := 18.7245444        # 18°43'28.36"N
const CENTER_LON := 82.8265472        # 82°49'35.57"E

## Terrain height at the origin in the Blender scene. The map is lowered by
## this so the stadium field - and therefore the world origin - sits at y = 0.
const GROUND_OFFSET := 45.67

const MAP_PATH := "res://world/map.glb"
const ASSET_PATH := "res://world/assets.glb"
const PLAYER_PATH := "res://scenes/Player.tscn"

## Grass is 103k instances of a 4-triangle clump, so it fades out close in.
## These two are the first knobs to turn if the framerate suffers.
const GRASS_RANGE := 130.0
const TREE_RANGE := 1400.0

@export var load_vegetation := true
@export var generate_collision := true
@export var spawn_player := true

var map_root: Node3D
var player: CharacterBody3D


## Real-world coordinate -> world position. Use this for any further OSM or
## GPS data so it lands in the same frame as the map.
func latlon_to_world(latitude: float, longitude: float) -> Vector3:
	var meters_per_lat := 111132.92 - 559.82 * cos(deg_to_rad(2.0 * CENTER_LAT)) \
		+ 1.175 * cos(deg_to_rad(4.0 * CENTER_LAT))
	var meters_per_lon := 111412.84 * cos(deg_to_rad(CENTER_LAT)) \
		- 93.5 * cos(deg_to_rad(3.0 * CENTER_LAT))
	return Vector3(
		(longitude - CENTER_LON) * meters_per_lon,
		0.0,
		-(latitude - CENTER_LAT) * meters_per_lat)


func _ready() -> void:
	var t0 := Time.get_ticks_msec()

	map_root = Node3D.new()
	map_root.name = "MapRoot"
	# No horizontal shift: the Blender tile is centred on the world origin.
	map_root.position = Vector3(0.0, -GROUND_OFFSET, 0.0)
	add_child(map_root)

	var packed := load(MAP_PATH) as PackedScene
	if packed == null:
		push_error("world: could not load %s" % MAP_PATH)
		return
	var map := packed.instantiate()
	map.name = "Map"
	map_root.add_child(map)

	if generate_collision:
		print("world: %d collision bodies" % _add_collision(map))
	if load_vegetation:
		_load_vegetation()
	if spawn_player:
		_spawn_player()

	print("world: ready in %d ms" % (Time.get_ticks_msec() - t0))


func _add_collision(node: Node) -> int:
	## Trimesh straight off the visual geometry, ~250k triangles. Costs about a
	## second at load. To make it instant instead, select world/map.glb in the
	## FileSystem dock, set the import to generate collision, and drop this.
	var count := 0
	if node is MeshInstance3D and node.mesh != null:
		node.create_trimesh_collision()
		count += 1
	for child in node.get_children():
		count += _add_collision(child)
	return count


func _find_mesh(node: Node, prefix: String) -> Mesh:
	## glTF can suffix node names (TreeAsset_0.007), so match on prefix.
	if node is MeshInstance3D and node.name.begins_with(prefix):
		return node.mesh
	for child in node.get_children():
		var found := _find_mesh(child, prefix)
		if found != null:
			return found
	return null


func _add_multimesh(mesh: Mesh, path: String, range_end: float,
		shadows: bool) -> int:
	if mesh == null:
		push_warning("world: no source mesh for %s" % path)
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("world: missing %s" % path)
		return 0
	# uint32 count, then 12 float32 per instance in row-major 3x4 order, which
	# is byte-identical to MultiMesh.buffer for TRANSFORM_3D - so this is one
	# assignment rather than 100k set_instance_transform() calls.
	var count := f.get_32()
	var buf := f.get_buffer(count * 12 * 4).to_float32_array()
	f.close()
	if buf.is_empty():
		return 0

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buf

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = range_end
	mmi.visibility_range_end_margin = range_end * 0.15
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The instances span the whole 4 km tile. Without an explicit AABB the
	# entire batch is culled as soon as the node origin leaves the frustum.
	mmi.custom_aabb = AABB(Vector3(-2100, -50, -2100), Vector3(4200, 400, 4200))
	map_root.add_child(mmi)
	return count


func _load_vegetation() -> void:
	var packed := load(ASSET_PATH) as PackedScene
	if packed == null:
		push_warning("world: could not load %s" % ASSET_PATH)
		return
	var assets := packed.instantiate()
	var trees := 0
	for i in 3:
		trees += _add_multimesh(_find_mesh(assets, "TreeAsset_%d" % i),
			"res://world/trees_%d.bin" % i, TREE_RANGE, true)
	var grass := _add_multimesh(_find_mesh(assets, "GrassAsset"),
		"res://world/grass_0.bin", GRASS_RANGE, false)
	assets.queue_free()
	print("world: %d trees, %d grass clumps" % [trees, grass])


func _spawn_player() -> void:
	var packed := load(PLAYER_PATH) as PackedScene
	if packed == null:
		push_error("world: could not load %s" % PLAYER_PATH)
		return
	player = packed.instantiate()
	# Directly over the world origin - the requested coordinate. Starts a few
	# metres up and drops onto the stadium field at y = 0.
	player.position = Vector3(0.0, 3.0, 0.0)
	add_child(player)

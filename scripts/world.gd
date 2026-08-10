extends "res://scripts/main.gd"

# Minimal roaming sandbox: sky, sun, terrain and the player. Nothing else.
#
# It reuses main.gd's input map, environment, character and camera rig, but not
# its build_world() — that also calls build_geographic_gameplay(), which spawns
# the kirana shop, the NPCs and the labels. The terrain is generated at runtime
# rather than loaded from a baked scene, so there is nothing to re-bake.

const SPAWN_HEIGHT := 2.0
# The procedural ground from geographic_world.gd. Set false once a Terrain3D node
# in the scene provides the ground instead, or the two will overlap.
const USE_GENERATED_TERRAIN := true


func _ready() -> void:
	setup_input()
	build_environment()
	if USE_GENERATED_TERRAIN:
		build_terrain_only_world()
	build_player()


func build_terrain_only_world() -> void:
	geographic_world = Node3D.new()
	geographic_world.name = "GeographicWorld"
	geographic_world.set_script(GEOGRAPHIC_WORLD_SCRIPT)
	add_child(geographic_world)
	# BUILD_SCENERY is false, so generate() loads the elevation and road data for
	# height queries and then builds the terrain mesh and nothing more.
	geographic_world.generate()


func build_player() -> void:
	super()
	# Drop a Marker3D named PlayerSpawn anywhere in the scene (including inside an
	# instanced sub-scene) to choose where the player starts and which way it
	# faces. Without one, the player begins above the origin.
	var marker := find_child("PlayerSpawn", true, false)
	if marker is Node3D:
		player.position = (marker as Node3D).global_position
		player.rotation.y = (marker as Node3D).global_rotation.y
	elif geographic_world:
		player.position.y = geographic_world.surface_height_at(0.0, 0.0) + SPAWN_HEIGHT
	else:
		# Terrain3D provides the ground; it sits at y = 0 until sculpted.
		player.position.y = SPAWN_HEIGHT

extends Node

## Visual polish pass.
##
## Deliberately does NOT create its own WorldEnvironment. It finds the one
## main.gd already builds and upgrades that Environment resource in place, so
## this file never conflicts with map/environment work happening in main.gd.
##
## Requires the Forward+ renderer. On gl_compatibility most of this is ignored
## by the engine and the scene just looks like it did before.

@export var enabled := true


func _ready() -> void:
	if not enabled:
		return
	# Wait one frame so main.gd has finished building the world.
	await get_tree().process_frame
	var world_environment := _find_world_environment(get_tree().root)
	if world_environment == null:
		push_warning("post_fx: no WorldEnvironment found, skipping")
		return
	_upgrade(world_environment.environment)
	_upgrade_sun(_find_sun(get_tree().root))


func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var found := _find_world_environment(child)
		if found:
			return found
	return null


func _find_sun(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node
	for child in node.get_children():
		var found := _find_sun(child)
		if found:
			return found
	return null


func _upgrade(environment: Environment) -> void:
	if environment == null:
		return

	# Contact shadows where geometry meets the ground. This is the single
	# biggest win for a world made of untextured boxes - without it everything
	# reads as floating.
	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 2.6
	environment.ssao_power = 1.6
	environment.ssao_detail = 0.6

	# Bounced light between nearby surfaces. Subtle, but stops shadowed faces
	# from going flat and dead.
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.65
	environment.ssil_radius = 3.5

	# AgX holds highlights far better than Filmic under a bright outdoor sun.
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0

	# Aerial perspective. Gives a 2 km open map a real sense of distance.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("b9c9d4")
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.12
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.35

	# Gentle bloom on sunlit surfaces only.
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.glow_bloom = 0.05
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 1.1

	# Slight warmth and contrast. Small numbers on purpose - heavy grading is
	# what makes prototypes look worse, not better.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08


func _upgrade_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.16
	sun.directional_shadow_split_3 = 0.42
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.4
	# Soft, sun-sized penumbra rather than a hard stencil edge.
	sun.light_angular_distance = 1.2

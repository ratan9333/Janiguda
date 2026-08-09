extends Node3D

## Bootstrap for the HAL Stadium base scene: environment, sun, the real-world
## generator, a survey camera, and an on-screen readout of where you are.

const HAL_WORLD_SCRIPT := preload("res://scripts/hal_world.gd")

var world
var info_label: Label
var camera: Camera3D


func _ready() -> void:
	_build_environment()
	world = Node3D.new()
	world.name = "HalWorld"
	world.set_script(HAL_WORLD_SCRIPT)
	add_child(world)
	world.generate()
	_build_camera()
	_build_hud()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3a6ea5")
	sky_material.sky_horizon_color = Color("cfd8dc")
	sky_material.ground_bottom_color = Color("5c5648")
	sky_material.ground_horizon_color = Color("cfd8dc")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	# Aerial haze for depth over the 2 km hilly terrain.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("bcc9d1")
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.3
	world_environment.environment = env
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_color = Color("fff2da")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	add_child(sun)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/fly_camera.gd"))
	camera.fov = 65.0
	# Start above the origin marker looking toward the stadium footprint.
	var start_height: float = world.height_at(0, 0) + 35.0
	camera.position = Vector3(0, start_height, 60)
	camera.far = 4000.0
	add_child(camera)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	info_label = Label.new()
	info_label.position = Vector2(16, 16)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(info_label)


func _process(_delta: float) -> void:
	if info_label == null or camera == null:
		return
	var p := camera.global_position
	info_label.text = "HAL Stadium base — Sunabeda  (origin = 18.724522, 82.826247)\n" \
		+ "Camera x=%.0f z=%.0f  |  WASD fly · Shift boost · Space/Ctrl up-down · Esc mouse\n" % [p.x, p.z] \
		+ "Orange patch = real HAL Stadium footprint (225 x 221 m)  ·  Red pole = map origin"

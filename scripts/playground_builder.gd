extends Node3D

## Builds a small greybox test course: flat ground, a ramp, stairs and a few
## platforms at different heights. Enough to feel walking, running, jumping,
## coyote time and landings without loading the real world.

func _ready() -> void:
	_box("Ground", Vector3(40, 1, 40), Vector3(0, -0.5, 0), Color("3a3d38"))

	# A ramp to test slope handling.
	var ramp := _box("Ramp", Vector3(6, 0.5, 8), Vector3(-10, 1.4, 0), Color("4a5560"))
	ramp.rotation_degrees.x = -20.0

	# A staircase.
	for i in range(6):
		_box("Step%d" % i, Vector3(4, 0.4, 1.4), Vector3(8, 0.2 + i * 0.4, -6 + i * 1.4), Color("55606b"))

	# Jump platforms at rising heights - test the jump arc and coyote time.
	_box("Plat1", Vector3(3, 0.5, 3), Vector3(6, 1.0, 6), Color("5c6470"))
	_box("Plat2", Vector3(2.6, 0.5, 2.6), Vector3(10.5, 2.0, 8), Color("5c6470"))
	_box("Plat3", Vector3(2.2, 0.5, 2.2), Vector3(14, 3.2, 6.5), Color("5c6470"))

	# A low wall to bump into and slide along.
	_box("Wall", Vector3(0.5, 1.4, 10), Vector3(-4, 0.7, -8), Color("6b5b4a"))

	# Reference markers every 5 m so speed is readable.
	for x in [-15, -10, -5, 5, 10, 15]:
		_box("Mark", Vector3(0.15, 0.05, 40), Vector3(x, 0.03, 0), Color("2c2e2a"))


func _box(node_name: String, size: Vector3, position: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	add_child(body)
	return body

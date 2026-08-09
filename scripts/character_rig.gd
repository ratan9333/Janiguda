extends Node3D

## Character visuals, kept separate from the movement controller.
##
## Drop a rigged model in res://assets/characters/ named player.<ext> and this
## node uses it automatically. Until then it builds the blocky placeholder so
## the game always runs. Nothing else needs to change when you swap.
##
## Godot 4.7 imports .fbx natively, so a Mixamo FBX export works directly.
## .glb (Blender) and .dae are also accepted, in that order of preference.

const MODEL_PATHS := [
	"res://assets/characters/player.glb",
	"res://assets/characters/player.fbx",
	"res://assets/characters/player.dae",
]

## The placeholder is modelled around the hips; this lifts it so the feet sit at
## the rig's origin (y=0), matching how Mixamo/Blender models export - feet on
## the floor. Keeps the swap to a real model seamless.
const FOOT_OFFSET := 0.97

## True while the placeholder is in use. player.gd checks this to decide
## between hand-driven limb rotation and real animation playback.
var is_placeholder := true

## Limb roots. Populated for the placeholder; left null for imported models,
## where the AnimationPlayer drives the skeleton instead.
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D

var animation_player: AnimationPlayer


func _ready() -> void:
	var found := ""
	for path in MODEL_PATHS:
		if ResourceLoader.exists(path):
			found = path
			break
	if found.is_empty():
		_build_placeholder()
	else:
		_load_model(found)


func _load_model(path: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("character_rig: %s failed to load, using placeholder" % path)
		_build_placeholder()
		return
	var model := scene.instantiate()
	add_child(model)
	is_placeholder = false
	animation_player = _find_animation_player(model)
	if animation_player == null:
		push_warning("character_rig: %s has no AnimationPlayer, poses will be static" % path)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


## Play an animation by name if the imported model provides one.
## Returns false when there is nothing to play, so the caller can fall back.
func play(animation_name: String, blend := 0.15) -> bool:
	if animation_player == null:
		return false
	if not animation_player.has_animation(animation_name):
		return false
	if animation_player.current_animation == animation_name:
		return true
	animation_player.play(animation_name, blend)
	return true


func _build_placeholder() -> void:
	is_placeholder = true

	# Everything hangs under a body node lifted by FOOT_OFFSET, so the feet rest
	# at the rig's origin. Limb rotation is unaffected - the offset is only a
	# translation of the whole body.
	var body := Node3D.new()
	body.name = "PlaceholderBody"
	body.position.y = FOOT_OFFSET
	add_child(body)

	_add_box(body, "Torso", Vector3(0.72, 0.82, 0.38), Vector3(0, 0.34, 0), Color("375a8c"))
	_add_box(body, "ShirtStripe", Vector3(0.74, 0.10, 0.40), Vector3(0, 0.48, 0), Color("e6a84e"))
	_add_box(body, "Waist", Vector3(0.62, 0.18, 0.34), Vector3(0, -0.14, 0), Color("202735"))

	left_arm = _add_joint(body, "LeftArm", Vector3(-0.47, 0.66, 0))
	_add_box(left_arm, "Sleeve", Vector3(0.23, 0.42, 0.28), Vector3(0, -0.20, 0), Color("375a8c"))
	_add_box(left_arm, "Forearm", Vector3(0.19, 0.38, 0.20), Vector3(0, -0.56, 0), Color("d6a178"))
	_add_sphere(left_arm, "Hand", 0.13, Vector3(0, -0.79, 0), Color("d6a178"))

	right_arm = _add_joint(body, "RightArm", Vector3(0.47, 0.66, 0))
	_add_box(right_arm, "Sleeve", Vector3(0.23, 0.42, 0.28), Vector3(0, -0.20, 0), Color("375a8c"))
	_add_box(right_arm, "Forearm", Vector3(0.19, 0.38, 0.20), Vector3(0, -0.56, 0), Color("d6a178"))
	_add_sphere(right_arm, "Hand", 0.13, Vector3(0, -0.79, 0), Color("d6a178"))

	left_leg = _add_joint(body, "LeftLeg", Vector3(-0.19, -0.18, 0))
	_add_box(left_leg, "Trouser", Vector3(0.27, 0.67, 0.30), Vector3(0, -0.31, 0), Color("263047"))
	_add_box(left_leg, "Shoe", Vector3(0.31, 0.18, 0.49), Vector3(0, -0.70, -0.08), Color("17191e"))

	right_leg = _add_joint(body, "RightLeg", Vector3(0.19, -0.18, 0))
	_add_box(right_leg, "Trouser", Vector3(0.27, 0.67, 0.30), Vector3(0, -0.31, 0), Color("263047"))
	_add_box(right_leg, "Shoe", Vector3(0.31, 0.18, 0.49), Vector3(0, -0.70, -0.08), Color("17191e"))

	head = _add_joint(body, "Head", Vector3(0, 1.05, 0))
	_add_sphere(head, "Face", 0.34, Vector3.ZERO, Color("d6a178"))
	_add_sphere(head, "LeftEar", 0.09, Vector3(-0.32, 0, 0), Color("c98f69"))
	_add_sphere(head, "RightEar", 0.09, Vector3(0.32, 0, 0), Color("c98f69"))
	_add_box(head, "HairTop", Vector3(0.58, 0.17, 0.55), Vector3(0, 0.27, 0.02), Color("33251f"))
	_add_box(head, "HairSide", Vector3(0.62, 0.30, 0.18), Vector3(0, 0.13, 0.21), Color("33251f"))
	_add_sphere(head, "LeftEye", 0.055, Vector3(-0.12, 0.06, -0.30), Color("f7f5ec"))
	_add_sphere(head, "RightEye", 0.055, Vector3(0.12, 0.06, -0.30), Color("f7f5ec"))
	_add_sphere(head, "LeftPupil", 0.024, Vector3(-0.12, 0.055, -0.348), Color("202027"))
	_add_sphere(head, "RightPupil", 0.024, Vector3(0.12, 0.055, -0.348), Color("202027"))
	_add_box(head, "Mouth", Vector3(0.15, 0.025, 0.025), Vector3(0, -0.13, -0.335), Color("713f3e"))


func _add_joint(parent: Node3D, joint_name: String, position: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = position
	parent.add_child(joint)
	return joint


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _add_box(parent: Node3D, part_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _make_material(color)
	part.mesh = mesh
	part.position = position
	parent.add_child(part)
	return part


func _add_sphere(parent: Node3D, part_name: String, radius: float, position: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _make_material(color)
	part.mesh = mesh
	part.position = position
	parent.add_child(part)
	return part

extends Area3D

var conversation_index := 0
var health := 3
var reacting := false
var home_position: Vector3
var lines := [
	"Neighbour: Welcome to Jharaput, near the state highway.",
	"Neighbour: The kirana shop sells cigarettes for $10.",
	"Neighbour: Kharaguda and Jagamput are farther along these roads.",
]


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("punchable")
	home_position = global_position


func get_interaction_text() -> String:
	return "Press E to talk to neighbour"


func interact(player) -> void:
	player.show_message(lines[conversation_index])
	conversation_index = (conversation_index + 1) % lines.size()


func receive_punch(attacker_position: Vector3) -> void:
	if reacting:
		return
	reacting = true
	health -= 1
	var away := global_position - attacker_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()
	var rig: Node3D = get_node("CharacterRig")
	var start_position := global_position
	var target_position := start_position + away * 0.65
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_position, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(rig, "rotation:z", -0.28, 0.11)
	await tween.finished
	if health <= 0:
		var fall := create_tween()
		fall.tween_property(rig, "rotation:z", -1.35, 0.28).set_trans(Tween.TRANS_QUAD)
		await fall.finished
		await get_tree().create_timer(2.0).timeout
		health = 3
		global_position = home_position
	var recover := create_tween()
	recover.tween_property(rig, "rotation:z", 0.0, 0.35)
	await recover.finished
	reacting = false

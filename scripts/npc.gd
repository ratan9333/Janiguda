extends Area3D

var conversation_index := 0
var lines := [
	"Neighbour: Nice day for a walk through the park.",
	"Neighbour: The corner shop sells cigarettes for $10.",
	"Neighbour: That apartment across the road is open.",
]


func _ready() -> void:
	add_to_group("interactable")


func get_interaction_text() -> String:
	return "Press E to talk to neighbour"


func interact(player) -> void:
	player.show_message(lines[conversation_index])
	conversation_index = (conversation_index + 1) % lines.size()

extends Area3D

const PACK_PRICE := 10


func _ready() -> void:
	add_to_group("interactable")


func get_interaction_text() -> String:
	return "Press E to buy 5 cigarettes — $%d" % PACK_PRICE


func interact(player) -> void:
	player.buy_cigarettes(PACK_PRICE, 5)

extends Area3D

var base_y := 0.0
var time := 0.0


func _ready() -> void:
	add_to_group("cigarette_pickup")
	base_y = position.y


func _process(delta: float) -> void:
	time += delta
	rotation.y += delta * 1.2
	position.y = base_y + sin(time * 2.2) * 0.08


func collect() -> void:
	queue_free()


extends RigidBody3D

## A kickable football. Real-ish size (0.22 m) and mass (0.43 kg). The player's
## controller calls kick() when you press F near it.

func _ready() -> void:
	add_to_group("kickable")


## Send the ball rolling in `direction`, with a little lift so it arcs.
func kick(direction: Vector3, power: float) -> void:
	var impulse := direction.normalized() * power + Vector3.UP * power * 0.28
	apply_central_impulse(impulse)
	# A touch of spin so it rolls naturally.
	apply_torque_impulse(Vector3(direction.z, 0, -direction.x) * power * 0.15)

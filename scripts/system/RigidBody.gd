extends RigidBody2D

@onready var pushable_box = $"."

func get_box_inertia():
	return 1.0 / PhysicsServer2D.body_get_direct_state(pushable_box.get_rid()).inverse_inertia


extends AI_Class
class_name EnemyBase

@export var health: float = 10
		
func take_damage(amount: float) -> void:
	health -= amount
	print(health)
	if health <= 0:
		queue_free()

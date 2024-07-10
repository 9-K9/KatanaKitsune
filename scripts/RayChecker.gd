extends RayCast2D

func _draw():
	if enabled:
		draw_line(Vector2.ZERO, self.target_position, Color(1, 0, 0), 2)

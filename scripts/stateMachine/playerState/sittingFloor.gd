extends PlayerClass

## Resting. She recovers health for as long as she is left alone, and any input
## gets her up again. Reached by standing still — see idle.gd.

func on_enter():
	pc.speed = 0.0

func on_process(_delta):
	stateAnimation("sittingFloor", 2)
	if pc.InputHandler() != Vector2.ZERO \
			or pc.input.just_pressed("Attack") \
			or pc.input.just_pressed("Katana") \
			or pc.input.just_pressed("Stealth") \
			or pc.input.just_pressed("Jump") \
			or pc.input.just_pressed("Dodge"):
		change_state("idle")

func on_physics_process(delta):
	pc.rest(delta)

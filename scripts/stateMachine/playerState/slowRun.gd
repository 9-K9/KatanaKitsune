extends PlayerClass

## A jog. Sits between walk and run, used when she is hurt badly enough that
## sprinting is off the table.

func on_enter():
	pc.speed = pc.walkSpeed * 1.3

func on_process(_delta):
	stateAnimation("slowRun", 8)
	if pc.InputHandler() == Vector2.ZERO:
		change_state("idle")
	elif not Input.is_action_pressed("Run"):
		change_state("walk")
	if Input.is_action_just_pressed("Katana"):
		change_state("katanaDraw")

class_name EnemyState
extends StateMachineState

## Base class for the monster states.
## Mirrors PlayerClass: the state nodes sit under a FiniteStateMachine that is
## itself a child of the monster, so the default path back up is "../..".

## Node path to the monster.
@export_node_path("CharacterBody2D") var _enemy: NodePath = "../.."

## Reference to the monster node.
@onready var enemy: EnemyBase = get_node(_enemy)

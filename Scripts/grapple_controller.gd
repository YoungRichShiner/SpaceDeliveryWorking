extends Node2D

@onready var ray:= $RayCast2D

var launched = false
var target = Vector2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("grapple"):
		launch()
	if Input.is_action_just_released("grapple"):
		retract()

func launch():
	if ray.is_colliding():
		launched = true
		target = ray.get_collision_point()

func retract():
	launched = false

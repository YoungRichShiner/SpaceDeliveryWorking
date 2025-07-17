extends RigidBody2D

func _physics_process(_delta):
	if Input.is_action_pressed("ui_up"): apply_force(Vector2(0, -500))
	if Input.is_action_pressed("ui_left"): angular_velocity = -3
	if Input.is_action_pressed("ui_right"): angular_velocity = 3
	if Input.is_action_pressed("ui_accept"): linear_velocity = Vector2.ZERO

extends Node2D

@onready var GrappleRay := $RayCast2D
@onready var ship := get_parent()
@onready var HoldTimer := $Timer
@onready var WhipBeam := $WhipBeam

# Physics Parameters
@export var flick_force := 700.0
@export var rest_length := 0.0
@export var stiffness := 80.0
@export var damping := 45.0
@export var hold_offset := 180.0
@export var whip_origin_offset := 20.0
@export var brake_strength := 12.0
@export var min_distance := 60.0
@export var push_strength := 500.0
@export var max_release_speed := 800.0

# Tension System
@export var max_beam_tension := 20000.0
@export var tension_decay_rate := 50.0
@export var base_tension_multiplier := 0.2

var hooked_object: RigidBody2D = null
var is_holding := false
var current_tension := 0.0
var is_beam_at_risk := false



# # Releases hooked object with optional snap effects and velocity clamping
func release_grapple(snap: bool = false):
	if hooked_object:
		#if snap:
			#$SnapSound.play()
			#$AnimationPlayer.play("beam_snap")
		
		# Clamp release velocity
		var current_speed = hooked_object.linear_velocity.length()
		if current_speed > max_release_speed:
			hooked_object.linear_velocity = hooked_object.linear_velocity.normalized() * max_release_speed
	
	hooked_object = null
	is_holding = false
	WhipBeam.points = []
	current_tension = 0.0
	is_beam_at_risk = false


# # Handles grapple button press/release with tap/hold distinction
func _input(event):
	if event.is_action_pressed("grapple"):
		if GrappleRay.is_colliding():
			var obj = GrappleRay.get_collider()
			if obj is RigidBody2D:
				hooked_object = obj
				is_holding = true
				HoldTimer.start()
				current_tension = 0.0
				is_beam_at_risk = false
	
	if event.is_action_released("grapple"):
		if hooked_object:
			is_holding = false
			if HoldTimer.time_left > 0:
				var dir = (get_hold_point() - hooked_object.position).normalized()
				hooked_object.apply_central_impulse(dir * flick_force)
			release_grapple()


# # Main physics loop: calculates forces, updates tension, and manages snapping
func _physics_process(delta):
	if hooked_object and is_holding:
		if not is_instance_valid(hooked_object) or not hooked_object.get_parent():
			release_grapple()
			return

		# Calculate all physics forces first
		var hold_point = get_hold_point()
		var obj_pos = hooked_object.position
		var to_obj = obj_pos - ship.global_position
		var current_dist = to_obj.length()
		var shape = _get_object_shape(hooked_object)
		var shape_radius = _get_shape_radius(shape) if shape else 0.0
		var desired_dist = hold_offset + shape_radius

		# Soft repulsion when too close
		if current_dist < desired_dist:
			var push_dir = to_obj.normalized()
			var push_ratio = 1.0 - (current_dist / desired_dist)
			var push_force = push_dir * push_ratio * push_strength
			hooked_object.apply_central_force(push_force)

		# Spring force
		var dir = (hold_point - obj_pos).normalized()
		var dist = hold_point.distance_to(obj_pos)
		var displacement = dist - rest_length
		var spring_force = dir * (stiffness * displacement)
		
		# Damping
		var rel_vel = hooked_object.linear_velocity - ship.linear_velocity
		var vel_along_dir = rel_vel.dot(dir)
		var damping_force = -damping * vel_along_dir * dir
		
		hooked_object.apply_central_force(spring_force + damping_force)

		# Orbit brake
		var facing = Vector2.RIGHT.rotated(ship.rotation)
		var tangent = Vector2(-facing.y, facing.x)
		var side_vel = rel_vel.dot(tangent)
		var brake_force = -tangent * side_vel * brake_strength
		hooked_object.apply_central_force(brake_force)

		# Calculate tension from movement forces only
		var movement_force = Vector2.ZERO
		if displacement > 0:  # Only count when stretching the beam
			movement_force = spring_force
		
		# Update tension (scaled by mass and force)
		var tension_increase = (movement_force.length() * delta) * base_tension_multiplier
		tension_increase *= hooked_object.mass  # Natural mass scaling
		current_tension = min(current_tension + tension_increase, max_beam_tension)
		
		# Update visuals
		_update_beam_visuals()
		
		# Check for snap
		if current_tension >= max_beam_tension:
			release_grapple(true)
			return

		# Whip visuals
		var WhipOrigin = ship.global_position + Vector2.RIGHT.rotated(ship.rotation) * whip_origin_offset
		WhipBeam.points = [WhipOrigin, hooked_object.global_position]

		if dist < 2.0 and hooked_object.linear_velocity.length() < 5.0:
			hooked_object.linear_velocity = Vector2.ZERO
	else:
		# Gradually reduce tension when not holding
		current_tension = max(current_tension - tension_decay_rate * delta, 0.0)
		_update_beam_visuals()


# # Updates whip color/width based on current tension (blue->red, pulsing at high tension)
func _update_beam_visuals():
	var tension_ratio = current_tension / max_beam_tension
	WhipBeam.default_color = Color(
		0.3 + tension_ratio * 0.7,  # R
		0.7 - tension_ratio * 0.7,  # G
		1.0 - tension_ratio * 0.7,  # B
		1.0
	)
	
	# Pulsing effect at high tension
	if tension_ratio > 0.7:
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.2
		WhipBeam.width = 3.0 * pulse
	else:
		WhipBeam.width = 3.0


# # Calculates ideal hold position accounting for object size and ship offset
func get_hold_point() -> Vector2:
	var offset = hold_offset
	if hooked_object and is_instance_valid(hooked_object):
		var shape = _get_object_shape(hooked_object)
		if shape:
			offset += _get_shape_radius(shape)
	return ship.global_position + Vector2.RIGHT.rotated(ship.rotation) * offset
	
# # Helper: Gets the collision shape of a physics object
func _get_object_shape(obj: RigidBody2D) -> Shape2D:
	if obj.get_shape_owners().size() > 0:
		return obj.shape_owner_get_shape(0, 0)
	return null

# # Helper: Calculates effective radius for different shape types
func _get_shape_radius(shape: Shape2D) -> float:
	if shape is CircleShape2D:
		return shape.radius
	elif shape is RectangleShape2D:
		return max(shape.extents.x, shape.extents.y)
	elif shape is CapsuleShape2D:
		return shape.radius + (shape.height * 0.5)
	return 0.0

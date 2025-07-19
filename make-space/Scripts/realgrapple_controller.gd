extends Node2D

@onready var GrappleRay := $RayCast2D
@onready var ship := get_parent()
@onready var HoldTimer := $Timer
@onready var WhipBeam := $WhipBeam

@export var flick_force := 700.0
@export var rest_length := 0.0
@export var stiffness := 80.0
@export var damping := 45.0
@export var hold_offset := 180.0
@export var whip_origin_offset := 20.0
@export var brake_strength := 12.0 # Damping for sideways/orbit motion

var hooked_object: RigidBody2D = null
var is_holding := false

func release_grapple():
	hooked_object = null
	is_holding = false
	WhipBeam.points = []
	
func _input(event):
	if event.is_action_pressed("grapple"):
		if GrappleRay.is_colliding():
			var obj = GrappleRay.get_collider()
			if obj is RigidBody2D:
				hooked_object = obj
				is_holding = true
				HoldTimer.start()
	if event.is_action_released("grapple"):
		if hooked_object:
			is_holding = false
			if HoldTimer.time_left > 0:
				var dir = (get_hold_point() - hooked_object.position).normalized()
				hooked_object.apply_central_impulse(dir * flick_force)
			release_grapple()

func _physics_process(delta):
	if hooked_object and is_holding:
		if not is_instance_valid(hooked_object) or not hooked_object.get_parent():
			release_grapple()
			return

		var hold_point = get_hold_point()
		var obj_pos = hooked_object.position

		# --- Clamp hold point to minimum distance from ship ---
		var min_distance = 60.0 # tweak as needed
		var to_obj = obj_pos - ship.global_position
		if to_obj.length() < min_distance:
			hold_point = ship.global_position + to_obj.normalized() * min_distance

		# --- Spring force toward hold point ---
		var dir = (hold_point - obj_pos).normalized()
		var dist = hold_point.distance_to(obj_pos)
		var effective_stiffness = stiffness



		var displacement = dist - rest_length
		var spring_force = dir * (effective_stiffness * displacement)
		var rel_vel = hooked_object.linear_velocity - ship.linear_velocity
		var vel_along_dir = rel_vel.dot(dir)
		var damping_force = -damping * vel_along_dir * dir
		hooked_object.apply_central_force(spring_force + damping_force)



		# --- Orbit brake: damp sideways velocity ---
		var facing = Vector2.RIGHT.rotated(ship.rotation)
		var tangent = Vector2(-facing.y, facing.x)
		var side_vel = rel_vel.dot(tangent)
		var brake_force = -tangent * side_vel * brake_strength
		hooked_object.apply_central_force(brake_force)

		# Whip visuals
		if is_instance_valid(hooked_object):
			var WhipOrigin = ship.global_position + Vector2.RIGHT.rotated(ship.rotation) * whip_origin_offset
			WhipBeam.points = [WhipOrigin, hooked_object.global_position]
		else:
			release_grapple()

		if dist < 2.0 and hooked_object.linear_velocity.length() < 5.0:
			hooked_object.linear_velocity = Vector2.ZERO



func get_hold_point() -> Vector2:
	var offset = hold_offset
	if hooked_object and is_instance_valid(hooked_object):
		var shape_owner_count = hooked_object.get_shape_owners().size()
		if shape_owner_count > 0:
			var shape = hooked_object.shape_owner_get_shape(0, 0)
			if shape is CircleShape2D:
				offset += shape.radius
			elif shape is RectangleShape2D:
				offset += max(shape.extents.x, shape.extents.y)
	return ship.global_position + Vector2.RIGHT.rotated(ship.rotation) * offset

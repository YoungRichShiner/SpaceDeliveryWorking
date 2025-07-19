extends Node2D



@onready var GrappleRay:= $RayCast2D
@onready var ship:= get_parent()
@onready var HoldTimer:= $Timer
@onready var WhipBeam:= $WhipBeam

var launched = false



# Tweak these in the Inspector later
@export var flick_force := 1200.0  # Quick tap = strong inward yank
@export var hold_force := 80.0     # Hold = gentle sustained pull
@export var max_distance := 1200.0  # Whip snap distance

var hooked_object: RigidBody2D = null
var is_holding := false

func _input(event):
	# 1. Press = Start Grapple
	if event.is_action_pressed("grapple"):
		if GrappleRay.is_colliding():
			var obj = GrappleRay.get_collider()
			is_holding = true
			if obj is RigidBody2D:  # Only grab physics objects
				hooked_object = obj
				HoldTimer.start()  # Start checking for hold
	
	# 2. Release = Throw or Drop
	if event.is_action_released("grapple"):
		if hooked_object:
			if HoldTimer.time_left > 0:  # TAP = Flick Inward
				var dir = (global_position - hooked_object.position).normalized()
				hooked_object.apply_central_impulse(dir * flick_force)
			else:  # HOLD RELEASE = Just drop
				pass
			release_grapple()

func _physics_process(delta):
	global_position = ship.global_position
	if hooked_object and is_holding:
		# Check if hooked_object is still valid and in the scene
		if not is_instance_valid(hooked_object) or not hooked_object.get_parent():
			release_grapple()
			return

		# Keep object within max distance
		var obj_pos = hooked_object.position
		var obj_global = hooked_object.global_position

		var dist = global_position.distance_to(obj_pos)
		if dist > max_distance:
			release_grapple()  # Snap if too far
			return

		# Apply pull force
		var dir = (global_position - obj_pos).normalized()
		hooked_object.apply_central_impulse(dir * hold_force * delta * 60)

		# Update whip line visuals
		if is_instance_valid(hooked_object):
			WhipBeam.points = [global_position, obj_global]
		else:
			release_grapple()

func release_grapple():
	hooked_object = null
	is_holding = false
	WhipBeam.points = []  # Hide whip line

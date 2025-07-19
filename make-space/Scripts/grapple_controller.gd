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
	if hooked_object and is_holding:
		# Keep object within max distance
		var dist = global_position.distance_to(hooked_object.position)
		if dist > max_distance:
			release_grapple()  # Snap if too far
		else:
			# Apply pull force
			var dir = (global_position - hooked_object.position).normalized()
			hooked_object.apply_central_impulse(dir * hold_force * delta * 60)
		
		# Update whip line visuals
		WhipBeam.points = [Vector2.ZERO, to_local(hooked_object.position)]

func release_grapple():
	hooked_object = null
	is_holding = false
	WhipBeam.points = []  # Hide whip line

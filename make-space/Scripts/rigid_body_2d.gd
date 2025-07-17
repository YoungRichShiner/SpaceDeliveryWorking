extends RigidBody2D

### FLIGHT CONSTANTS BITCH ###
const REVERSE_THRUST := 350.0 #put it in reverse terry
const THRUST := 570.0      # Forward/backward force
const TURN_SPEED := 2.3    # Rotation speed
const BRAKE := 650.0       # Stopping power
const TURN_DAMPING := 0.6  # 0-1 (higher = stronger counter-thrust)
const TOP_SPEED := 3250.0  # Changed to float
const TURN_SMOOTH = .3 #lower = slower AND smoother
const THRUST_RAMP_UP := 4.0 # How fast engine reaches full power (higher = faster)

### LANDING MODE CONST ###
const LANDING_SPEED = 200.0
const LANDING_BRAKE = 550.0
const ROTATION_DAMPING = 3.0

### VARIABLES ###
var _turn_smoothing := 0.0
var _thrust_input := 0.0
var _last_forward := Vector2.ZERO
var _current_thrust := 0.0

var _landing_mode := false


func _physics_process(delta):
	var forward = Vector2(cos(rotation), sin(rotation)) #Reusable forward vector YOOOOOOOO
	
	### --- LANDING MODE SECTION --- ###
	_landing_mode = Input.is_action_pressed("landing_mode")

	if Input.is_action_just_pressed("landing_mode"):
		if linear_velocity.length() > LANDING_SPEED:
			linear_velocity = linear_velocity.move_toward(Vector2.ZERO, BRAKE * delta)
			##linear_velocity = lerp(linear_velocity, LANDING SPEED, BRAKE * delta)
	if _landing_mode:
		
		# Gradually slow rotation
		angular_velocity = move_toward(angular_velocity, 0, ROTATION_DAMPING * delta)
		
		# Get input direction (screen space)
		var move_input = Vector2(
			Input.get_axis("Turn L", "Turn R"),
			Input.get_axis("Go", "Reverse")
		)
		
		# Apply braking when no input
		if move_input.length() < 0.01:
			linear_velocity = linear_velocity.move_toward(Vector2.ZERO, LANDING_BRAKE * delta)
		else:
			# Apply movement with speed limit
			linear_velocity = move_input.normalized() * min(linear_velocity.length() + LANDING_BRAKE * delta, LANDING_SPEED)
		
		return  # Skip normal flight controls
		
	
	# Forward thrust
	if Input.is_action_pressed("Go"):
		_thrust_input = lerp(_thrust_input, 1.0, THRUST_RAMP_UP * delta)
		var speed_ratio = clamp(linear_velocity.length() / TOP_SPEED, 0, 0.9)
		_current_thrust = THRUST * _thrust_input * (1 - speed_ratio)
		apply_force(forward * _current_thrust)
	else:
		_thrust_input = lerp(_thrust_input, 0.0, THRUST_RAMP_UP * delta * 0.5)
	
	# Reverse thrust
	if Input.is_action_pressed("Reverse"):
		apply_force(-forward * REVERSE_THRUST)
	
		### --- SMOOTH TURNING IMPLEMENTATION --- ###
	var turn_input = Input.get_axis("Turn L", "Turn R")
	var target_turn_speed = turn_input * TURN_SPEED 

	# Gradual turn acceleration
	angular_velocity = move_toward(angular_velocity, target_turn_speed, (TURN_SPEED * 5) * delta)

	# Physics-preserving turn handling
	if turn_input != 0:
		var forward_velocity = forward * forward.dot(linear_velocity)
		var sideways_velocity = linear_velocity - forward_velocity
		apply_force(-sideways_velocity * TURN_DAMPING * delta)
		linear_velocity = forward_velocity + sideways_velocity * 0.95
	else:
		# Natural rotation damping
		angular_velocity = move_toward(angular_velocity, 0, TURN_DAMPING * 0.5 * delta)


	# Brake
	if Input.is_action_pressed("ui_accept"):
		linear_velocity = linear_velocity.move_toward(Vector2.ZERO, BRAKE * delta)
		angular_velocity = move_toward(angular_velocity, 0.0, BRAKE * delta)
	
	_last_forward = forward
	

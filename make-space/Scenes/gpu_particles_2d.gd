extends GPUParticles2D

@onready var particle_light := PointLight2D.new()

func _ready():
	# Configure light
	particle_light.texture = preload("res://Assets/new_gradient_texture_2d.tres")  # 16x16 white circle
	particle_light.energy = 1.5
	particle_light.scale = Vector2(0.3, 0.3)  # Smaller light
	add_child(particle_light)

func _process(delta):
	# Sync light position/visibility with particles
	particle_light.enabled = emitting
	particle_light.global_position = global_position

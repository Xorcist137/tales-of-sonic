extends Node3D

@onready var particles = $GPUParticles3D

func _ready():
	pass
	

func _process(delta):
	# Rotate the particle system
	particles.rotate_y(delta)  # Adjust rotation speed as needed

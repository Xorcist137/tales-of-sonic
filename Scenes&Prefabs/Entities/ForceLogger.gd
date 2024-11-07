extends Node

class_name ForceLogger

@onready var rigid_body: RigidBody3D = $"../"
var forces: Dictionary = {}

func _ready():
	rigid_body = get_parent()
	if not rigid_body is RigidBody3D:
		push_error("ForceLogger must be a child of a RigidBody3D")
		queue_free()

func log_force(force_name: String, force: Vector3):
	forces[force_name] = force

func clear_forces():
	forces.clear()

func _physics_process(delta):
	# Log the total force applied this frame
	var total_force = rigid_body.get_applied_force()
	log_force("Total Applied Force", total_force)

	# Log gravity
	var gravity = rigid_body.gravity_scale * rigid_body.get_gravity()
	log_force("Gravity", gravity)

	# Print all logged forces
	print("Forces applied this frame:")
	for force_name in forces:
		print(force_name + ": " + str(forces[force_name]))
	
	print("Current Velocity: " + str(rigid_body.linear_velocity))
	print("---")

	# Clear forces for the next frame
	clear_forces()

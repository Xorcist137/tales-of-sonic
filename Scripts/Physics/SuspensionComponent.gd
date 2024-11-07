extends RayCast3D
class_name SuspensionComponent

# Licensed under MIT

# This class is responsible for providing suspension for the Rigidbody

##@export var suspension_model_path: MeshInstance3D
##@export var player_body_path: RigidBody3D

@onready var suspension_model: Node3D = $"Reference"
@onready var movement_manager: Node3D = $"../BoomMovementStateComponent"
@onready var animation_player = $"AnimationPlayer"
@onready var player_body: RigidBody3D = $".."
@export var suspension_strength: float = 12000
@export var suspension_damping: float = 600
@export var downforce_mul: float = 0.8
@export var suspension_length: float = 2
@export var ride_height: float = 1.25
@export var allow_jumping: bool = true
@export var visual_offset: float = 0.25

@onready var controls: Controls = $"/root/GameControls"
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@onready var target_basis: Basis = suspension_model.global_transform.basis

var ground_direction: Vector3 = -Vector3.UP
var velocity: Vector3 = Vector3.ZERO
var prev_direction: Vector3 = Vector3.FORWARD
var facing_direction: Vector3 = Vector3.FORWARD
var just_jumped: bool = false
var jump_timer: float = 0.0

var grounded_frames: int = 0
var airborne_frames: int = 0
const GROUNDED_THRESHOLD: int = 2
const AIRBORNE_THRESHOLD: int = 2

signal suspension_force
signal suspension_velocity
signal touching_ground
signal not_touching_ground

func manage_ground() -> Vector3:
	target_position = -get_collision_normal() * suspension_length
	return -get_collision_normal()
	
func align_with_ground_normal(input_basis: Basis, normal: Vector3) -> Basis:
	input_basis.y = normal
	input_basis.x = -input_basis.z.cross(input_basis.y)
	input_basis = input_basis.orthonormalized()
	return input_basis

func ground_suspension() -> void:
	var ground_normal = -manage_ground()
	var current_ride_height: float = global_position.distance_to(get_collision_point())
	var suspension_offset = ride_height - current_ride_height
	var suspension_force = 0
	suspension_force = suspension_offset * suspension_strength
	suspension_force -= player_body.get_linear_velocity().dot(get_collision_normal()) * suspension_damping
	
	if is_colliding:
		controls.ground_normal = ground_normal
		spatial_vars.ground_normal = ground_normal
	
	suspension_model.position = position - (get_collision_normal() * (current_ride_height * 0.75 + visual_offset) )
	#target_basis = align_with_ground_normal(suspension_model.global_transform.basis, ground_normal)
	player_body.apply_central_force(ground_normal * suspension_force)
	
	if current_ride_height < 0.75 :
		player_body.set_axis_velocity(ground_normal * 1)
	if current_ride_height > 1.7:
		player_body.set_axis_velocity(-ground_normal * 1)
	# Apply ground transition factor
	#suspension_model.global_transform.basis = suspension_model.global_transform.basis.slerp(target_basis, 0.5)
	#suspension_model.global_transform

func jump() -> void:
	jump_timer = 0.2  # Adjust this value as needed
	target_position = Vector3(0, 1, 0)
	grounded_frames = 0
	airborne_frames = AIRBORNE_THRESHOLD

func air() -> void:
	target_position = Vector3(0, -1, 0) * (suspension_length * 0.5)
	suspension_model.position = position - (position + Vector3(0, 0.5, 0))
	ground_direction = Vector3(0, -1, 0)
	controls.ground_normal = Vector3(0, 1, 0)
	# Apply air transition factor
	

func _ready():
	controls.jump_pressed.connect(_on_controls_jump_pressed.bind())
	pass # Replace with function body.


func _physics_process(delta):
	if is_colliding():
		grounded_frames += 1
		airborne_frames = 0
		
		if grounded_frames >= GROUNDED_THRESHOLD:
			if not spatial_vars.grounded:
				emit_signal("touching_ground", -get_collision_normal())
				spatial_vars.grounded = true
		
		if jump_timer > 0:
			jump_timer -= delta
		else:
			ground_suspension()
	else:
		airborne_frames += 1
		grounded_frames = 0
		
		if airborne_frames >= AIRBORNE_THRESHOLD:
			if spatial_vars.grounded:
				emit_signal("not_touching_ground", Vector3(0, -1, 0))
				spatial_vars.grounded = false
		
		air()
	
	update_facing_direction()
	
func update_facing_direction(force_direction: Vector3 = Vector3.ZERO) -> void:
	var target_direction: Vector3
	var interpolation_speed = 0.2
	var up_direction: Vector3
	
	if force_direction.length() > 0:
		# Use the forced direction if provided
		if is_colliding():
			# If grounded, ignore vertical component
			force_direction.y = 0
			if force_direction.length() > 0:
				target_direction = force_direction.normalized()
			else:
				target_direction = prev_direction.normalized()
		else:
			target_direction = force_direction.normalized()
		interpolation_speed = 0.4  # Faster interpolation for forced direction
	else:
		# Use velocity-based direction if no forced direction
		var velocity = player_body.get_linear_velocity()
		if controls.ground_normal != Vector3.ZERO:
			velocity = velocity - controls.ground_normal * velocity.dot(controls.ground_normal)
		
		if velocity.length() > 0.2:
			target_direction = velocity.normalized()
			prev_direction = velocity
		else:
			target_direction = prev_direction.normalized()
	# Determine up direction based on whether the player is grounded or not
	if is_colliding():
		up_direction = -get_collision_normal()
	else:
		up_direction = Vector3.DOWN
	
	# Calculate the right direction and create the adjusted basis
	var right_direction = up_direction.cross(target_direction).normalized()
	var adjusted_target_basis = Basis(
		target_direction,
		right_direction.cross(target_direction).normalized(),
		right_direction
	)
	
	# Apply the rotation using slerp
	suspension_model.global_transform.basis = suspension_model.global_transform.basis.slerp(
		adjusted_target_basis,
		interpolation_speed
	).orthonormalized()
	
	facing_direction = target_direction

func _on_controls_jump_pressed() -> void:
	if movement_manager.can_jump:
		just_jumped = true

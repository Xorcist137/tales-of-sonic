extends Node3D
class_name Mouse3rdPersonCam

@export var player_node_path: Node3D
@export var springarm_path: SpringArm3D
@export var spring_arm_length_normal: float = 8.0
@export var spring_arm_length_boosted: float = 12.0
@export var spring_arm_length_drift: float = 7.0
@export var controller_sensitivity: float = 0.25
@export var mouse_sensitivity: float = 0.001
@export var camera_rotation_speed: float = 2.0
@export var moving_camera_sensitivity_multiplier: float = 0.5
@export var min_velocity_threshold: float = 40
@export var offset_smoothing: float = 4.0
@export var max_boost_speed: float = 151.0
@export var max_extended_spring_length: float = 25.0
@export var spring_length_velocity_factor: float = 0.12
@export var drift_tilt_angle: float = 5.0
@export var drift_tilt_speed: float = 3.0
@export var fov_normal: float = 75.0
@export var fov_boosted: float = 85.0
@export var vertical_offset: float = 3.0  # Increased from 2.0 to 3.0
@export var vertical_velocity_factor: float = 0.035
@export var horizontal_offset_factor: float = 0.05
@export var max_horizontal_offset: float = 8.0
@export var max_vertical_offset: float = 5.0
@export var max_vertical_speed_for_offset: float = 100.0
@export var slope_threshold_angle: float = 30.0
@export var min_vertical_angle: float = -60.0
@export var max_vertical_angle: float = 60.0

@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var player_node: Node3D = player_node_path
@onready var player_body: RigidBody3D = $"../Player"
@onready var springarm: SpringArm3D = $"SpringArm3D"
@onready var controls: GameControls = $"/root/GameControls"
@onready var alignment_funcs: AlignmentStatics = $"/root/AlignmentStatics"
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@onready var boost_manager: Node3D = $"../Player/BoomMovementStateComponent"

var up_axis: Vector3 = Vector3.UP
var right_axis: Vector3 = Vector3.RIGHT
var target_spring_length: float = spring_arm_length_normal
var is_player_moving: bool = false
var player_movement_direction: Vector3 = Vector3.ZERO
var is_player_drifting: bool = false
var current_right_offset: float = 0.0
var target_right_offset: float = 0.0
var shake_amount: float = 0
var shake_duration: float = 0
var shake_timer: float = 0
var current_drift_tilt: float = 0.0
var target_drift_tilt: float = 0.0
var target_fov: float = fov_normal
var current_tilt: float = 0.0
var current_vertical_offset: float = 0.0

func _ready():
	springarm.spring_length = spring_arm_length_normal
	if player_body:
		springarm.add_excluded_object(player_body.get_rid())
	var stomp_ability = get_node("../Player/StompAbility")
	if stomp_ability:
		stomp_ability.connect("camera_shake_requested", Callable(self, "start_shake"))

func cam_input(_delta):
	var sensitivity = controller_sensitivity
	if is_player_moving:
		sensitivity *= moving_camera_sensitivity_multiplier

	self.transform.basis = self.transform.basis.rotated(up_axis, -controls.cam_input.x * 0.1 * sensitivity)
	springarm.rotation.x -= controls.cam_input.y * 0.1 * sensitivity
	springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-60), deg_to_rad(45))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		var sensitivity = mouse_sensitivity
		if is_player_moving:
			sensitivity *= moving_camera_sensitivity_multiplier

		self.transform.basis = self.transform.basis.rotated(up_axis, -event.relative.x * sensitivity)
		springarm.rotation.x = clamp(springarm.rotation.x, deg_to_rad(-60), deg_to_rad(45))
		springarm.rotate_x(-event.relative.y * sensitivity)

func _process(delta):
	update_axes()
	update_camera_position(delta)

	var player_velocity = player_body.get_linear_velocity()
	is_player_moving = player_velocity.length() > min_velocity_threshold
	is_player_drifting = boost_manager.is_drifting

	if is_player_moving:
		player_movement_direction = player_velocity.normalized()
	update_drift_tilt(delta)
	update_spring_length(player_velocity, delta)
	update_alignment(delta)

	cam_input(delta)
	controls.wish_dir_basis = transform.basis
	apply_shake(delta)
	update_camera_fov(delta)
	
func update_camera_fov(delta):
	if controls.is_boost_pressed:
		target_fov = fov_boosted
	else:
		target_fov = fov_normal
	
	camera.fov = lerp(camera.fov, target_fov, delta * 5.0)
func update_axes():
	up_axis = self.transform.basis.y
	right_axis = self.transform.basis.x

func update_camera_position(delta):
	var player_velocity = player_body.get_linear_velocity()

	# Calculate the angle between the ground normal and the world's up vector
	var ground_normal = controls.ground_normal
	var angle_with_up = rad_to_deg(acos(ground_normal.dot(Vector3.UP)))

	# Calculate vertical offset based on velocity only if the ground normal is less than 30 degrees
	var vertical_velocity = player_velocity.y
	var additional_height = 0.0
	if angle_with_up <= slope_threshold_angle:
		additional_height = clamp(vertical_velocity * vertical_velocity_factor, -max_vertical_offset, max_vertical_offset)
	
	# Interpolate the vertical offset for smoother movement
	current_vertical_offset = lerp(current_vertical_offset, additional_height, delta * offset_smoothing)

	# Calculate horizontal offset based on velocity
	var horizontal_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
	var horizontal_speed = horizontal_velocity.length()
	var vertical_speed = abs(player_velocity.y)
	
	# Default offsets to zero when the player is not moving
	target_right_offset = 0.0
	
	if is_player_moving:
		if abs(player_movement_direction.dot(up_axis)) < 0.99:
			var target_basis = Basis().looking_at(player_movement_direction, up_axis)
			if is_player_drifting:
				transform.basis = transform.basis.slerp(target_basis, camera_rotation_speed * delta * 2)
				target_right_offset = controls.input_dir.x * 5
			else:
				transform.basis = transform.basis.slerp(target_basis, camera_rotation_speed * delta / 2)
		else:
			target_right_offset = 0.0

		# Add horizontal velocity-based offset
		var velocity_based_offset = horizontal_velocity.normalized().dot(transform.basis.x) * horizontal_speed * horizontal_offset_factor
		
		# Apply a dampening factor based on vertical speed
		var vertical_speed_factor = clamp(1.0 - (vertical_speed / max_vertical_speed_for_offset), 0.0, 1.0)
		velocity_based_offset *= vertical_speed_factor
		
		target_right_offset += clamp(velocity_based_offset, -max_horizontal_offset, max_horizontal_offset)
	
	# Interpolate horizontal offset for smoother movement
	current_right_offset = lerp(current_right_offset, target_right_offset, delta * offset_smoothing)
	
	# Combine the offsets and update the camera position
	var final_offset = transform.basis.y * (vertical_offset + current_vertical_offset) + transform.basis.x * current_right_offset
	position = player_body.position + final_offset


func update_spring_length(player_velocity: Vector3, delta):
	var speed = player_velocity.length()
	var vertical_speed = abs(player_velocity.y)
	
	if speed > max_boost_speed:
		target_spring_length = spring_length_velocity_factor * speed
	else:
		target_spring_length = spring_arm_length_boosted if controls.is_boost_pressed else spring_arm_length_normal
	
	if is_player_drifting:
		target_spring_length = spring_arm_length_drift
	
	# Adjust spring length based on vertical speed
	target_spring_length += vertical_speed * vertical_velocity_factor
	
	springarm.spring_length = lerp(springarm.spring_length, min(target_spring_length, max_extended_spring_length), 0.5 * delta)
	
func update_alignment(_delta):
	var ground_normal = controls.ground_normal
	var angle_with_up = rad_to_deg(acos(ground_normal.dot(Vector3.UP)))
	
	if angle_with_up > slope_threshold_angle:
		var alignment = alignment_funcs.basis_aligned_y(transform.basis, ground_normal)
		transform.basis = transform.basis.slerp(alignment, 0.015)
	else:
		# Gradually return to upright position when on flat ground
		var upright_basis = alignment_funcs.basis_aligned_y(transform.basis, Vector3.UP)
		transform.basis = transform.basis.slerp(upright_basis, 0.015)
		
func update_right_offset(delta):
	var player_velocity = player_body.get_linear_velocity()
	var horizontal_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
	var horizontal_speed = horizontal_velocity.length()
	var vertical_speed = abs(player_velocity.y)
	
	if is_player_moving:
		if abs(player_movement_direction.dot(up_axis)) < 0.99:
			var target_basis = Basis().looking_at(player_movement_direction, up_axis)
			if is_player_drifting:
				transform.basis = transform.basis.slerp(target_basis, camera_rotation_speed * delta * 2)
				target_right_offset = controls.input_dir.x * 5
			else:
				transform.basis = transform.basis.slerp(target_basis, camera_rotation_speed * delta / 2)
				target_right_offset = 0
		else:
			pass
	else:
		target_right_offset = 0
	
	# Add horizontal velocity-based offset
	var velocity_based_offset = horizontal_velocity.normalized().dot(transform.basis.x) * horizontal_speed * horizontal_offset_factor
	
	# Apply a dampening factor based on vertical speed
	var vertical_speed_factor = clamp(1.0 - (vertical_speed / max_vertical_speed_for_offset), 0.0, 1.0)
	velocity_based_offset *= vertical_speed_factor
	
	target_right_offset += clamp(velocity_based_offset, -max_horizontal_offset, max_horizontal_offset)
	
	current_right_offset = lerp(current_right_offset, target_right_offset, delta * offset_smoothing)
	var right_offset = transform.basis.x * current_right_offset
	
	# Update the camera's position with the right offset
	position = player_body.position + transform.basis.y * vertical_offset + right_offset

func apply_shake(delta):
	if shake_timer > 0:
		shake_timer -= delta
		
		var shake_offset = Vector3(randf(), randf(), randf()) * 2 - Vector3.ONE
		shake_offset = shake_offset.normalized() * shake_amount
		position += shake_offset
		
		if shake_timer <= 0:
			shake_amount = 0

func update_drift_tilt(delta):
	if is_player_drifting:
		# Determine the drift direction
		var drift_direction = sign(boost_manager.last_drift_direction)
		target_drift_tilt = drift_tilt_angle * drift_direction
	else:
		target_drift_tilt = 0.0
	
	# Smoothly interpolate to the target tilt
	current_drift_tilt = lerp(current_drift_tilt, target_drift_tilt, drift_tilt_speed * delta)
	
	# Apply the tilt rotation
	springarm.rotation.z = deg_to_rad(current_drift_tilt)

func start_shake(amount: float, duration: float):
	shake_amount = amount
	shake_duration = duration
	shake_timer = duration

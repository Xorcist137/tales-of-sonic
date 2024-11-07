extends Node
class_name MovementForcesComponent

@onready var controls: Controls = $"/root/GameControls"
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@onready var hud_vars: HUDStatics = $"/root/HudStatics"
@onready var targeting_system: RayCast3D = $"../TargetManager"
@onready var boost_state_manager: Node3D = $"../BoomMovementStateComponent"
@export var jump_allowed: bool = true
@onready var player_body: RigidBody3D = $".."
@onready var player_model: RayCast3D = $"../SuspensionComponent"
@onready var circle_slash: Node3D = $"../SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/SwordFX/circle_slash"
@onready var abilities: AbilitySystem = $"/root/Abilities"
# These can be modified by a MovementStateComponent, or used on their own
var wish_dir: Vector3 = Vector3.ZERO
var drag_coefficient: float = 0.4
var drag_area: float = 0.5
var air_density: float = 1.225
var traction_base: float = 2500
var air_control: float = 1250
var top_speed_base: float = 30
var slope_accel_multiplier: float = 0
var slope_jump_mul: float = 1
var jump_force_base: float = 40
var accel: float = 300
var downforce_mul: float = 0.8
var min_speed: float = 5.0
var max_vertical_velocity: float = 65.0
# for the love of all that is holy do not set this to 0
var friction: float = 100
var turn_radius: float = 0.0
# these are variables whose values fluctuate on player input
var slip_angle_scalar: float = 0
var slip_angle_degrees: float = 0
var total_speed: float = 0
var ground_plane_speed: float = 0
var movement_resistance: float = 0
var drag: float = 0
var accel_curve_point: float = 0
var downforce: float = 0
var ground_direction: Vector3 = Vector3(0, -1, 0)
var force_direction: Vector3 = Vector3.ZERO
var launch_direction: Vector3 = Vector3.ZERO
var air_moving: bool = false
var previous_angle_with_up = 0.0
var angle_with_up_deg = 0.0
var is_boosting = false
var time_since_jump: float = 0.0
var jump_grace_period: float = 0.2  # 0.2 seconds before applying the cap
var grounded_time: float = 0.0
var required_ground_time: float = 0.2  # Adjust this value as needed
var previous_grounded_state: bool = false

signal set_airborne
# Called when the node enters the scene tree for the first time.
func _ready():
	update_global_movement_vars()
	 # Replace with function body.

func update_global_movement_vars() -> void:
	wish_dir = controls.wish_dir
	total_speed = player_body.get_linear_velocity().length()
	movement_resistance = total_speed * 2 + 100
	drag = \
		drag_coefficient * ( air_density * \
		( (total_speed * total_speed) / 2 ) * \
		drag_area )
	accel_curve_point = clampf(ground_plane_speed, 1, top_speed_base) / top_speed_base
	slip_angle_degrees = rad_to_deg(acos(slip_angle_scalar))
	if spatial_vars.grounded:
		hud_vars.current_speed = total_speed
	else:
		hud_vars.current_speed = \
			( player_body.get_linear_velocity() * Vector3(1, 0, 1) ).length()

func apply_accel(base_speed, top_speed: float, acceleration: float, slope_mul: float, mask_direction: Vector3) -> void:
	if wish_dir.length() > 0.1:
		player_body.linear_damp = 0
		if player_body.get_linear_velocity().length() < base_speed and !is_boosting and spatial_vars.grounded:
			launch(wish_dir * base_speed)
			
	else:
		if player_body.get_linear_velocity().length() < base_speed and is_boosting and spatial_vars.grounded:
			launch(player_model.facing_direction * base_speed)
		if air_moving:
			player_body.linear_damp = 0
		else:
			player_body.linear_damp = 1.5
	
	top_speed *= 1 + (Vector3(0, -1, 0).dot(wish_dir) * slope_mul)
	
	if player_body.get_linear_velocity().length() < top_speed:
		acceleration *= 1.5 + (Vector3(0, -1, 0).dot(wish_dir) * slope_mul)
		player_body.apply_central_force(wish_dir * acceleration)
	else:
		if wish_dir.length() > 0.1:
			# mass divided by 10 here is just a magic number I found in testing.
			# friction is just a value I use to determine how much momentum is preserved
			# drag will be a better term
			# but I'm gonna wait until I refactor because it's still in use for another thing rn
			player_body.apply_central_force(\
				player_body.get_linear_velocity().normalized() * \
				( player_body.get_linear_velocity().length() * (player_body.mass / 10) ) \
				* 1/friction )
		# this is so slopes can still affect player movement even if over top speed
		player_body.apply_central_force(\
			player_body.get_linear_velocity().normalized() * \
			( (Vector3(0, -1, 0)\
				.dot(player_body.get_linear_velocity().normalized() * mask_direction) \
				* slope_mul) * accel ) )

func apply_grip(compensation: bool, traction: float, mask_direction: Vector3) -> void:
	var slippage = (slip_angle_scalar + 1) * (slip_angle_scalar + 1)
	var grip = traction
	grip *= ( -0.125 * ( slippage * slippage ) + (0.75 * slippage) )
	grip += 0.25 * traction
	grip *= turn_radius / (player_body.get_linear_velocity().length() / top_speed_base)
	grip *= clampf(player_body.get_linear_velocity().length(), 1, 400) / 50

	if not spatial_vars.grounded:
		# Only affect horizontal movement in air to prevent unintended rising
		var horizontal_wish_dir = Vector3(wish_dir.x, 0, wish_dir.z).normalized()
		var horizontal_velocity = Vector3(player_body.get_linear_velocity().x, 0, player_body.get_linear_velocity().z)

		if slip_angle_scalar != 1 and wish_dir.length() > 0.1:
			var correction_dir = horizontal_wish_dir - horizontal_velocity.normalized()
			player_body.apply_central_force(correction_dir * grip)
			if compensation:
				player_body.apply_central_force(horizontal_wish_dir * (horizontal_wish_dir.dot(correction_dir) * grip))
	else:
		# Original grip logic when grounded
		if slip_angle_scalar != 1 and wish_dir.length() > 0.1:
			var correction_dir = wish_dir.normalized() - (player_body.get_linear_velocity() * mask_direction).normalized()
			player_body.apply_central_force(correction_dir * grip)
			if compensation:
				player_body.apply_central_force(wish_dir.normalized() * (wish_dir.normalized().dot(correction_dir) * grip))


func apply_drag() -> void:
	var speed = player_body.get_linear_velocity().length()
	var stop_threshold = 5.0  # Adjust this value to set the speed below which the player will stop
	
	if wish_dir.length() < 0.1 and speed < stop_threshold:
		# If no movement input and speed is below threshold, stop the player
		player_body.set_linear_velocity(Vector3.ZERO)
	#else:
	#	# Apply regular drag force
	#	player_body.apply_central_force( \
	#		-((player_body.get_linear_velocity().normalized() * \
	#		mask_direction.normalized()) * \
	#		current_drag))
	#	
	#	# Apply additional resistance when not moving
	#	if controls.wish_dir.length() == 0:
	#		player_body.apply_central_force( \
	#			-( (player_body.get_linear_velocity().normalized() * \
	#			mask_direction.normalized()) * \
	#			movement_resistance))

func jump(slope_mul: float) -> void:
	boost_state_manager.end_drift(false)
	var slope_effect = Vector3(0, 1, 0).dot(wish_dir) * slope_mul
	var jump_force = clampf(
		jump_force_base * (1 + slope_effect),  # Reduced multiplier
		jump_force_base,
		jump_force_base * 3  # Lowered maximum multiplier
	)
	player_body.set_axis_velocity(spatial_vars.ground_normal * jump_force)
	time_since_jump = 0.0

func end_jump() -> void:
	pass
	#if player_body.get_linear_velocity().y > jump_force_base / 2:
		#player_body.set_axis_velocity(Vector3.UP * player_body.get_linear_velocity().y * 0.75)

func launch(velocity: Vector3) -> void:
	player_body.set_axis_velocity(velocity)

func ground_move() -> void:
	var rising_slash = abilities.get_ability("rising_slash")
	var far_slash = abilities.get_ability("far_slash")
	var ground_slash = abilities.get_ability("ground_slash")
	var run_slash = abilities.get_ability("run_slash")
	var air_attack = abilities.get_ability("air_attack")
	if grounded_time >= required_ground_time:
		rising_slash.reset_usage()
	
	if controls.is_rise_pressed and rising_slash.can_use() and !abilities.is_any_ability_active(): 
		rising_slash.use()
	elif controls.is_far_pressed and far_slash.can_use() and !abilities.is_any_ability_active():
		far_slash.use()
	elif controls.is_attack_pressed:
		if air_attack.can_use() and !abilities.is_any_ability_active():
			air_attack.use()
		elif total_speed >= 40:
			if run_slash.can_use() and !abilities.is_any_ability_active():
				run_slash.use()
		else:
			if ground_slash.can_use() and !abilities.is_any_ability_active():
				ground_slash.use()
			else:
				ground_slash.input_attack()
	air_moving = false
	# Set the calculated gravity scale
	player_body.set_gravity_scale(0.8)
	ground_plane_speed = total_speed
	
	# Use the actual ground normal from spatial_vars
	var ground_normal = controls.ground_normal.normalized()
	# World 'up' direction
	var world_up = Vector3.UP

	# Calculate the angle between the ground normal and the world up vector
	var dot_product = player_model.get_collision_normal().dot(world_up)
	previous_angle_with_up = angle_with_up_deg
	var angle_with_up = acos(clamp(dot_product, -1.0, 1.0))
	angle_with_up_deg = rad_to_deg(angle_with_up)
	# Define the speed threshold and angle threshold for going airborne
	var speed_threshold = 35.0  # Player speed below which airborne logic triggers
	var angle_threshold = 75  # Angle above which airborne logic triggers
	var score = 1 - (angle_with_up_deg)/120 + ground_plane_speed/100
	if score <= 0.5 or abs(previous_angle_with_up - angle_with_up_deg) > 45:
		emit_signal("set_airborne")
		var launch_direction = player_model.get_collision_normal()
		# Clamp the y component to ensure no upward launch
		launch_direction.y = min(launch_direction.y, 0)
		# Normalize the vector again to maintain the magnitude
		if launch_direction != Vector3.ZERO:
			launch_direction = launch_direction.normalized()
		launch(launch_direction * 25)
		var current_velocity = player_body.get_linear_velocity()
		current_velocity.y = min(current_velocity.y, 0)
		player_body.set_linear_velocity(current_velocity)
		return
	slip_angle_scalar = \
		player_body.get_linear_velocity().normalized().dot(wish_dir)
	
	apply_accel(min_speed, top_speed_base, accel, slope_accel_multiplier, Vector3(1, 1, 1))
	apply_grip(true, traction_base, Vector3(1, 1, 1))
	apply_drag()

func air_move() -> void:
	previous_angle_with_up = 0.0
	angle_with_up_deg = 0.0
	air_moving = true
	var air_attack = abilities.get_ability("air_attack")
	var rising_slash = abilities.get_ability("rising_slash")
	var stomp = abilities.get_ability("stomp")
	var far_slash = abilities.get_ability("far_slash")
	var air_slash = abilities.get_ability("air_slash")
	if controls.is_attack_pressed and !abilities.is_any_ability_active():
		if air_attack.can_use():
			air_attack.use()
		elif air_slash.can_use():
			air_slash.use()
	elif controls.is_rise_pressed and rising_slash.can_use() and !abilities.is_any_ability_active():
		rising_slash.use()
	elif controls.is_stomp_pressed and stomp.can_use() and !abilities.is_any_ability_active():
		stomp.use()
	elif controls.is_far_pressed and far_slash.can_use() and !abilities.is_any_ability_active():
		far_slash.use()
	
	if not air_attack.is_active:
		if Input.is_action_pressed("jump"):
			player_body.set_gravity_scale(1.0)
		else:
			player_body.set_gravity_scale(2.0)
		
		ground_plane_speed = (player_body.get_linear_velocity() * Vector3(1, 0, 1)).length()
		slip_angle_scalar = (player_body.get_linear_velocity() * Vector3(1, 0, 1)).normalized().dot(wish_dir)
		downforce = drag * downforce_mul
		
		apply_accel(0, top_speed_base, accel, slope_accel_multiplier, Vector3(1, 0, 1))
		apply_grip(true, air_control, Vector3(1, 0, 1))
		
		if player_body.get_linear_velocity().dot(ground_direction) < 0:
			player_body.apply_central_force(ground_direction * downforce)
		
#
func _physics_process(delta):
	update_global_movement_vars()
	time_since_jump += delta
	
	if spatial_vars.grounded:
		if previous_grounded_state:
			grounded_time += delta
		else:
			grounded_time = 0.0
	else:
		grounded_time = 0.0
	
	previous_grounded_state = spatial_vars.grounded
	
	if time_since_jump > jump_grace_period:
		var current_velocity = player_body.get_linear_velocity()
		if current_velocity.y > max_vertical_velocity and !spatial_vars.grounded and !abilities.is_any_ability_active():
			player_body.set_linear_velocity(Vector3(current_velocity.x, max_vertical_velocity, current_velocity.z))

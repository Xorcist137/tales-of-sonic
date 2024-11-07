extends "res://Scripts/Physics/MovementStateComponent.gd"
class_name BoomMovementStateComponent

@export var can_buffer_jump: bool = true
@export var top_speed: float = 90
@export var top_speed_boost: float = 150
@export var accel: float = 300
@export var accel_boost: float = 600
@export var base_jump_force: float = 16
@export var boost_speed: float = 75
@export var drag_coefficient: float = 0.4
@export var drag_coefficient_boosting: float = 0.2
@export var air_density: float = 1.225
@export var frontal_area: float = 0.5
@export var frontal_area_boosting: float = 0.25
@export var base_slope_accel_mul: float = 1.2
@export var slope_accel_mul_sprint: float = 0
@export var downforce_mul: float = 0.8
@export var downforce_mul_boost: float = 0
@export var normal_turn_rate: float = 0.6
@export var boost_turn_rate: float = 0.1  # Adjust this value to make turning while boosting more difficult
##@export var player_body_path: RigidBody3D
##@export var boost_manager_path: BoostManager
@export var drift_top_speed: float = 60


@onready var player_body: RigidBody3D = $".."
@onready var suspension_model = $"../SuspensionComponent"
@onready var boost_manager: BoostManager = $"../BoostManagerComponent"
@onready var abilities: Node = $"/root/Abilities"

var drift_cooldown_timer: float = 0.0
var drift_cooldown_duration: float = 0.5  # 0.5 second cooldown
var drift_start_time: float = 0.0
var min_drift_time: float = 0.85  # Minimum drift time in seconds
var is_drifting: bool = false
var reached_min_drift: bool = false
var trail_material: BaseMaterial3D
var fade_duration = 0.5  # Time in seconds for the fade effect
var current_fade_time = 0.0
var is_fading_in = false
var is_fading_out = false
var transparent_color = Color(1,1,1,0)
var semi_transparent_color = Color(1,1,1,0.75)
var last_drift_direction: float = 0.0
var drift_grace_timer: float = 0.0
var current_drift_duration: float = 0.0
var succeeded: bool = false
const DRIFT_GRACE_PERIOD: float = 0.25  # 0.5 seconds grace period

enum BoostState {
	NORMAL = 0,
	BOOST = 1
}

var boost_state_prev = BoostState.NORMAL
var boost_state = BoostState.NORMAL
var can_boost: bool = true
var can_jump: bool = false


signal boost_state_changed
signal just_jumped

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	movement_forces_component.air_density = air_density
	
	trail_material = load("res://Scenes&Prefabs/Entities/wind.tres")
	if trail_material:
		trail_material.albedo_color = transparent_color
	else:
		push_warning("Failed to load wind.tres material")

func initialize_abilities():
	var air_attack = abilities.get_ability("air_attack")
	if air_attack:
		if air_attack.has_signal("attack_started") and air_attack.has_signal("attack_ended"):
			air_attack.connect("attack_started", Callable(self, "_on_air_attack_started"))
			air_attack.connect("attack_ended", Callable(self, "_on_air_attack_ended"))
			print("Air attack ability connected successfully")
		else:
			push_warning("AirAttackAbility does not have required signals.")
	else:
		push_warning("AirAttackAbility not found in the ability system.")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	super(delta)
	boost_state_prev = boost_state
	if controls.is_boost_pressed and can_boost:
		boost_state = BoostState.BOOST
	else:
		boost_state = BoostState.NORMAL
	
	if boost_state_prev != boost_state:
		emit_signal("boost_state_changed", boost_state, boost_state_prev)
		if boost_state == BoostState.BOOST:
			boost_state_just_boosted()
			start_fade_in()
		else:
			start_fade_out()	
	if drift_cooldown_timer > 0:
		drift_cooldown_timer -= delta
	if spatial_vars.grounded and controls.is_drift_pressed and abs(controls.input_dir.x) > 0.1 and player_body.get_linear_velocity().length() >= 40 and drift_cooldown_timer <= 0:
		if !is_drifting:
			start_drift()
		else:
			check_drift_direction()
			update_drift_status()
	elif (!controls.is_drift_pressed or player_body.get_linear_velocity().length() <= 40) and is_drifting:
		if reached_min_drift:
			end_drift(true)
		else:
			end_drift(false)
	if is_drifting and abs(controls.input_dir.x) < 0.1:
		drift_grace_timer = DRIFT_GRACE_PERIOD
		update_drift_status()
	# Decrement grace timer
	if drift_grace_timer > 0:
		drift_grace_timer -= delta
	match boost_state:
		BoostState.NORMAL:
			boost_state_normal()
		BoostState.BOOST:
			boost_state_boost()
	
	# Apply drift modifications if drifting
	if is_drifting:
		apply_drift_modifications()
		apply_drift_slide()
	process_fade(delta)
	
	if controls.is_jump_pressed and can_jump:
		emit_signal("just_jumped")
		can_jump = false
	if spatial_vars.grounded and !controls.is_jump_pressed:
		#print("grounded")
		can_jump = true
	if abilities.is_any_ability_active():
		can_jump = false

func boost_state_just_boosted():
	var facing_direction = suspension_model.facing_direction # Get the direction from the other script
	# Apply the boost in the facing direction
	if player_body.get_linear_velocity().dot(facing_direction) < top_speed_boost:
		if spatial_vars.grounded:
			movement_forces_component.launch(facing_direction * top_speed_boost)
		else:
			movement_forces_component.launch(facing_direction * top_speed_boost * 0.8)
	boost_manager.just_boosted()

func start_drift():
	is_drifting = true
	reached_min_drift = false  # Reset the flag when starting a new drift
	succeeded = false
	drift_start_time = Time.get_ticks_msec() / 1000.0
	last_drift_direction = sign(controls.input_dir.x) if abs(controls.input_dir.x) > 0.1 else last_drift_direction

func update_drift_status():
	if is_drifting and abs(controls.input_dir.x) > 0.5:
		current_drift_duration = Time.get_ticks_msec() / 1000.0 - drift_start_time

		if current_drift_duration >= min_drift_time and !reached_min_drift:
			reached_min_drift = true
func check_drift_direction():
	if is_drifting:
		var current_input = controls.input_dir.x
		if abs(current_input) > 0.1:
			var current_direction = sign(current_input)
			if current_direction != last_drift_direction and drift_grace_timer <= 0:
				end_drift(false)
				start_drift()
				last_drift_direction = current_direction
		elif drift_grace_timer <= 0 and abs(current_input) <= 0.1:
			# Continue drifting in the last direction
			pass
	else:
		if drift_grace_timer <= 0:
			end_drift(false)
func end_drift(success):
	succeeded = success
	is_drifting = false
	var drift_duration = Time.get_ticks_msec() / 1000.0 - drift_start_time
	if (reached_min_drift or drift_grace_timer > 0) and player_body.get_linear_velocity().length() > 40:
		var forward_velocity = player_body.get_linear_velocity().project(suspension_model.facing_direction)
		if success:
			movement_forces_component.launch(forward_velocity.normalized() * min(movement_forces_component.top_speed_base * 3, 200))
	drift_cooldown_timer = drift_cooldown_duration  # Start the cooldown
	drift_grace_timer = 0  # Reset grace timer
	reached_min_drift = false  # Reset the flag when ending the drift
	last_drift_direction = 0.0  # Reset the last drift
	
func apply_drift_slide():
	if is_drifting and spatial_vars.grounded:
		var forward_velocity = player_body.get_linear_velocity().project(suspension_model.facing_direction)
		var sideways_direction = suspension_model.facing_direction.cross(spatial_vars.ground_normal).normalized()
		var sideways_speed = 2 if boost_state == 1.0 else 1.35
		# Update last_drift_direction when there's input
		#if abs(controls.input_dir.x) > 0.1:
		#	last_drift_direction = sign(controls.input_dir.x)
		# Use last_drift_direction instead of current input
		var sideways_velocity = sideways_direction * sideways_speed * last_drift_direction * (abs(controls.input_dir.x)+0.5)
		# Combine forward and sideways velocities
		var new_velocity = forward_velocity + sideways_velocity

		# Apply the new velocity
		player_body.set_linear_velocity(new_velocity)
		
func apply_drift_modifications():
	check_drift_direction()
	# Store original values
	if !spatial_vars.grounded:
		end_drift(false)
	movement_forces_component.top_speed_base *= 0.6
	movement_forces_component.turn_radius *= movement_forces_component.top_speed_base/30
	if player_body.get_linear_velocity().length() > movement_forces_component.top_speed_base:
		player_body.linear_damp = 1

func boost_state_normal():
	boost_manager.increment_boost()
	movement_forces_component.min_speed = 5
	movement_forces_component.is_boosting = false
	movement_forces_component.accel = accel
	movement_forces_component.top_speed_base = top_speed
	movement_forces_component.slope_accel_multiplier = base_slope_accel_mul
	movement_forces_component.drag_area = frontal_area
	movement_forces_component.drag_coefficient = drag_coefficient
	movement_forces_component.downforce_mul = downforce_mul
	# for the love of all that is holy do not set this to 0
	movement_forces_component.friction = 200
	movement_forces_component.turn_radius = normal_turn_rate
	
func boost_state_boost():
	boost_manager.decrement_boost()
	player_body.set_gravity_scale(1.25)
	movement_forces_component.min_speed = 90
	movement_forces_component.is_boosting = true
	movement_forces_component.traction_base = traction_base
	movement_forces_component.air_control = traction_base
	movement_forces_component.accel = accel_boost
	movement_forces_component.top_speed_base = top_speed_boost
	movement_forces_component.slope_accel_multiplier = 0
	movement_forces_component.drag_area = frontal_area_boosting
	movement_forces_component.drag_coefficient = drag_coefficient_boosting
	movement_forces_component.downforce_mul = downforce_mul_boost
	# for the love of all that is holy do not set this to 0
	movement_forces_component.friction = 100
	movement_forces_component.turn_radius = boost_turn_rate

func set_trail_transparency(alpha: float):
	if trail_material:
		var new_color = Color(semi_transparent_color)
		new_color.a = alpha
		trail_material.albedo_color = new_color

func start_fade_in():
	is_fading_in = true
	is_fading_out = false
	current_fade_time = 0.0

func start_fade_out():
	is_fading_out = true
	is_fading_in = false
	current_fade_time = 0.0

#func _on_air_attack_started():
#	can_boost = false
#
#func _on_air_attack_ended():
#	can_boost = true

func process_fade(delta: float):
	if is_fading_in or is_fading_out:
		current_fade_time += delta
		var t = clamp(current_fade_time / fade_duration, 0.0, 1.0)
		var alpha = t if is_fading_in else 1.0 - t
		set_trail_transparency(alpha)
		
		if current_fade_time >= fade_duration:
			is_fading_in = false
			is_fading_out = false

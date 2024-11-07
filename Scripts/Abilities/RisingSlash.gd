extends Node
class_name RisingSlashAbility

signal ability_started
signal ability_ended
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@onready var player_model: RayCast3D = $"../SuspensionComponent"
@onready var rise_vfx: Node3D = $"../SuspensionComponent/vfx_fire"
@onready var particles_floating: GPUParticles3D = $"../SuspensionComponent/vfx_fire/ParticlesFloating"
@onready var flame_particles: GPUParticles3D = $"../SuspensionComponent/vfx_fire/flame"
@onready var smoke_particles: GPUParticles3D = $"../SuspensionComponent/vfx_fire/smoke"
@onready var secondary_flame: GPUParticles3D = $"../SuspensionComponent/vfx_fire/flame2"
@onready var secondary_smoke: GPUParticles3D = $"../SuspensionComponent/vfx_fire/smoke2"


@export var max_rising_speed: float = 60.0
@export var ability_duration: float = 0.40
@export var horizontal_momentum_retention: float = 0.5
@export var windup_duration: float = 0.2
@export var min_horizontal_speed: float = 25.0
@export var max_horizontal_speed: float = 50.0
@export var cooldown_duration: float = 1.10  # Duration of the cooldown phase
@export var cooldown_gravity_factor: float = 0.1  # Fraction of normal gravity during cooldown
@export var vfx_offset_factor: float = 0.01
@export var secondary_particles_delay: float = 0.30
@export var secondary_particles_stop: float = 0.6

var final_rising_horizontal_velocity: Vector3
var is_active: bool = false
var player_body: RigidBody3D
var current_time: float = 0.0
var initial_horizontal_velocity: Vector3
var total_duration: float
var ability_system: AbilitySystem
var original_gravity_scale: float
var can_use_again: bool = true
var just_used: bool = false
var initial_direction: Vector3
var secondary_particles_timer: float = 0.0
var circle_slash: Node3D

enum AbilityPhase { WINDUP, RISING, COOLDOWN }
var current_phase: AbilityPhase = AbilityPhase.COOLDOWN

func _ready():
	player_body = get_parent()
	total_duration = windup_duration + ability_duration + cooldown_duration
	ability_system = get_node("/root/Abilities")
	original_gravity_scale = player_body.gravity_scale
	secondary_flame.emitting = false
	secondary_smoke.emitting = false
	circle_slash = player_body.get_node("SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/SwordFX/circle_slash")

func start_windup_particles():
	particles_floating.emitting = true
	flame_particles.emitting = false
	smoke_particles.emitting = false

func start_rising_particles():
	particles_floating.emitting = false
	flame_particles.emitting = true
	smoke_particles.emitting = true

func start_cooldown_particles():
	
	particles_floating.emitting = true
	flame_particles.emitting = false
	smoke_particles.emitting = true
	

func stop_all_particles():
	particles_floating.emitting = false
	flame_particles.emitting = false
	smoke_particles.emitting = false
	secondary_flame.emitting = false
	secondary_smoke.emitting = false
func can_use() -> bool:
	return ability_system.is_ability_unlocked("rising_slash") and not is_active and can_use_again and !ability_system.is_ability_locked("rising_slash")
func use():
	if can_use():
		perform_rising_slash()

func perform_rising_slash() -> void:
	is_active = true
	current_time = 0.0
	current_phase = AbilityPhase.WINDUP
	emit_signal("ability_started")
	start_windup_particles()
	can_use_again = false
	
	var current_velocity = player_body.get_linear_velocity()
	
	# Calculate horizontal velocity ignoring the slope (flatten the vector)
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	
	var horizontal_speed = horizontal_velocity.length()
	initial_direction = player_model.facing_direction

	# Clamp horizontal speed to ensure it's within the desired range
	horizontal_speed = clamp(horizontal_speed, min_horizontal_speed, max_horizontal_speed)
	
	# Calculate initial horizontal velocity based purely on the player's facing direction
	initial_horizontal_velocity = initial_direction * horizontal_speed

func update_velocity(t: float):
	var vertical_factor = custom_ease_in_out(t)
	var vertical_velocity = Vector3.UP * max_rising_speed * vertical_factor
	
	# Maintain horizontal velocity based on the original direction
	var horizontal_speed = initial_horizontal_velocity.length()
	var current_horizontal_velocity = initial_direction * horizontal_speed
	
	# Combine vertical and horizontal components
	var new_velocity = current_horizontal_velocity + vertical_velocity
	player_body.set_linear_velocity(new_velocity)
	
	update_vfx_position()
	
	final_rising_horizontal_velocity = current_horizontal_velocity  # Update this every frame

func _physics_process(delta):
	if is_active:
		player_body.set_gravity_scale(2)
		current_time += delta
		match current_phase:
			AbilityPhase.WINDUP:
				if current_time >= windup_duration:
					current_phase = AbilityPhase.RISING
					current_time = 0
					start_rising_particles()
				else:
					apply_windup()
			AbilityPhase.RISING:
				if current_time >= ability_duration:
					start_cooldown()
					start_cooldown_particles()
					#sword_trail.restart()
				else:
					update_velocity(current_time / ability_duration)
			AbilityPhase.COOLDOWN:
				if current_time >= cooldown_duration:
					end_ability()
				else:
					apply_cooldown()
					update_vfx_position()
					update_secondary_particles(delta)

func update_secondary_particles(delta):
	secondary_particles_timer += delta
	if secondary_particles_timer >= secondary_particles_delay:
		circle_slash.visible = true
		secondary_flame.emitting = true
		secondary_smoke.emitting = true
	if secondary_particles_timer >= secondary_particles_stop:
		circle_slash.visible = false
func reset_usage():
	if not is_active:
		can_use_again = true

func apply_windup():
	var slowed_velocity = player_body.get_linear_velocity() * 0.95
	player_body.set_linear_velocity(slowed_velocity)


func custom_ease_in_out(t: float) -> float:
	# This function creates a smooth arc: slow start, fast middle, slow end
	if t < 0.5:
		return 4 * t * t * t
	else:
		return 1 - pow(-2 * t + 2, 3) / 2

# Optional: Add these functions for more control over the motion
func ease_out_cubic(t: float) -> float:
	return 1 - pow(1 - t, 3)

func ease_in_cubic(t: float) -> float:
	return t * t * t

func start_cooldown():
	current_phase = AbilityPhase.COOLDOWN
	current_time = 0
	
	
	# Maintain the horizontal velocity from the rising phase
	var current_velocity = player_body.get_linear_velocity()
	var horizontal_speed = final_rising_horizontal_velocity.length()
	var maintained_horizontal_velocity = player_model.facing_direction * horizontal_speed
	var new_velocity = Vector3(maintained_horizontal_velocity.x, current_velocity.y, maintained_horizontal_velocity.z)
	player_body.set_linear_velocity(new_velocity)
	
	

func apply_cooldown():
	var current_velocity = player_body.get_linear_velocity()
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	var horizontal_speed = horizontal_velocity.length()
	
	# Only adjust speed if it's outside the allowed range
	if horizontal_speed < min_horizontal_speed:
		horizontal_velocity = player_model.facing_direction * min_horizontal_speed
	elif horizontal_speed > max_horizontal_speed:
		horizontal_velocity = player_model.facing_direction * max_horizontal_speed
	
	var new_velocity = Vector3(horizontal_velocity.x, current_velocity.y, horizontal_velocity.z)
	player_body.set_linear_velocity(new_velocity)
	
	
func end_ability():
	stop_all_particles()
	secondary_particles_timer = 0
	is_active = false
	current_phase = AbilityPhase.COOLDOWN
	just_used = false
	emit_signal("ability_ended")
func update_vfx_position():
	var player_velocity = player_body.get_linear_velocity()
	var offset = player_velocity * vfx_offset_factor
	
	# Get the global position of the player
	var player_global_pos = player_body.global_position
	
	# Set the global position of vfx_fire
	rise_vfx.global_position = player_global_pos + offset

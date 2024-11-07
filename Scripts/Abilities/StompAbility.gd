extends Node
class_name StompAbility

signal ability_started
signal ability_ended
signal camera_shake_requested(amount: float, duration: float)


@export var stomp_speed: float = 150.0
@export var ground_impact_force: float = 1000.0
@export var max_stomp_duration: float = 2.0  # Maximum time the stomp will last if ground isn't hit
@export var windup_duration: float = 0.25  # Duration of the windup phase
@export var cooldown_duration: float = 0.3
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@onready var anim_manager: Node3D = $"../AnimationManager"
@export var shake_amount: float = 0.1
@export var shake_duration: float = 0.3
@export var vfx_offset_factor: float = 0.01

@onready var rise_vfx: Node3D = $"../SuspensionComponent/vfx_fire"
@onready var particles_floating: GPUParticles3D = $"../SuspensionComponent/vfx_fire/ParticlesFloating"
@onready var flame_particles: GPUParticles3D = $"../SuspensionComponent/vfx_fire/flame"
@onready var smoke_particles: GPUParticles3D = $"../SuspensionComponent/vfx_fire/smoke"
@onready var secondary_flame: GPUParticles3D = $"../SuspensionComponent/vfx_fire/flame2"
@onready var secondary_smoke: GPUParticles3D = $"../SuspensionComponent/vfx_fire/smoke2"
@onready var sparks_vfx = $explosion_vfx/sparks
@onready var flash_vfx = $explosion_vfx/flash
var is_active: bool = false
var player_body: RigidBody3D
var ability_system: AbilitySystem
var initial_horizontal_velocity: Vector3
var current_time: float = 0.0

enum StompPhase { WINDUP, STOMPING, COOLDOWN }
var current_phase: StompPhase = StompPhase.WINDUP

func _ready():
	player_body = get_parent()
	ability_system = get_node("/root/Abilities")  # Adjust this path if necessary
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
	if spatial_vars.grounded:
		secondary_flame.emitting = true
		secondary_smoke.emitting = true
		sparks_vfx.emitting = true
		flash_vfx.emitting = true
func stop_all_particles():
	particles_floating.emitting = false
	flame_particles.emitting = false
	smoke_particles.emitting = false
	secondary_flame.emitting = false
	secondary_smoke.emitting = false
func can_use() -> bool:
	return not is_active and ability_system.is_ability_unlocked("stomp") and not spatial_vars.grounded and !ability_system.is_ability_locked("stomp")

func use():
	if can_use():
		perform_stomp()
	else:
		print("Stomp is not available, not unlocked, or player is on the ground.")

func perform_stomp() -> void:
	start_windup_particles()
	anim_manager.reverse_sword()
	is_active = true
	current_time = 0.0
	current_phase = StompPhase.WINDUP
	emit_signal("ability_started")
	
	# Store a portion of the horizontal velocity
	initial_horizontal_velocity = player_body.get_linear_velocity()  # Retain 20% of horizontal speed
	
	# Set downward velocity
	#player_body.set_linear_velocity(Vector3.DOWN * stomp_speed + initial_horizontal_velocity)

func _physics_process(delta):
	if is_active:
		current_time += delta
		
		match current_phase:
			StompPhase.WINDUP:
				if current_time >= windup_duration:
					start_rising_particles()
					start_stomping()
				else:
					# Slow down during windup
					player_body.set_linear_velocity(initial_horizontal_velocity * 0.5)
			
			StompPhase.STOMPING:
				if spatial_vars.grounded or current_time >= max_stomp_duration:
					start_cooldown_particles()
					start_cooldown()
				else:
					# Maintain downward velocity and slight horizontal movement
					player_body.set_linear_velocity(Vector3.DOWN * stomp_speed + initial_horizontal_velocity * 0.2)
			
			StompPhase.COOLDOWN:
				if current_time >= cooldown_duration:
					stop_all_particles()
					end_ability()
				else:
					# Keep the player in place during cooldown
					player_body.set_linear_velocity(Vector3.ZERO)

func start_stomping():
	current_phase = StompPhase.STOMPING
	current_time = 0.0  # Reset the timer for the stomping phase
	
	# Set downward velocity
	player_body.set_linear_velocity(Vector3.DOWN * stomp_speed + initial_horizontal_velocity * 0.2)
	update_vfx_position()
func start_cooldown():
	current_phase = StompPhase.COOLDOWN
	current_time = 0.0  # Reset the timer for the cooldown phase
	
	# Apply an upward force on impact to create a bouncing effect
	#player_body.apply_central_impulse(Vector3.UP * ground_impact_force)
	if spatial_vars.grounded:
		emit_signal("camera_shake_requested", shake_amount, shake_duration)

func end_ability():
	anim_manager.reverse_sword()
	is_active = false
	#rotate sword by 180 degrees here(local coordinates)
	emit_signal("ability_ended")
func update_vfx_position():
	var player_velocity = player_body.get_linear_velocity()
	var offset = player_velocity * vfx_offset_factor
	
	# Get the global position of the player
	var player_global_pos = player_body.global_position
	
	# Set the global position of vfx_fire
	rise_vfx.global_position = player_global_pos + offset

extends Node
class_name AirAttackAbility

signal attack_started
signal attack_ended

@onready var rise_vfx: Node3D = $"../SuspensionComponent/vfx_fire"
@onready var particles_floating: GPUParticles3D = $"../SuspensionComponent/vfx_fire/ParticlesFloating"
@onready var flame_particles: GPUParticles3D = $"../SuspensionComponent/vfx_fire/flame"
@onready var smoke_particles: GPUParticles3D = $"../SuspensionComponent/vfx_fire/smoke"
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@onready var movement_forces: MovementForcesComponent = $"../MovementForcesComponent"

@export var attack_speed: float = 6.0
@export var attack_duration: float = 0.25
@export var vfx_offset_factor: float = 0.01
@export var startup_duration: float = 0.25
@export var jump_frames: int = 10  # Number of frames to apply jump force

var is_active: bool = false
var player_body: RigidBody3D
var targeting_system: RayCast3D
var circle_slash: Node3D
var ability_system: AbilitySystem
var startup_timer: float = 0.0
var jump_frame_counter: int = 0

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

func _ready():
	player_body = get_parent()
	targeting_system = player_body.get_node("TargetManager")
	circle_slash = player_body.get_node("SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/SwordFX/circle_slash")
	ability_system = get_node("/root/Abilities")

func can_use() -> bool:
	return targeting_system.get_current_target() != null and not is_active and ability_system.is_ability_unlocked("air_attack") and !ability_system.is_ability_locked("air_attack")

func use():
	if can_use():
		perform_air_attack()

func perform_air_attack() -> void:
	start_windup_particles()
	is_active = true
	emit_signal("attack_started")
	player_body.set_linear_velocity(player_body.get_linear_velocity()*0.2)
	if !spatial_vars.grounded:
		jump_frames = 4
	else:
		jump_frames = 10
	# Set player as airborne
	spatial_vars.grounded = false
	
	# Start the startup phase
	startup_timer = 0.0
	jump_frame_counter = 0
	set_physics_process(true)

func _physics_process(delta):
	if is_active and startup_timer < startup_duration:
		startup_timer += delta
		
		# Apply jump force for a certain number of frames
		if jump_frame_counter < jump_frames:
			movement_forces.jump(0)
			jump_frame_counter += 1
		
		if startup_timer >= startup_duration:
			execute_attack()
			set_physics_process(false)  # Stop physics process once attack is executed

func execute_attack():
	var current_target = targeting_system.get_current_target()
	var direction_to_target = targeting_system.get_target_vector()
	
	start_rising_particles()
	
	# Set new attack velocity
	player_body.set_linear_velocity(direction_to_target * attack_speed)
	circle_slash.visible = true
	update_vfx_position()
	
	# Create and start a timer for attack duration
	get_tree().create_timer(attack_duration).connect("timeout", Callable(self, "_on_attack_timer_timeout"))

func _on_attack_timer_timeout():
	circle_slash.visible = false
	stop_all_particles()
	is_active = false
	player_body.set_linear_velocity(player_body.get_linear_velocity() * 0.3)
	emit_signal("attack_ended")

func update_vfx_position():
	var player_velocity = player_body.get_linear_velocity()
	var offset = player_velocity * vfx_offset_factor
	
	# Get the global position of the player
	var player_global_pos = player_body.global_position
	
	# Set the global position of vfx_fire
	rise_vfx.global_position = player_global_pos + offset

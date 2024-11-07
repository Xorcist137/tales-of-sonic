extends Node
class_name AirSlashAbility

signal ability_started
signal ability_ended

@onready var player_model: RayCast3D = $"../SuspensionComponent"
@onready var sword_trail: Node3D = $"../SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/sword_trail"

@export var ability_duration: float = 0.5
@export var cooldown_duration: float = 0.5
@export var vertical_speed_reduction: float = 1.0

var is_active: bool = false
var player_body: RigidBody3D
var current_time: float = 0.0
var ability_system: AbilitySystem

enum AbilityPhase {SLASHING, COOLDOWN }
var current_phase: AbilityPhase = AbilityPhase.SLASHING

func _ready():
	player_body = get_parent()
	ability_system = get_node("/root/Abilities")

func can_use() -> bool:
	return ability_system.is_ability_unlocked("run_slash") and not is_active and current_phase == AbilityPhase.SLASHING and !ability_system.is_ability_locked("air_slash")

func use():
	if can_use():
		perform_air_slash()

func perform_air_slash() -> void:
	is_active = true
	current_time = 0.0
	current_phase = AbilityPhase.SLASHING
	emit_signal("ability_started")
	sword_trail.restart()
	apply_velocity()

func apply_velocity():
	var new_velocity = player_body.get_linear_velocity()*Vector3(1,vertical_speed_reduction,1)  # Maintain vertical velocity
	player_body.set_gravity_scale(0.33)
	player_body.set_linear_velocity(new_velocity)

func _physics_process(delta):
	if is_active or current_phase == AbilityPhase.COOLDOWN:
		current_time += delta
		match current_phase:
			AbilityPhase.SLASHING:
				if current_time >= ability_duration:
					start_cooldown()
			AbilityPhase.COOLDOWN:
				if current_time >= cooldown_duration:
					end_ability()

func start_slashing():
	
	current_phase = AbilityPhase.SLASHING
	current_time = 0

func start_cooldown():
	is_active = false
	current_phase = AbilityPhase.COOLDOWN
	current_time = 0

func end_ability():
	is_active = false
	current_phase = AbilityPhase.SLASHING
	emit_signal("ability_ended")

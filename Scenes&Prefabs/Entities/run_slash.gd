extends Node
class_name RunSlashAbility

signal ability_started
signal ability_ended

@onready var player_model: RayCast3D = $"../SuspensionComponent"
@onready var sword_trail: Node3D = $"../SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/sword_trail"

@export var min_slash_speed: float = 80.0
@export var speed_boost: float = -10.0
@export var windup_duration: float = 0.33
@export var ability_duration: float = 0.5
@export var cooldown_duration: float = 1.0
@export var windup_speed_factor: float = 0.5  # New: Speed factor during windup

var is_active: bool = false
var player_body: RigidBody3D
var current_time: float = 0.0
var ability_system: AbilitySystem
var slash_direction: Vector3
var target_speed: float

enum AbilityPhase { WINDUP, SLASHING, COOLDOWN }
var current_phase: AbilityPhase = AbilityPhase.WINDUP

func _ready():
	player_body = get_parent()
	ability_system = get_node("/root/Abilities")

func can_use() -> bool:
	return ability_system.is_ability_unlocked("run_slash") and not is_active and current_phase == AbilityPhase.WINDUP and !ability_system.is_ability_locked("run_slash")

func use():
	if can_use():
		perform_run_slash()

func perform_run_slash() -> void:
	is_active = true
	current_time = 0.0
	current_phase = AbilityPhase.WINDUP
	emit_signal("ability_started")
	sword_trail.restart()
	var current_velocity = player_body.get_linear_velocity()
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	var current_speed = horizontal_velocity.length()
	
	target_speed = max(min_slash_speed, current_speed + speed_boost)
	slash_direction = horizontal_velocity.normalized()
	
	if slash_direction == Vector3.ZERO:
		slash_direction = -player_model.global_transform.basis.z
	
	apply_windup_velocity()

func apply_windup_velocity():
	var windup_speed = target_speed * windup_speed_factor
	var new_velocity = slash_direction * windup_speed
	new_velocity.y = player_body.get_linear_velocity().y  # Maintain vertical velocity
	player_body.set_linear_velocity(new_velocity)

func apply_slash_velocity():
	var new_velocity = slash_direction * target_speed
	new_velocity.y = player_body.get_linear_velocity().y  # Maintain vertical velocity
	player_body.set_linear_velocity(new_velocity)

func _physics_process(delta):
	if is_active or current_phase == AbilityPhase.COOLDOWN:
		current_time += delta
		match current_phase:
			AbilityPhase.WINDUP:
				if current_time >= windup_duration:
					start_slashing()
				else:
					apply_windup_velocity()
			AbilityPhase.SLASHING:
				if current_time >= ability_duration:
					start_cooldown()
			AbilityPhase.COOLDOWN:
				if current_time >= cooldown_duration:
					end_ability()

func start_slashing():
	current_phase = AbilityPhase.SLASHING
	current_time = 0
	apply_slash_velocity()

func start_cooldown():
	is_active = false
	current_phase = AbilityPhase.COOLDOWN
	current_time = 0

func end_ability():
	is_active = false
	current_phase = AbilityPhase.WINDUP
	emit_signal("ability_ended")

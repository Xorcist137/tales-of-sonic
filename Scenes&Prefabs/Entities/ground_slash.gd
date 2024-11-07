extends Node
class_name GroundSlashAbility

signal ability_started
signal ability_ended

@export var combo_window_duration: float = 0.20  # Time window to input next slash
@export var slash_1_2_duration: float = 0.4  # Duration of each slash
@export var slash_3_duration: float = 0.5
@export var cooldown_duration: float = 1.0
@export var slash_1_2_speed_limit: float = 15.0
@export var slash_3_speed_limit: float = 30.0
@onready var sword_trail: Node3D = $"../SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/sword_trail"

var is_active: bool = false
var player_body: RigidBody3D
var ability_system: AbilitySystem
var current_time: float = 0.0
var combo_count: int = 0
var combo_input_received: bool = false
var in_combo_window: bool = false
var combo_window_time: float = 0.0

enum SlashPhase { SLASH_1, SLASH_2, SLASH_3, COOLDOWN }
var current_phase: SlashPhase = SlashPhase.COOLDOWN

var is_slash_1_active: bool = false
var is_slash_2_active: bool = false
var is_slash_3_active: bool = false

func _ready():
	player_body = get_parent()
	ability_system = get_node("/root/Abilities")
	set_process(false)

func use():
	if not is_active:
		start_ability()

func start_ability():
	player_body.set_linear_velocity(Vector3.ZERO)
	sword_trail.restart()
	is_active = true
	current_time = 0.0
	combo_count = 0
	current_phase = SlashPhase.SLASH_1
	is_slash_1_active = true
	combo_input_received = false
	in_combo_window = false
	combo_window_time = 0.0
	set_process(true)
	emit_signal("ability_started")

func _process(delta):
	current_time += delta
	
	match current_phase:
		SlashPhase.SLASH_1:
			process_slash_1(delta)
		SlashPhase.SLASH_2:
			process_slash_2(delta)
		SlashPhase.SLASH_3:
			process_slash_3(delta)
		SlashPhase.COOLDOWN:
			process_cooldown(delta)
	if is_active and current_phase != SlashPhase.COOLDOWN:
		apply_velocity()
		
func process_slash_1(delta):
	if current_time >= slash_1_2_duration:
		is_slash_1_active = false
		if combo_input_received:
			start_slash_2()
		else:
			end_ability()
	elif current_time >= slash_1_2_duration - combo_window_duration:
		in_combo_window = true
		combo_window_time += delta

func process_slash_2(delta):
	if current_time >= slash_1_2_duration:
		is_slash_2_active = false
		if combo_input_received:
			start_slash_3()
		else:
			end_ability()
	elif current_time >= slash_1_2_duration - combo_window_duration:
		in_combo_window = true
		combo_window_time += delta

func process_slash_3(_delta):
	if current_time >= slash_3_duration:
		is_slash_3_active = false
		end_ability()

func process_cooldown(_delta):
	if current_time >= cooldown_duration:
		set_process(false)

func start_slash_2():
	current_time = 0.0
	current_phase = SlashPhase.SLASH_2
	is_slash_2_active = true
	combo_input_received = false
	in_combo_window = false
	combo_window_time = 0.0
	combo_count = 1

func start_slash_3():
	current_time = 0.0
	current_phase = SlashPhase.SLASH_3
	is_slash_3_active = true
	combo_input_received = false
	in_combo_window = false
	combo_window_time = 0.0
	combo_count = 2

func end_ability():
	current_time = 0.0
	current_phase = SlashPhase.COOLDOWN
	is_active = false
	emit_signal("ability_ended")

func can_use() -> bool:
	return not is_active and !ability_system.is_ability_locked("ground_slash")

func reset_usage():
	if current_phase == SlashPhase.COOLDOWN:
		set_process(false)
		current_time = 0.0

func input_attack():
	if in_combo_window and not combo_input_received:
		combo_input_received = true

func apply_velocity():
	if not player_body:
		return
	
	var current_velocity = player_body.get_linear_velocity().normalized()
	var speed_limit = slash_1_2_speed_limit if current_phase != SlashPhase.SLASH_3 else slash_3_speed_limit
	current_velocity *= current_time/(slash_1_2_duration) * 50
	if current_velocity.length() > speed_limit:
		current_velocity = current_velocity.normalized() * speed_limit
		player_body.set_linear_velocity(current_velocity) 
		return
	player_body.set_linear_velocity(current_velocity)


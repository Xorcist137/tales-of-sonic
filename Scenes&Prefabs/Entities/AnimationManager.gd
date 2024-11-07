extends Node3D


@onready var suspension_model: Node3D = $"../SuspensionComponent"
@onready var animation_player = $"../SuspensionComponent/AnimationPlayer"
#@onready var mix_animation_player = $"../SuspensionComponent/MixAnimationPlayer"
@onready var player_body: RigidBody3D = $"../"
@onready var controls: Controls = $"/root/GameControls"
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@onready var Boost_Manager: Node3D =  $"../BoomMovementStateComponent"
@onready var movement_forces: Node3D = $"../MovementForcesComponent"
@onready var sword_effects: Node3D = $"../SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/SwordFX"
@onready var drift_effects: Node3D = $"../SuspensionComponent/grass_part"
@onready var drift_effects_full: Node3D = $"../SuspensionComponent/vfx_fire/drift_smoke"
@onready var fire_vfx: Node3D = $"../SuspensionComponent/vfx_fire"
@onready var abilities: Node = $"/root/Abilities"
@onready var sword: Node3D = $"../SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/caliburn_stage1"
@onready var sword_trail: Node3D = $"../SuspensionComponent/Reference/Skeleton3D/BoneAttachment3D/sword_trail"
@onready var ember_particles: GPUParticles3D = $"../SuspensionComponent/vfx_fire/ParticlesFloating"


var is_jumping: bool = false
var jump_start_time: float = 0
var flip_threshold: float = 0.1
var has_flipped: bool = false
var is_jumpcrouch_signal_connected: bool = false
const TRANSITION_TIME = 0.5
var original_transform: Transform3D
var reversed_transform: Transform3D
var is_reversed: bool = false

@export var vfx_offset_factor: float = 0.015
# Called when the node enters the scene tree for the first time.
func _ready():
	is_jumpcrouch_signal_connected = false
	original_transform = sword.transform
	
	# Calculate the reversed transform
	reversed_transform = original_transform.translated(Vector3(0, -0.5, 0.1))  # Raise by 0.5 units
	reversed_transform = reversed_transform.rotated(Vector3.RIGHT, PI)  # Rotate 180 degrees around X-axis
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	update_animation()
	update_vfx_position()
	
func reverse_sword() -> void:
	if is_reversed:
		sword.transform = original_transform
	else:
		sword.transform = reversed_transform
	
	is_reversed = !is_reversed

func update_animation() -> void:
	if !abilities.is_any_ability_active():
		sword_trail.visible = false
	var ground_slash = abilities.get_ability("ground_slash")
	var rise_slash = abilities.get_ability("rising_slash")
	var far_slash = abilities.get_ability("far_slash")
	var stomp = abilities.get_ability("stomp")
	var run_slash = abilities.get_ability("run_slash")
	var air_slash = abilities.get_ability("air_slash")
	var speed_multiplier = player_body.get_linear_velocity().length()/5
	drift_effects.visible = false
	drift_effects_full.emitting = false
	if air_slash.is_active:
		play_animation("sonic_air_slash", 4.0)
		sword_trail.visible = true
	elif run_slash.is_active:
		match run_slash.current_phase:
			0:
				play_animation("sonic_run_slash_0",2.5)
			1:
				play_animation("sonic_run_slash_1",speed_multiplier)
				sword_trail.visible = true
			2:
				sword_trail.visible = false
				if spatial_vars.grounded:
					play_animation("sonic_run", speed_multiplier)
				else:
					play_animation("sonic_run_slash_1",speed_multiplier)
	elif ground_slash.is_active:
		handle_ground_slash_animation()
	elif rise_slash.is_active:
		is_jumping = true
		play_animation("sonic_rise", 2.4, 0.05)
	elif far_slash.is_active:
		match far_slash.current_phase:
			0:
				play_animation("sonic_far", 2.5, 0.05)
	elif stomp.is_active:
		if stomp.current_phase == 0:
			play_animation("sonic_stomp_1", 1.75, 0.05)
		if stomp.current_phase == 1:
			play_animation("sonic_stomp_2", 4.0, 0.05)
		if stomp.current_phase == 2:
			play_animation("sonic_stomp_3", 1.75, 0.05)
	elif spatial_vars.grounded:
		if Boost_Manager.drift_cooldown_timer > 0 and Boost_Manager.succeeded:
			ember_particles.emitting = true
		else:
			ember_particles.emitting = false
		if is_jumping:
			is_jumping = false
		if Boost_Manager.is_drifting:
			if Boost_Manager.last_drift_direction > 0:
				play_animation("sonic_drift_R", 2.0)
			else:
				play_animation("sonic_drift_L", 2.0)
			drift_effects.visible = true
			drift_effects_full.emitting = Boost_Manager.reached_min_drift
		elif speed_multiplier > 10.0:
			play_animation("sonic_run", speed_multiplier)
		elif speed_multiplier > 2.5:
			play_animation("sonic_walk", speed_multiplier*2)
		elif speed_multiplier > 0.1:
			play_animation("sonic_walk", speed_multiplier*6)
		else:
			play_animation("sonic_idle", 1.0, 1)
		
	else:
		handle_air_animation()

func handle_ground_slash_animation() -> void:
	var ground_slash = abilities.get_ability("ground_slash")
	if ground_slash.is_slash_1_active:
		sword_trail.visible = true
		play_animation("sonic_ground_slash_1", 3)
	elif ground_slash.is_slash_2_active:
		sword_trail.visible = true
		play_animation("sonic_ground_slash_2", 3)
	elif ground_slash.is_slash_3_active:
		sword_trail.visible = true
		play_animation("sonic_ground_slash_3", 3)

func handle_air_animation() -> void:
	var rise_slash = abilities.get_ability("rising_slash")
	var vertical_velocity = player_body.get_linear_velocity().y
	if abilities.get_ability("air_attack").is_active:
		play_animation("sonic_airattack", 8)
	elif Boost_Manager.boost_state == Boost_Manager.BoostState.BOOST:
		play_animation("sonic_airboost", 3.0)
	elif not is_jumping and vertical_velocity > 0:
		has_flipped = false
		jump_start_time = Time.get_ticks_msec() / 1000.0
		play_animation("sonic_jumpcrouch", 2.0, 0.0)
		if not is_jumpcrouch_signal_connected:
			animation_player.connect("animation_finished", Callable(self, "_on_jumpcrouch_finished"))
			is_jumpcrouch_signal_connected = true
	elif is_jumping:
		var time_since_jump_start = Time.get_ticks_msec() / 1000.0 - jump_start_time
		if vertical_velocity > 0:
			if time_since_jump_start < flip_threshold:
				play_animation("sonic_jump", 3.0, 1.0)
			elif !has_flipped:
				has_flipped = true
				play_animation("sonic_flip", 3.0)
		else:
			play_animation("sonic_fall", 3.0, 1.0)
	else:
		play_animation("sonic_fall", 3.0, 1.0)

func _on_jumpcrouch_finished(anim_name: String) -> void:
	if is_jumpcrouch_signal_connected:
		animation_player.disconnect("animation_finished", Callable(self, "_on_jumpcrouch_finished"))
		is_jumpcrouch_signal_connected = false
	is_jumping = true
	
func play_animation(anim_name: String, speed: float = 1.0, transition_time: float = 0.5) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name, transition_time)
	animation_player.speed_scale = speed
#func play_mix_animation(anim_name: String, speed: float = 1.0, transition_time: float = 0.5) -> void:
#	if mix_animation_player.current_animation != anim_name:
#		mix_animation_player.play(anim_name, transition_time)
#	mix_animation_player.speed_scale = speed
	
func update_vfx_position():
	var player_velocity = player_body.get_linear_velocity()
	var offset = player_velocity * vfx_offset_factor
	
	# Get the global position of the player
	var player_global_pos = player_body.global_position
	
	# Set the global position of vfx_fire
	fire_vfx.global_position = player_global_pos + offset

extends RigidBody3D


@onready var abilities = $"/root/Abilities"  # Assuming AbilitySystem is an autoload
@onready var controls = $"/root/GameControls"  # Assuming Controls is an autoload
@onready var air_attack_ability = $AirAttackAbility
@onready var rising_slash_ability = $RisingSlash
@onready var stomp_ability = $StompAbility
@onready var far_slash_ability = $FarSlash
@onready var ground_slash_ability = $ground_slash
@onready var run_slash_ability = $run_slash
@onready var air_slash_ability = $air_slash
@onready var boom_movement_state = $BoomMovementStateComponent


func _ready():
	if air_attack_ability:
		abilities.register_ability("air_attack", air_attack_ability)
		abilities.unlock_ability("air_attack")
		print("Air attack ability registered and unlocked")
	else:
		push_warning("AirAttackAbility node not found on player")
	
	if rising_slash_ability:
		abilities.register_ability("rising_slash", rising_slash_ability)
		abilities.unlock_ability("rising_slash")
	else:
		push_warning("RisingSlashAbility node not found on player")
	if stomp_ability:
		abilities.register_ability("stomp", stomp_ability)
		abilities.unlock_ability("stomp")
	else:
		push_warning("StompAbility node not found on player")
	if far_slash_ability:
		abilities.register_ability("far_slash", far_slash_ability)
		abilities.unlock_ability("far_slash")
		print("FarSlashAbility registered and unlocked")
	else:
		push_warning("FarSlash node not found on player")
	if ground_slash_ability:
		abilities.register_ability("ground_slash", ground_slash_ability)
		abilities.unlock_ability("ground_slash")
		print("Ground Slash ability registered and unlocked")
	else:
		push_warning("GroundSlashAbility node not found on player")
	if run_slash_ability:
		abilities.register_ability("run_slash", run_slash_ability)
		abilities.unlock_ability("run_slash")
		print("Run Slash ability registered and unlocked")
	else:
		push_warning("RunSlashAbility node not found on player")
	if air_slash_ability:
		abilities.register_ability("air_slash", air_slash_ability)
		abilities.unlock_ability("air_slash")
		print("Air Slash ability registered and unlocked")
	else:
		push_warning("AirSlashAbility node not found on player")
	# Signal other components that initialization is complete
	#call_deferred("_post_init")

#func _post_init():
	# This will be called after all _ready functions have been called
	#if boom_movement_state:
	#	boom_movement_state.initialize_abilities()

#func _on_attack_pressed():
#	abilities.use_ability("air_attack")

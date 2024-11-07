extends Node3D
class_name BoostManager

@onready var input_manager: Controls = $"/root/GameControls"
@onready var hud_vars: HUDStatics = $"/root/HudStatics"
@export var max_boost_energy: float = 480
@onready var movement_state_component: BoomMovementStateComponent = $"../BoomMovementStateComponent"
@onready var ability_system: Node = $"/root/Abilities"

var current_boost_energy: float = max_boost_energy
var needs_full_recharge: bool = false

func decrement_boost():
	if current_boost_energy > 0:
		current_boost_energy -= 1
		if current_boost_energy == 0:
			needs_full_recharge = true
	update_boost_availability()

func just_boosted():
	if movement_state_component.can_boost:
		if current_boost_energy > 60:
			current_boost_energy -= 60
		else:
			current_boost_energy = 0
			needs_full_recharge = true
	update_boost_availability()

func increment_boost():
	if current_boost_energy < max_boost_energy:
		current_boost_energy += 0.5
		if current_boost_energy == max_boost_energy:
			needs_full_recharge = false
	update_boost_availability()

func update_boost_availability():
	movement_state_component.can_boost = current_boost_energy > 0 and not needs_full_recharge and not ability_system.is_any_ability_active()
	hud_vars.boost_available = !needs_full_recharge

func _ready():
	hud_vars.boost_max = max_boost_energy

func _physics_process(delta):
	hud_vars.boost_energy = current_boost_energy
	update_boost_availability()

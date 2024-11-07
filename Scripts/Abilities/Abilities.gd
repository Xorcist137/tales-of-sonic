extends Node
class_name AbilitySystem

var abilities = {
	"air_attack": false,
	"rising_slash": false,
	"stomp": false,
	"far_slash": false,
	"ground_slash": true,
	"run_slash": true,
	"air_slash": true
}

signal ability_state_changed(ability_name: String, is_active: bool)

var ability_instances = {}
var locked_abilities: Array = []

func register_ability(ability_name: String, ability_instance: Node):
	ability_instances[ability_name] = ability_instance
	if ability_name not in abilities:
		abilities[ability_name] = false
	print("Ability registered: ", ability_name)

func unlock_ability(ability_name: String) -> void:
	if ability_name in abilities:
		abilities[ability_name] = true

func is_ability_unlocked(ability_name: String) -> bool:
	return abilities.get(ability_name, false)



func use_ability(ability_name: String) -> void:
	if is_ability_unlocked(ability_name) and not is_ability_locked(ability_name):
		var ability = ability_instances.get(ability_name)
		if ability and ability.has_method("can_use") and ability.can_use():
			ability.use()
			
	else:
		print("Ability not unlocked or is locked: ", ability_name)

func get_ability(ability_name: String) -> Node:
	return ability_instances.get(ability_name, null)

func lock_ability(ability_name: String) -> void:
	if ability_name not in locked_abilities:
		locked_abilities.append(ability_name)

func unlock_all_abilities() -> void:
	locked_abilities.clear()

func is_ability_locked(ability_name: String) -> bool:
	return ability_name in locked_abilities

func is_any_ability_active() -> bool:
	for ability in ability_instances.values():
		if ability.is_active:
			return true
	return false

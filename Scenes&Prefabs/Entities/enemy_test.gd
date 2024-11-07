extends RigidBody3D

@export var disable_distance: float = 4.0 # Distance at which to disable collision
@export var disable_duration: float = 1.0
@onready var collision_shape: CollisionShape3D = $CollisionShape3D  # Adjust this path if necessary
@onready var player: Node = $"../Player"  # Assumes the player is in a "player" group
var can_disable: bool = true
func _ready():
	add_to_group("targetable")

func _physics_process(_delta):
	if player:
		var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
		if distance_to_player <= disable_distance:
			HitStopManager.slow_motion_short()
			disable_collision()
			
			

func disable_collision():
	collision_shape.disabled = true
	can_disable = false
	
	# Optional: Add any visual effects or other logic here
	# For example, you could fade out the enemy's mesh:
	# $Mesh.visible = false  # Assuming you have a Mesh child node
	
	# Start a timer to re-enable collision
	get_tree().create_timer(disable_duration).connect("timeout", Callable(self, "enable_collision"))

func enable_collision():
	collision_shape.disabled = false
	can_disable = true
	
	# Optional: Reverse any visual effects applied when disabling
	# For example, fade the mesh back in:
	# $Mesh.visible = true

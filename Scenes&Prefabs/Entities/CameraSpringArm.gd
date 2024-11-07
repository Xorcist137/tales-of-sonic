extends SpringArm3D
@onready var player = $"../../Player"

# Called when the node enters the scene tree for the first time.
func _ready():
	if player:
		print("excluded player")
		add_excluded_object(player.get_rid()) # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

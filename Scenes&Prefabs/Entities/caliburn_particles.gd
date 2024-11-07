extends Node3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Set the up direction to be global up
	look_at(Vector3.UP)

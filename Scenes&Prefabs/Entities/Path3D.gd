extends Path3D


# Called when the node enters the scene tree for the first time.
func _ready():
	var curve = Curve3D.new()

	var radius = 1.0
	var height_per_turn = 2.0
	var points_per_turn = 16
	var num_turns = 3

	for i in range(points_per_turn * num_turns + 1):
		var t = i * 2 * PI / points_per_turn
		var x = radius * cos(t)
		var y = height_per_turn * t / (2 * PI)
		var z = radius * sin(t)
		
		var tx = -radius * sin(t)
		var ty = height_per_turn / (2 * PI)
		var tz = radius * cos(t)
		
		var magnitude = sqrt(tx*tx + ty*ty + tz*tz)
		var scale = 0.5
		var out_x = (tx / magnitude) * scale
		var out_y = (ty / magnitude) * scale
		var out_z = (tz / magnitude) * scale
		
		var tilt = 0
		
		curve.add_point(Vector3(x, y, z), Vector3(out_x, out_y, out_z), Vector3.ZERO, tilt) # Replace with function body.


	# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

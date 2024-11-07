extends Node3D
class_name Controls

# Licensed under MIT

# This code handles inputs, like getting the players intended 3D direction from a 2D input, or even basic buttons
# Add this as a child node to any component that needs input like the physics manager or player controller
# By the time you read this I may already have made all dependent components a dedicated scene with this component
# If I do this, you won't need to worry about this for the default components

# the node that is used to create the wish direction, the direction that the player wants to move

var is_boost_pressed: bool
var is_jump_pressed: bool
var is_drift_pressed: bool
var is_attack_pressed: bool
var is_rise_pressed: bool
var is_stomp_pressed: bool
var is_far_pressed: bool

var wish_dir_basis: Basis
var ground_normal: Vector3 = Vector3(0, 1, 0)
var wish_dir: Vector3 = Vector3(0, 0, 0)
var cam_input: Vector2 = Vector2(0, 0)
var input_dir: Vector2 = Vector2(0, 0)
var first_frame = true

signal boost_pressed
signal jump_pressed
signal drift_pressed
signal attack_pressed
signal rise_pressed
signal stomp_pressed
# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if first_frame:
		wish_dir = Vector3.ZERO
		first_frame = false
		return
	
	cam_input = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	is_boost_pressed = Input.is_action_pressed("boost")
	is_jump_pressed = Input.is_action_pressed("jump")
	is_drift_pressed = Input.is_action_pressed("drift")
	is_attack_pressed = Input.is_action_pressed("attack")
	is_rise_pressed = Input.is_action_pressed("rise")
	is_stomp_pressed = Input.is_action_pressed("stomp")
	is_far_pressed = Input.is_action_pressed("far")
	if Input.is_action_just_pressed("boost"):
		emit_signal("boost_pressed")
	if Input.is_action_just_pressed("jump"):
		emit_signal("jump_pressed")
	if Input.is_action_just_pressed("drift"):
		emit_signal("drift_pressed")
	if Input.is_action_just_pressed("attack"):
		emit_signal("attack_pressed")
	# clamp the length of input direction if it goes above 1
	if input_dir.length() > 1:
		input_dir = input_dir.normalized()
	
	wish_dir = (wish_dir_basis * Vector3(input_dir.x, 0, input_dir.y))
		
	
	#print(wish_dir_basis.y)

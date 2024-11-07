extends Control
class_name HPBar

@onready var progress_bar = $TextureProgressBar
@onready var label = $Label

var oscillation_speed = 2.0  # Adjust this to change the speed of oscillation
var oscillation_amplitude = 30.0  # Adjust this to change the amount of oscillation

func _ready():
	progress_bar.value = 88
	update_tint()

func _process(delta):
	get_input()
	update_label()
	update_tint()
	oscillate_texture(delta)

func get_input():
	if Input.is_action_pressed("ui_up") and progress_bar.value < 88:
		progress_bar.value += 1
	if Input.is_action_pressed("ui_down") and progress_bar.value > 37:
		progress_bar.value -= 1

func update_label():
	label.text = str(progress_bar.value) + "%"

func update_tint():
	var health_percentage = (progress_bar.value - 37) / (88 - 37)
	var tint_color = Color.RED.lerp(Color.WHITE, health_percentage)
	progress_bar.tint_progress = tint_color

func oscillate_texture(_delta):
	var offset = sin(Time.get_ticks_msec() * oscillation_speed * 0.001) * oscillation_amplitude
	progress_bar.texture_progress_offset = Vector2(offset/2, offset)

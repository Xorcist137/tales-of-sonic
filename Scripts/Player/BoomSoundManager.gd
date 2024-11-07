extends Node3D

enum BoostState {
	NORMAL = 0,
	BOOST = 1,
}

##@export var boost_sound_path: AudioStreamPlayer
##@export var wind_sound_path: AudioStreamPlayer
##@export var roll_sound_path: AudioStreamPlayer

@onready var boost_sound: AudioStreamPlayer = $"BoostSoundPlayer"
@onready var wind_sound: AudioStreamPlayer = $"WindSoundPlayer"
@onready var jump_sound: AudioStreamPlayer = $"JumpSoundPlayer"
@onready var hud_vars: HUDStatics = $"/root/HudStatics"

var original_boost_volume_db: float
var original_wind_volume_db: float
var original_jump_volume_db: float

# Called when the node enters the scene tree for the first time.
func _ready():
	wind_sound.volume_db = -120
	wind_sound.play()
	original_boost_volume_db = boost_sound.volume_db
	original_wind_volume_db = wind_sound.volume_db
	original_jump_volume_db = jump_sound.volume_db

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	wind_sound.volume_db = clampf(hud_vars.current_speed - 40, -40, 10)
	wind_sound.pitch_scale = clampf((hud_vars.current_speed + 1)/60, 1, 4)


func _on_boom_movement_state_component_boost_state_changed(boost_state, boost_state_prev):
	match boost_state:
		BoostState.NORMAL:
			return
		BoostState.BOOST:
			play_sound(boost_sound, 50)


func _on_boom_movement_state_component_just_jumped():
	jump_sound.play()

func play_sound(sound: AudioStreamPlayer, volume_percent: float = 100.0):
	var original_volume = get_original_volume(sound)
	var volume_change = linear_to_db(volume_percent / 100.0)
	sound.volume_db = original_volume + volume_change
	sound.play()
	# Reset volume to original after playing
	sound.finished.connect(func(): sound.volume_db = original_volume, CONNECT_ONE_SHOT)

func get_original_volume(sound: AudioStreamPlayer) -> float:
	match sound:
		boost_sound: return original_boost_volume_db
		wind_sound: return original_wind_volume_db
		jump_sound: return original_jump_volume_db
		_: return 0.0  # Default case, shouldn't occur

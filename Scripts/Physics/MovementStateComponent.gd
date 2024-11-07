extends Node3D
class_name MovementStateComponent

##@export var movement_forces_component_path: MovementForcesComponent
##@export var suspension_component_path: SuspensionComponent
##@export var coyote_jump_timer_path: Timer

@onready var movement_forces_component: MovementForcesComponent = $"../MovementForcesComponent"
@onready var boom_movement_state: BoomMovementStateComponent = $"../BoomMovementStateComponent"
@onready var suspension_component: SuspensionComponent = $"..//SuspensionComponent"
@onready var coyote_jump_timer: Timer = $"../CoyoteJumpTimer"

@onready var controls: Controls = $"/root/GameControls"
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"

@export var traction_base: float = 2500
@export var air_control: float = 1250
@export var can_coyote_jump: bool = false
@export var slope_jump_mul: float = 1

var jump_available: bool = true
var has_jumped: bool = false

enum GroundedState {
	GROUND = 0,
	AIR = 1,
}


var grounded_state_prev = GroundedState.GROUND
var grounded_state = GroundedState.GROUND

var jump_location: Vector3 = Vector3(0,0,0)
var land_location: Vector3 = Vector3(0,0,0)

# Called when the node enters the scene tree for the first time.
func _ready():
	coyote_jump_timer.timeout.connect(_on_coyote_jump_timeout.bind())
	controls.jump_pressed.connect(_on_controls_jump_pressed.bind())
	movement_forces_component.slope_jump_mul = slope_jump_mul
	movement_forces_component.set_airborne.connect(_on_set_airborne.bind())
	print("ready")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if (grounded_state == 1) and (grounded_state_prev == 0):
		jump_location = global_position
	if (grounded_state == 0) and (grounded_state_prev == 1):
		land_location = global_position
		print((land_location - jump_location).length())
	grounded_state_prev = grounded_state
	if spatial_vars.grounded == true:
		grounded_state = GroundedState.GROUND
	else:
		grounded_state = GroundedState.AIR
	
	if grounded_state_prev != grounded_state:
		#emit_signal("grounded_state_changed", grounded_state, grounded_state_prev)
		if grounded_state == GroundedState.GROUND:
			jump_available = true
		if grounded_state == GroundedState.AIR:
			coyote_jump_timer.start()
	
	match grounded_state:
		GroundedState.GROUND:
			state_ground()
		GroundedState.AIR:
			state_air()
	
	#print(jump_available)

func state_ground():
	if not controls.is_jump_pressed:
		jump_available = true
		has_jumped = false
	movement_forces_component.traction_base = traction_base
	movement_forces_component.ground_move()
	suspension_component.suspension_length = 4

func state_air():
	if can_coyote_jump == false:
		jump_available = false
	movement_forces_component.air_move()
	if has_jumped and not controls.is_jump_pressed:
		movement_forces_component.end_jump()
	suspension_component.suspension_length = 2
	

func jump():
	jump_available = false
	has_jumped = true
	suspension_component.jump()
	movement_forces_component.jump(slope_jump_mul)

func _on_coyote_jump_timeout():
	jump_available = false
	coyote_jump_timer.stop()

func _on_controls_jump_pressed():
	if jump_available and boom_movement_state.can_jump:
		jump()
func _on_set_airborne():
	grounded_state = GroundedState.AIR
	jump_available = false
	suspension_component.jump()
		

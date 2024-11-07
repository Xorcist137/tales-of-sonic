extends Node
class_name FarSlashAbility

signal ability_started
signal ability_ended
@onready var spatial_vars: SpatialVarStatics = $"/root/SpatialVarStatics"
@export var windup_duration: float = 0.5
@export var projectile_speed: float = 90.0
@export var max_projectile_distance: float = 75.0
@export var explosion_radius: float = 5.0
@export var explosion_force: float = 500.0
@export var cooldown_duration: float = 1.0
@export var homing_strength: float = 1000.0
@export var max_homing_angle: float = 90.0
@onready var player_model = $"../SuspensionComponent"
@onready var projectile_node = $projectile_node
@onready var trail = $projectile_node/GPUParticles3D
@onready var smoke_trail = $projectile_node/GPUParticles3D2
@onready var projectile_mesh = $projectile_node/projectile
@onready var sparks_vfx = $projectile_node/explosion_vfx/sparks
@onready var flash_vfx = $projectile_node/explosion_vfx/flash
var target_position: Vector3
var initial_direction: Vector3

var is_active: bool = false
var player_body: RigidBody3D
var targeting_system: RayCast3D
var ability_system: AbilitySystem
var projectile: Area3D
var projectile_parent: Node
var current_time: float = 0.0
var has_target: bool = false
var projectile_start_position: Vector3

enum FarSlashPhase { WINDUP, PROJECTILE, COOLDOWN }
var current_phase: FarSlashPhase = FarSlashPhase.WINDUP

func _ready():
	player_body = get_parent()
	targeting_system = player_body.get_node("TargetManager")
	ability_system = get_node("/root/Abilities")
	projectile_parent = get_tree().get_root()
	create_projectile()

func can_use() -> bool:
	return not is_active and ability_system.is_ability_unlocked("far_slash") and current_phase == FarSlashPhase.WINDUP and !ability_system.is_ability_locked("far_slash")

func use():
	if can_use():
		perform_far_slash()

func perform_far_slash() -> void:
	if projectile_node.get_parent() != self:
		if projectile_node.is_inside_tree():
			projectile_node.get_parent().remove_child(projectile_node)
		add_child(projectile_node)
		projectile_node.add_to_group("targetable")
	
	is_active = true
	current_time = 0.0
	current_phase = FarSlashPhase.WINDUP
	if spatial_vars.grounded:
		player_body.set_linear_velocity(player_body.get_linear_velocity() * 0.4)
	else:
		player_body.set_linear_velocity(player_body.get_linear_velocity() * 0.1)
	emit_signal("ability_started")
	
	# Check if there's a target
	has_target = targeting_system.get_current_target() != null

func _physics_process(delta):
	if is_active or current_phase != FarSlashPhase.WINDUP:
		current_time += delta
		
		match current_phase:
			FarSlashPhase.WINDUP:
				if has_target:
					player_model.update_facing_direction(targeting_system.get_target_vector())
				player_body.set_gravity_scale(0)
				if current_time >= windup_duration - 0.15:
					launch_projectile()
			
			FarSlashPhase.PROJECTILE:
				update_projectile(delta)
			
			FarSlashPhase.COOLDOWN:
				if current_time >= cooldown_duration:
					end_ability()

func launch_projectile():
	if projectile_node.get_parent() == self:
		remove_child(projectile_node)
		projectile_parent.add_child(projectile_node)
	projectile_node.global_transform.origin = player_body.global_transform.origin + Vector3(0, 1.5, 0)
	projectile_start_position = projectile_node.global_transform.origin
	current_phase = FarSlashPhase.PROJECTILE
	current_time = 0.0
	projectile_node.visible = true
	projectile_mesh.visible = true
	trail.emitting = true
	smoke_trail.emitting = true
	
	if has_target:
		initial_direction = (targeting_system.entity_position - projectile_node.global_transform.origin).normalized()
		target_position = targeting_system.entity_position
	else:
		# Calculate the 30-degree downward angle
		var facing_direction = player_model.facing_direction
		var downward_angle = deg_to_rad(0)
		if !spatial_vars.grounded:
			downward_angle = deg_to_rad(-30)
		initial_direction = (facing_direction.rotated(facing_direction.cross(Vector3.UP).normalized(), downward_angle)).normalized()
		target_position = projectile_node.global_transform.origin + initial_direction * max_projectile_distance
	
	projectile_node.look_at(projectile_node.global_transform.origin + initial_direction, Vector3.UP)
	
	is_active = false

func update_projectile(delta):
	var current_direction = initial_direction
	if has_target:
		var new_target_position = targeting_system.entity_position
		var to_new_target = (new_target_position - projectile_node.global_transform.origin).normalized()
		var angle_to_new_target = current_direction.angle_to(to_new_target)
		if angle_to_new_target <= deg_to_rad(max_homing_angle):
			current_direction = current_direction.slerp(to_new_target, homing_strength * delta)
			target_position = new_target_position

	var movement = current_direction * projectile_speed * delta
	projectile_node.global_transform.origin += movement
	projectile_node.look_at(projectile_node.global_transform.origin + current_direction, Vector3.UP)
	
	var distance_traveled = (projectile_node.global_transform.origin - projectile_start_position).length()
	if distance_traveled >= max_projectile_distance or projectile_node.global_transform.origin.distance_to(target_position) < 1.0:
		explode_projectile()

func explode_projectile():
	trail.emitting = false
	smoke_trail.emitting = false
	projectile_mesh.visible = false
	var explosion_position = projectile_node.global_transform.origin
	flash_vfx.restart()
	sparks_vfx.restart()
	# Apply explosion force to nearby bodies
	# ... (rest of your explosion code)
	
	# Set up a timer to reset the projectile_node after particles fade
	var timer = Timer.new()
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_particle_fade_timeout"))
	timer.set_wait_time(smoke_trail.lifetime)
	timer.set_one_shot(true)
	timer.start()
	
	current_phase = FarSlashPhase.COOLDOWN
	current_time = 0.0

func _on_particle_fade_timeout():
	if projectile_node.is_inside_tree():
		projectile_node.get_parent().remove_child(projectile_node)
	add_child(projectile_node)
	projectile_node.visible = false
	# Reset the projectile_node's transform
	projectile_node.transform = Transform3D.IDENTITY

func end_ability():
	is_active = false
	emit_signal("ability_ended")
	current_phase = FarSlashPhase.WINDUP

func create_projectile():
	projectile = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	collision_shape.shape = sphere_shape
	projectile.add_child(collision_shape)
	
	# Connect the body_entered signal to handle collisions
	projectile.connect("body_entered", Callable(self, "_on_projectile_body_entered"))
	
	# Add the projectile (Area3D) to the projectile_node
	projectile_node.add_child(projectile)
	
	# Ensure the projectile_node is initially invisible
	projectile_node.visible = false

func _on_projectile_body_entered(body):
	if body != player_body and current_phase == FarSlashPhase.PROJECTILE:
		explode_projectile()

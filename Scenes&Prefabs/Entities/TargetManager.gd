extends RayCast3D

@export var max_distance: float = 50.0
@export var target_group: String = "targetable"
@export var player: Node3D
@export var sphere_cast_radius: float = 50.0
@export var min_vertical_angle: float = 35.0  # Minimum angle from vertical axis (in degrees)

@onready var reticle: Sprite3D = $Reticle
@onready var player_model = $"../SuspensionComponent"
var current_target: Node3D = null
var entity_position: Vector3 = Vector3.ZERO

func _ready():
	if not player:
		player = get_parent()
	reticle.visible = false

func _physics_process(_delta):
	update_targeting()
	update_reticle()

func update_targeting():
	var space_state = get_world_3d().direct_space_state
	var player_pos = player.global_transform.origin
	var player_up = player.global_transform.basis.y
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = sphere_cast_radius
	query.transform = Transform3D(Basis(), player_pos)
	query.collision_mask = 1  # Adjust this to match your collision layers
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var results = space_state.intersect_shape(query, 32)  # 32 is max results, adjust if needed

	var best_score = -INF
	current_target = null
	for result in results:
		var collider = result["collider"]
		if collider.is_in_group(target_group):
			var target_pos = collider.global_transform.origin
			var distance = player_pos.distance_to(target_pos)
			
			if distance > max_distance:
				continue

			var to_target = (target_pos - player_pos).normalized()
			
			# Check vertical angle
			var angle_from_vertical = rad_to_deg(acos(abs(to_target.dot(player_up))))
			if angle_from_vertical < min_vertical_angle:
				continue

			# Calculate dot product to prioritize targets in the facing direction
			var direction_score = player_model.facing_direction.dot(to_target)
			
			# Combine distance and direction for final score (higher is better)
			var score = direction_score * 5 - distance / max_distance  # Normalize distance and adjust weights

			if score > best_score:
				best_score = score
				current_target = collider
				entity_position = target_pos

func update_reticle():
	if current_target:
		reticle.visible = true
		reticle.global_transform.origin = entity_position
	else:
		reticle.visible = false

func get_target_vector() -> Vector3:
	if current_target:
		return entity_position - player.global_transform.origin
	return Vector3.ZERO

func get_current_target() -> Node3D:
	return current_target

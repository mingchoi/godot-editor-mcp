extends Area3D

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $Collision

var is_held: bool = false
var is_dragging: bool = false
var drag_offset: Vector3 = Vector3.ZERO
var color_time: float = 0.0
var mouse_down_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 5.0

# Size feedback
var base_scale: Vector3 = Vector3.ONE
var target_scale: Vector3 = Vector3.ONE
var scale_speed: float = 8.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_mouse_over(event.position):
				is_held = true
				is_dragging = false
				mouse_down_pos = event.position
				color_time = 0.0
				# Click feedback: scale up on press
				target_scale = base_scale * 1.2
				var plane := Plane(Vector3.UP, global_position.y)
				var mouse_pos_3d: Vector3 = _get_mouse_world_position(event.position, plane)
				drag_offset = global_position - mouse_pos_3d
		else:
			if is_held:
				if not is_dragging:
					# Was a click (not drag) — cycle to a new random size
					_cycle_size()
				is_held = false
				is_dragging = false
				# Scale back to current base
				target_scale = base_scale

	elif event is InputEventMouseMotion and is_held:
		var dist: float = event.position.distance_to(mouse_down_pos)
		if dist > DRAG_THRESHOLD:
			is_dragging = true
		if is_dragging:
			var plane := Plane(Vector3.UP, global_position.y)
			var mouse_pos_3d: Vector3 = _get_mouse_world_position(event.position, plane)
			global_position = mouse_pos_3d + drag_offset

func _cycle_size() -> void:
	# Pick a random scale between 0.5 and 2.0
	var s := randf_range(0.5, 2.0)
	base_scale = Vector3.ONE * s

func _is_mouse_over(mouse_pos: Vector2) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [self])
	var result: Dictionary = space_state.intersect_ray(query)
	return result.size() > 0

func _get_mouse_world_position(mouse_pos: Vector2, plane: Plane) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = camera.project_ray_normal(mouse_pos)
	var result: Variant = plane.intersects_ray(from, dir)
	if result is Vector3:
		return result
	return global_position

func _process(delta: float) -> void:
	# Smooth scale interpolation
	scale = scale.lerp(target_scale, delta * scale_speed)

	if is_held:
		color_time += delta * 2.0
		var hue: float = fmod(color_time, 1.0)
		var new_color: Color = Color.from_hsv(hue, 0.8, 0.9)
		_ensure_material()
		var mat: Material = mesh_instance.get_surface_override_material(0)
		if mat and mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color = new_color

func _ensure_material() -> void:
	var mat: Material = mesh_instance.get_surface_override_material(0)
	if mat == null:
		var new_mat := StandardMaterial3D.new()
		new_mat.albedo_color = Color.WHITE
		mesh_instance.set_surface_override_material(0, new_mat)

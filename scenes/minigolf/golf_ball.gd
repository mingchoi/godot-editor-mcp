extends Node3D
## Golf ball with click-and-drag hitting mechanics
## Uses manual physics since we can't use RigidBody3D with proper collision shapes

signal ball_stopped

@export var max_hit_power: float = 2.0
@export var friction: float = 0.98
@export var min_velocity_threshold: float = 0.01
@export var bounce_damping: float = 0.7

var velocity: Vector3 = Vector3.ZERO
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var current_mouse_position: Vector2 = Vector2.ZERO
var is_stationary: bool = true
var stationary_timer: float = 0.0
const STATIONARY_TIME: float = 0.3

# Course boundaries (should match course size)
var bounds_min: Vector3 = Vector3(-5.9, 0, -3.9)
var bounds_max: Vector3 = Vector3(5.9, 0, 3.9)
var ball_radius: float = 0.25

@onready var game: Node3D = get_parent()

func _ready() -> void:
	set_process_input(true)
	set_process(true)

func _input(event: InputEvent) -> void:
	if game and game.has_method("is_game_won") and game.is_game_won():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_clicking_on_ball(event.position) and is_stationary:
				is_dragging = true
				drag_start_position = event.position
				current_mouse_position = event.position
		else:
			if is_dragging:
				_apply_hit()
				is_dragging = false

	elif event is InputEventMouseMotion and is_dragging:
		current_mouse_position = event.position

func _process(delta: float) -> void:
	# Apply friction
	velocity *= friction

	# Stop if very slow
	if velocity.length() < min_velocity_threshold:
		velocity = Vector3.ZERO
		stationary_timer += delta
		if stationary_timer >= STATIONARY_TIME and not is_stationary:
			is_stationary = true
			ball_stopped.emit()
	else:
		stationary_timer = 0.0
		is_stationary = false

		# Move ball
		var movement = velocity * delta * 60  # Scale by 60 for reasonable speed
		position += movement

		# Boundary collision
		_handle_boundary_collision()

func _handle_boundary_collision() -> void:
	# Check and bounce off walls
	if position.x - ball_radius < bounds_min.x:
		position.x = bounds_min.x + ball_radius
		velocity.x = -velocity.x * bounce_damping
	elif position.x + ball_radius > bounds_max.x:
		position.x = bounds_max.x - ball_radius
		velocity.x = -velocity.x * bounce_damping

	if position.z - ball_radius < bounds_min.z:
		position.z = bounds_min.z + ball_radius
		velocity.z = -velocity.z * bounce_damping
	elif position.z + ball_radius > bounds_max.z:
		position.z = bounds_max.z - ball_radius
		velocity.z = -velocity.z * bounce_damping

func _is_clicking_on_ball(screen_pos: Vector2) -> bool:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return false

	# Project ball position to screen
	var ball_screen = camera.unproject_position(global_position)

	# Check distance
	var distance = ball_screen.distance_to(screen_pos)
	return distance < 50  # 50 pixel tolerance

func _apply_hit() -> void:
	var drag_vector = drag_start_position - current_mouse_position
	var drag_length = drag_vector.length()

	if drag_length < 10:
		return

	# Convert screen drag to world direction
	var hit_direction = Vector3(drag_vector.x, 0, drag_vector.y).normalized()

	# Calculate power
	var power = min(drag_length / 80.0, 1.0) * max_hit_power

	# Set velocity
	velocity = hit_direction * power

	is_stationary = false
	stationary_timer = 0.0

	if game and game.has_method("add_stroke"):
		game.add_stroke()

	print("Hit! Power: ", power, " Direction: ", hit_direction)

func reset_to_position(pos: Vector3) -> void:
	velocity = Vector3.ZERO
	position = pos
	is_stationary = true
	stationary_timer = 0.0

func get_velocity() -> Vector3:
	return velocity

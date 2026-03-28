extends Node3D
## Hole detection for mini golf
## Checks if the ball is within hole radius and slow enough

signal ball_entered

@export var hole_radius: float = 0.4
@export var max_ball_speed: float = 0.5  # Max speed to fall in

var ball: Node3D = null
var ball_inside: bool = false

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if ball == null:
		_find_ball()
		return

	_check_ball()

func _find_ball() -> void:
	var parent = get_parent()
	if parent:
		ball = parent.get_node_or_null("Ball")

func _check_ball() -> void:
	if not ball:
		return

	# Check distance from hole center
	var distance = Vector2(
		ball.position.x - position.x,
		ball.position.z - position.z
	).length()

	if distance < hole_radius:
		# Ball is over hole
		var ball_velocity = ball.get("velocity")
		if ball_velocity and ball_velocity.length() < max_ball_speed:
			if not ball_inside:
				ball_inside = true
				_capture_ball()
	else:
		ball_inside = false

func _capture_ball() -> void:
	# Disable ball movement
	if ball:
		ball.set("velocity", Vector3.ZERO)

		# Move ball to hole center and sink
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ball, "position:x", position.x, 0.3)
		tween.tween_property(ball, "position:z", position.z, 0.3)
		tween.chain()
		tween.tween_property(ball, "position:y", -0.5, 0.5)
		tween.tween_callback(func(): ball_entered.emit())

	print("Ball captured in hole!")

extends Node3D
## Main mini golf game controller

signal ball_in_hole
signal stroke_completed

@export var max_strokes: int = 10

var strokes: int = 0
var ball_start_position: Vector3 = Vector3(-4, 0.25, 0)
var game_won: bool = false

@onready var ball = $Ball
@onready var hole = $Hole

func _ready() -> void:
	# Store ball start position
	if ball:
		ball_start_position = ball.position
		ball.ball_stopped.connect(_on_ball_stopped)

	if hole:
		hole.ball_entered.connect(_on_ball_entered_hole)

	print("Mini Golf Ready! Click and drag on the ball to hit it.")

func _on_ball_stopped() -> void:
	stroke_completed.emit()
	print("Ball stopped. Total strokes: ", strokes)

	if game_won:
		return

	# Check if ball fell off course (y < -1)
	if ball and ball.position.y < -1:
		print("Ball fell off! Resetting...")
		reset_ball()

func _on_ball_entered_hole() -> void:
	game_won = true
	print("========================================")
	print("HOLE IN ", strokes, "!")
	if strokes == 1:
		print("HOLE IN ONE! AMAZING!")
	elif strokes <= 3:
		print("Great shot!")
	print("========================================")
	ball_in_hole.emit()

func reset_ball() -> void:
	if ball and ball.has_method("reset_to_position"):
		ball.reset_to_position(ball_start_position)

func get_strokes() -> int:
	return strokes

func add_stroke() -> void:
	strokes += 1

func is_game_won() -> bool:
	return game_won

extends Node3D

var goals: Array[Node] = []
var total_goals: int = 0

func _ready() -> void:
	# Find all goals in the scene
	goals = get_tree().get_nodes_in_group("goals")
	total_goals = goals.size()

	# Connect to each goal's signals
	for goal in goals:
		goal.box_entered.connect(_on_box_entered_goal)
		goal.box_exited.connect(_on_box_exited_goal)

	print("Sokoban level loaded. Goals to fill: ", total_goals)

func _on_box_entered_goal() -> void:
	_check_win()

func _on_box_exited_goal() -> void:
	# Win state might change when box exits
	pass

func _check_win() -> void:
	var filled_goals := 0
	for goal in goals:
		if goal.has_box():
			filled_goals += 1

	print("Goals filled: ", filled_goals, " / ", total_goals)

	if filled_goals == total_goals and total_goals > 0:
		print("========================================")
		print("🎉 CONGRATULATIONS! YOU WIN! 🎉")
		print("All ", total_goals, " goal(s) have been filled!")
		print("========================================")

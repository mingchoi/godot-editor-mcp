extends Node
## GameManager — connects all systems, handles global key bindings, updates UI.
## Attach this to a "GameManager" node under the scene root.

# --- Node References ---
var _player: Node
var _monster: Node
var _health_bar: ProgressBar
var _mana_bar: ProgressBar
var _combat_log: RichTextLabel
var _instructions: Label


func _ready() -> void:
	# Wait a frame for all nodes to be ready
	await get_tree().process_frame
	_find_nodes()
	_connect_signals()


func _find_nodes() -> void:
	# Try multiple path strategies for runtime compatibility
	# Strategy 1: Relative from GameManager (sibling of scene root children)
	_player = _find_node_safe("../Player")
	_monster = _find_node_safe("../Monster")
	
	# Fallback: try absolute paths
	if not _player:
		_player = _find_node_safe("/root/ArpgBasic/Player")
	if not _monster:
		_monster = _find_node_safe("/root/ArpgBasic/Monster")
	
	# Fallback: search by group/type
	if not _player:
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]
	
	var ui: CanvasLayer = _find_node_safe("../UI") as CanvasLayer
	if not ui:
		ui = _find_node_safe("/root/ArpgBasic/UI") as CanvasLayer
	if ui:
		_health_bar = ui.get_node_or_null("HealthBarContainer/HealthBar")
		_mana_bar = ui.get_node_or_null("HealthBarContainer/ManaBar")
		_combat_log = ui.get_node_or_null("CombatLog")
		_instructions = ui.get_node_or_null("Instructions")


func _find_node_safe(path: String) -> Node:
	return get_node_or_null(path) if has_node(path) else null


func _connect_signals() -> void:
	if _player:
		# Add player to "player" group so monster can find it
		if not _player.is_in_group("player"):
			_player.add_to_group("player")
		
		if _player.has_signal("health_changed"):
			_player.health_changed.connect(_on_player_health_changed)
		if _player.has_signal("mana_changed"):
			_player.mana_changed.connect(_on_player_mana_changed)
		if _player.has_signal("combat_message"):
			_player.combat_message.connect(_on_combat_message)
		if _player.has_signal("died"):
			_player.died.connect(_on_player_died)
	
	if _monster:
		if _monster.has_signal("health_changed"):
			_monster.health_changed.connect(_on_monster_health_changed)
		if _monster.has_signal("combat_message"):
			_monster.combat_message.connect(_on_combat_message)
		if _monster.has_signal("died"):
			_monster.died.connect(_on_monster_died)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_do_reset()
			KEY_T:
				_do_toggle_monster_attack()


func _do_reset() -> void:
	if _player and _player.has_method("reset_player"):
		_player.reset_player()
	if _monster and _monster.has_method("reset_monster"):
		_monster.reset_monster()
	_append_combat_log("[b][color=cyan]=== FULL RESET ===[/color][/b]")


func _do_toggle_monster_attack() -> void:
	if _monster and _monster.has_method("toggle_attack"):
		_monster.toggle_attack()


# --- Signal Handlers ---

func _on_player_health_changed(current: int, maximum: int) -> void:
	if _health_bar:
		_health_bar.value = current
		_health_bar.max_value = maximum


func _on_player_mana_changed(current: int, maximum: int) -> void:
	if _mana_bar:
		_mana_bar.value = current
		_mana_bar.max_value = maximum


func _on_monster_health_changed(current: int, _maximum: int) -> void:
	pass  # Could add monster health bar later


func _on_combat_message(text: String) -> void:
	_append_combat_log(text)


func _append_combat_log(text: String) -> void:
	if _combat_log:
		_combat_log.append_text(text + "\n")


func _on_player_died() -> void:
	pass  # Already handled by player's combat message


func _on_monster_died() -> void:
	pass  # Already handled by monster's combat message

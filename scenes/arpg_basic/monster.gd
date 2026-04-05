extends CharacterBody3D
class_name Monster

# --- Stats ---
@export var max_health: int = 80
@export var move_speed: float = 3.5
@export var attack_damage: int = 10
@export var attack_range: float = 2.5
@export var chase_range: float = 20.0
@export var attack_cooldown: float = 1.2
@export var respawn_time: float = 4.0

# --- Internal State ---
var current_health: int = 80
var is_dead: bool = false
var attack_enabled: bool = true
var _attack_timer: float = 0.0
var _respawn_timer: float = 0.0
var _player_ref: CharacterBody3D

# --- Node References ---
var _attack_area: Area3D
var _attack_visual: MeshInstance3D

# --- Signals ---
signal health_changed(current: int, maximum: int)
signal died
signal damage_dealt(target: Node, amount: int)
signal combat_message(text: String)


func _ready() -> void:
	current_health = max_health
	_attack_area = get_node("AttackArea")
	
	if _attack_area:
		_attack_visual = _create_attack_visual(_attack_area, Vector3(2.0, 2.0, 2.0), Color(1.0, 0.3, 0.3, 0.5))
		_attack_area.body_entered.connect(_on_attack_body_entered)
		_attack_area.monitoring = false
	
	# Create facing indicator (red cone so you can see which way monster faces)
	_create_facing_indicator()


func _create_attack_visual(parent: Area3D, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "AttackVisual"
	mesh_instance.mesh = BoxMesh.new()
	mesh_instance.mesh.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.visible = false
	parent.add_child(mesh_instance)
	return mesh_instance


func _create_facing_indicator() -> void:
	# Small yellow box on front of monster so you can see which way it faces
	var indicator: MeshInstance3D = MeshInstance3D.new()
	indicator.name = "FacingIndicator"
	indicator.mesh = BoxMesh.new()
	indicator.mesh.size = Vector3(0.15, 0.15, 0.35)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0)  # yellow for monster
	indicator.set_surface_override_material(0, mat)
	indicator.position = Vector3(0.0, 0.5, -0.7)  # front of capsule
	add_child(indicator)


func _physics_process(delta: float) -> void:
	if is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()
		return
	
	if not attack_enabled:
		return
	
	# Find player reference
	if not _player_ref:
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player_ref = players[0]
	
	if not _player_ref:
		return
	
	var player_node: Node = _player_ref
	if not is_instance_valid(player_node):
		_player_ref = null
		return
	
	# Check if player is dead
	if player_node.has_method("is_dead") and player_node.is_dead():
		return
	
	var dist_to_player: float = global_position.distance_to(player_node.global_position)
	
	# Cooldown timer
	_attack_timer -= delta
	
	# Chase player if in range
	if dist_to_player <= chase_range:
		var dir: Vector3 = (player_node.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		
		look_at(global_position + dir, Vector3.UP)
		
		if dist_to_player > attack_range * 0.7:
			velocity = dir * move_speed
			velocity.y -= 20.0 * delta
			move_and_slide()
		
		# Attack if close enough and cooldown ready
		if dist_to_player <= attack_range and _attack_timer <= 0:
			perform_attack()


func perform_attack() -> void:
	if not _attack_area:
		return
	
	_attack_timer = attack_cooldown
	combat_message.emit("[color=orange]Monster attacks![/color]")
	_attack_area.monitoring = true
	if _attack_visual:
		_attack_visual.visible = true
	get_tree().create_timer(0.25).timeout.connect(func(): 
		if _attack_area: 
			_attack_area.monitoring = false
		if _attack_visual:
			_attack_visual.visible = false
	)


func take_damage(amount: int, attacker: Node = null) -> void:
	if is_dead:
		return
	
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	var source: String = "Player" if attacker else "Unknown"
	combat_message.emit("[color=red]Monster takes %d damage! (HP: %d/%d)[/color]" % [amount, current_health, max_health])
	
	if current_health <= 0:
		die()


func die() -> void:
	is_dead = true
	_respawn_timer = respawn_time
	visible = false
	
	# Disable collision
	var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col_shape:
		col_shape.disabled = true
	
	if _attack_area:
		_attack_area.monitoring = false
	if _attack_visual:
		_attack_visual.visible = false
	
	combat_message.emit("[color=green]Monster defeated! Respawning in %.1fs...[/color]" % respawn_time)
	died.emit()


func respawn() -> void:
	is_dead = false
	current_health = max_health
	_respawn_timer = 0.0
	visible = true
	position = Vector3(8.0, 1.0, 8.0)
	velocity = Vector3.ZERO
	
	var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col_shape:
		col_shape.disabled = false
	
	health_changed.emit(current_health, max_health)
	combat_message.emit("[color=gray]Monster has respawned![/color]")


func reset_monster() -> void:
	if is_dead:
		is_dead = false
		_respawn_timer = 0.0
		visible = true
		var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
		if col_shape:
			col_shape.disabled = false
	
	current_health = max_health
	attack_enabled = true
	_attack_timer = 0.0
	position = Vector3(8.0, 1.0, 8.0)
	velocity = Vector3.ZERO
	
	if _attack_area:
		_attack_area.monitoring = false
	if _attack_visual:
		_attack_visual.visible = false
	
	health_changed.emit(current_health, max_health)
	combat_message.emit("[color=cyan]Monster reset.[/color]")


func toggle_attack() -> void:
	attack_enabled = not attack_enabled
	var state: String = "ENABLED" if attack_enabled else "DISABLED"
	combat_message.emit("[color=yellow]Monster attack %s[/color]" % state)


# --- Signal Callbacks ---

func _on_attack_body_entered(body: Node3D) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage, self)
		damage_dealt.emit(body, attack_damage)

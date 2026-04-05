extends CharacterBody3D
class_name Player

# --- Stats ---
@export var max_health: int = 100
@export var max_mana: int = 100
@export var move_speed: float = 7.0
@export var basic_attack_damage: int = 15
@export var aoe_attack_damage: int = 25
@export var aoe_attack_cost: int = 20
@export var heal_amount: int = 30
@export var heal_cost: int = 25
@export var mana_regen_rate: float = 5.0

# --- Internal State ---
var current_health: int = 100
var current_mana: int = 100
var is_dead: bool = false
var facing_direction: Vector3 = Vector3.FORWARD
var mana_regen_accumulator: float = 0.0
var can_act: bool = true

# --- Node References ---
var _attack_area: Area3D
var _aoe_area: Area3D
var _attack_visual: MeshInstance3D
var _aoe_visual: MeshInstance3D
var _facing_indicator: MeshInstance3D

# --- Signals ---
signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal died
signal damage_dealt(target: Node, amount: int)
signal healed(amount: int)
signal combat_message(text: String)


func _ready() -> void:
	current_health = max_health
	current_mana = max_mana
	add_to_group("player")
	
	# Attack area: find MCP-created or create in code
	_attack_area = _find_area_child("AttackArea")
	if not _attack_area:
		_attack_area = _make_attack_area("AttackArea_Code")
	if _attack_area:
		if not _attack_area.is_connected("body_entered", _on_attack_body_entered):
			_attack_area.body_entered.connect(_on_attack_body_entered)
		_attack_area.monitoring = false
		_attack_visual = _create_attack_visual(_attack_area)
	
	# AOE area: always create in code for reliability
	_aoe_area = _make_aoe_area()
	if _aoe_area:
		_aoe_area.body_entered.connect(_on_aoe_body_entered)
		_aoe_area.monitoring = false
	
	# Visuals — same pattern as FacingIndicator which PROVES code meshes render
	_aoe_visual = _create_aoe_visual()
	_create_facing_indicator()
	
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)


# === Code-created areas ===

func _make_attack_area(area_name: String) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	var col := CollisionShape3D.new()
	col.name = "AttackCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 1.5)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	return area


func _make_aoe_area() -> Area3D:
	var area := Area3D.new()
	area.name = "AOEArea_Code"
	var col := CollisionShape3D.new()
	col.name = "AOECollision"
	var shape := SphereShape3D.new()
	shape.radius = 5.0
	col.shape = shape
	area.add_child(col)
	add_child(area)
	return area


# === Code-generated visuals — ALL use identical proven pattern ===

func _create_attack_visual(parent: Area3D) -> MeshInstance3D:
	"""Red box for melee attack. Same pattern as FacingIndicator."""
	var mi := MeshInstance3D.new()
	mi.name = "AttackVisual"
	mi.mesh = BoxMesh.new()
	mi.mesh.size = Vector3(2.0, 2.0, 1.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)  # red, semi-transparent
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.set_surface_override_material(0, mat)
	mi.visible = false
	parent.add_child(mi)
	return mi


func _create_aoe_visual() -> MeshInstance3D:
	"""Purple ring on ground. Uses SAME proven pattern as FacingIndicator.
	Tall enough to be clearly visible from any camera angle."""
	var mi := MeshInstance3D.new()
	mi.name = "AOEVisual"
	mi.mesh = BoxMesh.new()
	mi.mesh.size = Vector3(10.0, 1.0, 10.0)  # 1m tall — impossible to miss
	mi.position = Vector3(0.0, -0.1, 0.0)  # just below player center, mostly above ground
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.0, 1.0, 0.4)  # purple, semi-transparent
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.set_surface_override_material(0, mat)
	mi.visible = false
	add_child(mi)
	return mi


func _create_facing_indicator() -> void:
	"""White box on front of player — this PROVES code meshes work."""
	var indicator := MeshInstance3D.new()
	indicator.name = "FacingIndicator"
	indicator.mesh = BoxMesh.new()
	indicator.mesh.size = Vector3(0.15, 0.15, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	indicator.set_surface_override_material(0, mat)
	indicator.position = Vector3(0.0, 0.5, -0.7)
	add_child(indicator)
	_facing_indicator = indicator


# === Node finding helper ===

func _find_area_child(name_hint: String) -> Area3D:
	var direct := get_node_or_null(name_hint)
	if direct and direct is Area3D:
		return direct
	var found := find_child(name_hint, true, false)
	if found and found is Area3D:
		return found
	for child in get_children():
		if child is Area3D and (child.name == name_hint or child.name.find(name_hint) >= 0):
			return child
	return null


# === Game loop ===

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_movement(delta)
	_handle_mana_regen(delta)
	_handle_ability_keys()


func _handle_movement(delta: float) -> void:
	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		facing_direction = input_dir
		look_at(global_position + facing_direction, Vector3.UP)
	velocity = input_dir * move_speed
	velocity.y -= 20.0 * delta
	move_and_slide()


func _handle_mana_regen(delta: float) -> void:
	if current_mana < max_mana:
		mana_regen_accumulator += mana_regen_rate * delta
		if mana_regen_accumulator >= 1.0:
			var gained: int = int(mana_regen_accumulator)
			mana_regen_accumulator -= float(gained)
			current_mana = mini(max_mana, current_mana + gained)
			mana_changed.emit(current_mana, max_mana)


func _handle_ability_keys() -> void:
	if is_dead or not can_act:
		return
	if Input.is_key_pressed(KEY_J) and not _attack_j_held:
		_attack_j_held = true; basic_attack()
	elif not Input.is_key_pressed(KEY_J): _attack_j_held = false
	if Input.is_key_pressed(KEY_K) and not _attack_k_held:
		_attack_k_held = true; aoe_attack()
	elif not Input.is_key_pressed(KEY_K): _attack_k_held = false
	if Input.is_key_pressed(KEY_L) and not _attack_l_held:
		_attack_l_held = true; heal()
	elif not Input.is_key_pressed(KEY_L): _attack_l_held = false


var _attack_j_held: bool = false
var _attack_k_held: bool = false
var _attack_l_held: bool = false


# === Abilities ===

func basic_attack() -> void:
	if not _attack_area or _attack_area.monitoring:
		return
	combat_message.emit("[color=yellow]Basic Attack![/color]")
	_attack_area.monitoring = true
	if not _attack_visual:
		for child in _attack_area.get_children():
			if child is MeshInstance3D: _attack_visual = child; break
	if _attack_visual: _attack_visual.visible = true
	get_tree().create_timer(0.4).timeout.connect(func():
		_attack_area.monitoring = false
		if _attack_visual: _attack_visual.visible = false
	)


func aoe_attack() -> void:
	if not _aoe_area or current_mana < aoe_attack_cost or _aoe_area.monitoring:
		return
	current_mana -= aoe_attack_cost
	mana_changed.emit(current_mana, max_mana)
	combat_message.emit("[color=purple]AOE Attack! (%d MP)[/color]" % aoe_attack_cost)
	_aoe_area.monitoring = true
	if _aoe_visual: _aoe_visual.visible = true
	get_tree().create_timer(1.0).timeout.connect(func():
		_aoe_area.monitoring = false
		if _aoe_visual: _aoe_visual.visible = false
	)


func heal() -> void:
	if current_mana < heal_cost or current_health >= max_health:
		return
	current_mana -= heal_cost
	var actual_heal: int = mini(heal_amount, max_health - current_health)
	current_health += actual_heal
	mana_changed.emit(current_mana, max_mana)
	health_changed.emit(current_health, max_mana)
	healed.emit(actual_heal)
	combat_message.emit("[color=green]Healed for %d HP! (-%d MP)[/color]" % [actual_heal, heal_cost])


func take_damage(amount: int, attacker: Node = null) -> void:
	if is_dead: return
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_mana)
	var attacker_name: String = "Monster" if attacker else "Unknown"
	combat_message.emit("[color=red]Took %d damage from %s[/color]" % [amount, attacker_name])
	if current_health <= 0: die()


func die() -> void:
	is_dead = true
	combat_message.emit("[color=red]YOU DIED! Press R to reset.[/color]")
	died.emit()


func reset_player() -> void:
	is_dead = false
	current_health = max_health; current_mana = max_mana
	mana_regen_accumulator = 0.0; can_act = true
	facing_direction = Vector3.FORWARD
	position = Vector3(0.0, 1.0, 0.0); velocity = Vector3.ZERO; visible = true
	var col_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if col_shape: col_shape.disabled = false
	if _attack_area: _attack_area.monitoring = false
	if _attack_visual: _attack_visual.visible = false
	if _aoe_area: _aoe_area.monitoring = false
	if _aoe_visual: _aoe_visual.visible = false
	rotation = Vector3.ZERO
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)
	combat_message.emit("[color=cyan]Player fully restored.[/color]")


func _on_attack_body_entered(body: Node3D) -> void:
	if body == self: return
	if body.has_method("take_damage"):
		body.take_damage(basic_attack_damage, self)
		damage_dealt.emit(body, basic_attack_damage)


func _on_aoe_body_entered(body: Node3D) -> void:
	if body == self: return
	if body.has_method("take_damage"):
		body.take_damage(aoe_attack_damage, self)
		damage_dealt.emit(body, aoe_attack_damage)

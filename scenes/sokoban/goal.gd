extends Area3D

signal box_entered
signal box_exited

var boxes_in_goal: int = 0
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var glow_emission_energy: float = 2.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Get the mesh instance for glow effect
	mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance:
		# Get material and make it unique so we can modify it independently
		var mat = mesh_instance.get_surface_override_material(0)
		if mat and mat is StandardMaterial3D:
			material = mat.duplicate()
			mesh_instance.set_surface_override_material(0, material)

func _on_body_entered(body: Node) -> void:
	if body is RigidBody3D:
		boxes_in_goal += 1
		box_entered.emit()
		print("Box entered goal!")
		_update_glow(true)

func _on_body_exited(body: Node) -> void:
	if body is RigidBody3D:
		boxes_in_goal -= 1
		box_exited.emit()
		print("Box exited goal.")
		_update_glow(boxes_in_goal > 0)

func _update_glow(glow: bool) -> void:
	if material:
		material.emission_energy_multiplier = glow_emission_energy if glow else 0.0

func has_box() -> bool:
	return boxes_in_goal > 0

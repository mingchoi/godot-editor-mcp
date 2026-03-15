## Configuration Warning Result
## Represents the outcome of checking a single node's configuration warnings.
class_name ConfigurationWarningResult
extends RefCounted

## Absolute node path in the scene tree (e.g., "/root/Main/Player/CollisionShape2D")
var path: String

## Node name without path (e.g., "CollisionShape2D")
var node_name: String

## Godot class name (e.g., "CollisionShape2D", "RigidBody2D")
var godot_class_name: String

## Array of warning messages (empty if no warnings)
var warnings: PackedStringArray


func _init(p_path: String = "", p_node_name: String = "", p_class_name: String = "", p_warnings: PackedStringArray = []) -> void:
	path = p_path
	node_name = p_node_name
	godot_class_name = p_class_name
	warnings = p_warnings


## Returns true if this result has any warnings
func has_warnings() -> bool:
	return warnings.size() > 0


## Creates a ConfigurationWarningResult from a Node instance
static func from_node(node: Node) -> ConfigurationWarningResult:
	if node == null:
		return null
	return ConfigurationWarningResult.new(
		str(node.get_path()),
		node.name,
		node.get_class(),
		node._get_configuration_warnings()
	)


## Converts the result to a Dictionary for MCP response
func to_dict() -> Dictionary:
	return {
		"path": path,
		"node_name": node_name,
		"class_name": godot_class_name,
		"warnings": warnings
	}

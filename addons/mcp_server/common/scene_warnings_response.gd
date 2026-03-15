## Scene Warnings Response
## Aggregate response containing warnings for multiple nodes in a scene.
## Only nodes with warnings are included (no entries for nodes without warnings).
class_name SceneWarningsResponse
extends RefCounted

## Array of warning results for nodes with warnings
var warnings: Array = []

## Total number of nodes scanned in the scene
var total_nodes_checked: int = 0

## Number of nodes that have warnings
var nodes_with_warnings: int = 0


func _init(p_warnings: Array = [], p_total: int = 0, p_with_warnings: int = 0) -> void:
	warnings = p_warnings
	total_nodes_checked = p_total
	nodes_with_warnings = p_with_warnings


## Adds a warning result to the response and increments the warning count
func add_warning(result: ConfigurationWarningResult) -> void:
	warnings.append(result)
	nodes_with_warnings += 1


## Converts the response to a Dictionary for MCP response
func to_dict() -> Dictionary:
	var warnings_dict: Array[Dictionary] = []
	for warning in warnings:
		warnings_dict.append(warning.to_dict())
	return {
		"warnings": warnings_dict,
		"total_nodes_checked": total_nodes_checked,
		"nodes_with_warnings": nodes_with_warnings
	}

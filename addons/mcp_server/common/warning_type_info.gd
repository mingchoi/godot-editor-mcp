## Warning Type Info
## Metadata about warnings for a specific node class, used for the "query warning types" feature.
class_name WarningTypeInfo
extends RefCounted

## Godot class name
var godot_class_name: String

## Whether this class has defined warnings
var has_warnings: bool

## Extracted warning patterns/descriptions (may contain C++ code snippets)
var warning_patterns: PackedStringArray

## List of parent class names in the hierarchy
var parent_classes: PackedStringArray


func _init(p_class_name: String = "", p_has_warnings: bool = false, p_warning_patterns: PackedStringArray = [], p_parent_classes: PackedStringArray = []) -> void:
	godot_class_name = p_class_name
	has_warnings = p_has_warnings
	warning_patterns = p_warning_patterns
	parent_classes = p_parent_classes


## Converts the info to a Dictionary for MCP response
func to_dict() -> Dictionary:
	return {
		"class_name": godot_class_name,
		"has_warnings": has_warnings,
		"warning_patterns": warning_patterns,
		"parent_classes": parent_classes
	}

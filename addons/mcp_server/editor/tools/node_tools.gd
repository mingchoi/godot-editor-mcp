## Node Operations Tools
## MCP tools for node operations in the edited scene.
extends RefCounted
class_name NodeTools

const TOOL_GET := "node_get"
const TOOL_GET_PROPERTY := "node_get_property"
const TOOL_SET_PROPERTY := "node_set_property"
const TOOL_CREATE := "node_create"
const TOOL_DELETE := "node_delete"
const TOOL_LIST_CHILDREN := "node_list_children"
const TOOL_DUPLICATE := "node_duplicate"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("NodeTools") if logger else MCPLogger.new("[NodeTools]")
	_editor_interface = editor_interface


## Registers all node tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_get_tool())
	registry.register(_create_get_property_tool())
	registry.register(_create_set_property_tool())
	registry.register(_create_create_tool())
	registry.register(_create_delete_tool())
	registry.register(_create_list_children_tool())
	registry.register(_create_duplicate_tool())


func _create_get_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_GET,
			"Gets detailed information about a node",
			{
				"path": {
					"type": "string",
					"description": "Node path (e.g., 'Main/Player' or '/root/Main/Player')"
				},
				"include_properties": {
					"type": "boolean",
					"default": false,
					"description": "Include all property values"
				},
				"include_children": {
					"type": "boolean",
					"default": false,
					"description": "Include list of child node names"
				}
			},
			["path"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_get(params)
	)


func _create_get_property_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_GET_PROPERTY,
			"Gets a specific property value from a node",
			{
				"path": {"type": "string", "description": "Node path"},
				"property": {"type": "string", "description": "Property name"}
			},
			["path", "property"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_get_property(params)
	)


func _create_set_property_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_SET_PROPERTY,
			"Sets a property value on a node",
			{
				"path": {"type": "string", "description": "Node path"},
				"property": {"type": "string", "description": "Property name"},
				"value": {"description": "New property value"}
			},
			["path", "property", "value"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_set_property(params)
	)


func _create_create_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_CREATE,
			"Creates a new node",
			{
				"type": {"type": "string", "description": "Node type (e.g., 'Sprite2D', 'Node2D')"},
				"name": {"type": "string", "description": "Node name (auto-generated if not provided)"},
				"parent": {"type": "string", "description": "Parent node path"},
				"properties": {"type": "object", "default": {}, "description": "Initial property values"}
			},
			["type", "parent"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_create(params)
	)


func _create_delete_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_DELETE,
			"Deletes a node",
			{
				"path": {"type": "string", "description": "Node path to delete"}
			},
			["path"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_delete(params)
	)


func _create_list_children_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_LIST_CHILDREN,
			"Lists all children of a node",
			{
				"path": {"type": "string", "description": "Parent node path"},
				"recursive": {"type": "boolean", "default": false, "description": "Include all descendants"}
			},
			["path"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_list_children(params)
	)


func _create_duplicate_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_DUPLICATE,
			"Duplicates a node",
			{
				"path": {"type": "string", "description": "Node to duplicate"},
				"new_name": {"type": "string", "description": "Name for the duplicate"}
			},
			["path"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_duplicate(params)
	)


# --- Tool Implementations ---

func _resolve_node(path: String) -> Node:
	if _editor_interface == null:
		return null

	var root: Node = _editor_interface.get_edited_scene_root()
	if root == null:
		return null

	# Handle absolute paths
	if path.begins_with("/root/"):
		# Remove /root/ prefix and get from scene root
		var relative_path: String = path.substr(6)
		return root.get_node_or_null(relative_path)

	# Handle relative paths from scene root
	return root.get_node_or_null(path)


func _execute_get(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")
	var include_properties: bool = params.get("include_properties", false)
	var include_children: bool = params.get("include_children", false)

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	var data: Dictionary = {
		"path": path,
		"name": node.name,
		"type": node.get_class(),
		"script": node.get_script().resource_path if node.get_script() != null else ""
	}

	if include_properties:
		data["properties"] = _get_node_properties(node)

	if include_children:
		var children: Array[String] = []
		for child: Node in node.get_children():
			children.append(child.name)
		data["children"] = children

	return MCPToolResult.text("Node: %s (%s)" % [node.name, node.get_class()], data)


func _execute_get_property(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")
	var property: String = params.get("property", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	if not property in node:
		return MCPToolResult.error("Property not found: %s" % property, MCPError.Code.NOT_FOUND)

	var value: Variant = node.get(property)
	var value_type: String = type_string(typeof(value))

	var data: Dictionary = {
		"path": path,
		"property": property,
		"value": _variant_to_json(value),
		"type": value_type
	}

	return MCPToolResult.text("%s: %s" % [property, str(value)], data)


func _execute_set_property(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")
	var property: String = params.get("property", "")
	var value: Variant = params.get("value")

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	var old_value: Variant = node.get(property)
	node.set(property, value)

	_logger.info("Property set", {"path": path, "property": property, "old": old_value, "new": value})

	return MCPToolResult.text("Set %s = %s" % [property, str(value)], {
		"path": path,
		"property": property,
		"old_value": _variant_to_json(old_value),
		"new_value": _variant_to_json(value)
	})


func _execute_create(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var node_type: String = params.get("type", "")
	var node_name: String = params.get("name", "")
	var parent_path: String = params.get("parent", "")
	var properties: Dictionary = params.get("properties", {})

	# Validate type
	if not ClassDB.class_exists(node_type):
		return MCPToolResult.error("Unknown node type: %s" % node_type, MCPError.Code.INVALID_PARAMS)

	# Get parent
	var parent: Node = _resolve_node(parent_path)
	if parent == null:
		return MCPToolResult.error("Parent node not found: %s" % parent_path, MCPError.Code.NOT_FOUND)

	# Create node
	var new_node: Node = ClassDB.instantiate(node_type)
	if new_node == null:
		return MCPToolResult.error("Failed to create node of type: %s" % node_type, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Set name
	if node_name.is_empty():
		node_name = node_type
	new_node.name = node_name

	# Set properties
	for prop: String in properties:
		new_node.set(prop, properties[prop])

	# Add to parent
	parent.add_child(new_node)
	new_node.owner = _editor_interface.get_edited_scene_root()

	var full_path: String = "%s/%s" % [parent_path, new_node.name]
	_logger.info("Node created", {"path": full_path, "type": node_type})

	return MCPToolResult.text("Created node: %s" % full_path, {
		"path": full_path,
		"name": new_node.name,
		"type": node_type
	})


func _execute_delete(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	var node_name: String = node.name
	var parent: Node = node.get_parent()

	if parent != null:
		parent.remove_child(node)

	node.queue_free()

	_logger.info("Node deleted", {"path": path})
	return MCPToolResult.text("Deleted node: %s" % path, {"path": path, "name": node_name})


func _execute_list_children(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")
	var recursive: bool = params.get("recursive", false)

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	var children: Array[Dictionary] = _get_children_list(node, recursive)

	return MCPToolResult.text("Found %d children" % children.size(), {
		"path": path,
		"children": children,
		"count": children.size()
	})


func _execute_duplicate(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")
	var new_name: String = params.get("new_name", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	var duplicate: Node = node.duplicate()
	if duplicate == null:
		return MCPToolResult.error("Failed to duplicate node", MCPError.Code.TOOL_EXECUTION_ERROR)

	if new_name.is_empty():
		new_name = node.name + "_duplicate"
	duplicate.name = new_name

	var parent: Node = node.get_parent()
	if parent != null:
		parent.add_child(duplicate)
		duplicate.owner = _editor_interface.get_edited_scene_root()

	var full_path: String = "%s/%s" % [parent.get_path(), new_name] if parent != null else new_name

	_logger.info("Node duplicated", {"original": path, "duplicate": full_path})
	return MCPToolResult.text("Duplicated node: %s" % full_path, {
		"original_path": path,
		"duplicate_path": full_path,
		"name": new_name
	})


func _get_children_list(node: Node, recursive: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for child: Node in node.get_children():
		result.append({
			"path": str(child.get_path()),
			"name": child.name,
			"type": child.get_class()
		})

		if recursive:
			result.append_array(_get_children_list(child, true))

	return result


func _get_node_properties(node: Node) -> Dictionary:
	var props: Dictionary = {}
	var property_list: Array[Dictionary] = node.get_property_list()

	for prop: Dictionary in property_list:
		var name: String = prop["name"]
		if name.begins_with("_"):
			continue
		props[name] = _variant_to_json(node.get(name))

	return props


func _variant_to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR3I:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_RECT2:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var arr: Array = []
			for item: Variant in value:
				arr.append(_variant_to_json(item))
			return arr
		TYPE_DICTIONARY:
			var dict: Dictionary = {}
			for key: Variant in value:
				dict[str(key)] = _variant_to_json(value[key])
			return dict
		TYPE_OBJECT:
			if value is Resource:
				return value.resource_path
			return str(value)
		_:
			return value

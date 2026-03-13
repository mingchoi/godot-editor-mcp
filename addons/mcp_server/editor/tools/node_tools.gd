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
const TOOL_PACK_AS_SCENE := "node_pack_as_scene"

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
	registry.register(_create_pack_as_scene_tool())


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


func _create_pack_as_scene_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_PACK_AS_SCENE,
			"Saves a node branch as a new scene file and converts the node to an instance",
			{
				"path": {"type": "string", "description": "Source node path to pack"},
				"destination": {"type": "string", "description": "Destination file path (e.g., 'res://scenes/new.tscn')"}
			},
			["path", "destination"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_pack_as_scene(params)
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
	var raw_value: Variant = params.get("value")

	# Parse JSON string if necessary (MCP may send objects as JSON strings)
	if typeof(raw_value) == TYPE_STRING:
		var parsed = JSON.parse_string(raw_value)
		if parsed != null:
			raw_value = parsed

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	# Get the expected type and convert the value
	var property_list: Array = node.get_property_list()
	var expected_type: int = TYPE_NIL
	for prop: Dictionary in property_list:
		if prop["name"] == property:
			expected_type = prop["type"]
			_logger.info("Found property type", {"property": property, "type": expected_type, "type_name": type_string(expected_type)})
			break

	if expected_type == TYPE_NIL:
		_logger.warning("Property type not found in list", {"property": property})

	var value: Variant = _json_to_variant(raw_value, expected_type)
	_logger.info("Value conversion", {"raw_type": type_string(typeof(raw_value)), "converted_type": type_string(typeof(value))})
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


func _execute_pack_as_scene(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")
	var destination: String = params.get("destination", "")

	# Validate destination path
	if not destination.begins_with("res://"):
		return MCPToolResult.error("Destination must be a res:// path", MCPError.Code.INVALID_PARAMS)

	if not destination.ends_with(".tscn") and not destination.ends_with(".scn"):
		return MCPToolResult.error("Destination must have .tscn or .scn extension", MCPError.Code.INVALID_PARAMS)

	# Get the node to pack
	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	var parent: Node = node.get_parent()
	var node_index: int = -1
	var node_name: String = node.name
	var original_transform_3d: Transform3D
	var original_transform_2d: Transform2D
	var is_node3d: bool = node is Node3D
	var is_node2d: bool = node is Node2D

	# Store transform before any modifications
	if is_node3d:
		original_transform_3d = node.transform
	elif is_node2d:
		original_transform_2d = node.transform

	# Remove from parent if it has one
	if parent != null:
		node_index = node.get_index()
		parent.remove_child(node)

	# Reset transform to avoid "root node transform" warning
	if is_node3d:
		node.transform = Transform3D()
	elif is_node2d:
		node.transform = Transform2D()

	# Set children's owner to the node being packed
	# This allows pack() to include them (pack only includes nodes owned by the root)
	_set_owner_recursive(node, node)

	# Pack the node
	var packed := PackedScene.new()
	var pack_result: int = packed.pack(node)

	if pack_result != OK:
		# Restore node on failure
		if is_node3d:
			node.transform = original_transform_3d
		elif is_node2d:
			node.transform = original_transform_2d
		if parent != null:
			parent.add_child(node)
			parent.move_child(node, node_index)
			node.owner = _editor_interface.get_edited_scene_root()
		return MCPToolResult.error("Failed to pack node: %s" % path, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Save the packed scene
	var save_result: int = ResourceSaver.save(packed, destination)
	if save_result != OK:
		# Restore node on failure
		if is_node3d:
			node.transform = original_transform_3d
		elif is_node2d:
			node.transform = original_transform_2d
		if parent != null:
			parent.add_child(node)
			parent.move_child(node, node_index)
			node.owner = _editor_interface.get_edited_scene_root()
		return MCPToolResult.error("Failed to save scene to: %s" % destination, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Update the filesystem so the new scene is recognized
	var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
	fs.update_file(destination)

	# Load the saved scene from disk (not from memory) so the instance gets scene_file_path set
	var loaded_scene: PackedScene = ResourceLoader.load(destination)
	if loaded_scene == null:
		# Restore node on failure
		if is_node3d:
			node.transform = original_transform_3d
		elif is_node2d:
			node.transform = original_transform_2d
		if parent != null:
			parent.add_child(node)
			parent.move_child(node, node_index)
			node.owner = _editor_interface.get_edited_scene_root()
		return MCPToolResult.error("Failed to load saved scene: %s" % destination, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Create an instance from the loaded scene (this sets scene_file_path properly)
	var instance: Node = loaded_scene.instantiate()
	instance.name = node_name

	# Restore the original transform on the instance
	if is_node3d:
		instance.transform = original_transform_3d
	elif is_node2d:
		instance.transform = original_transform_2d

	# Add instance to parent (replacing original)
	if parent != null:
		parent.add_child(instance)
		parent.move_child(instance, node_index)
		instance.owner = _editor_interface.get_edited_scene_root()

	# Free the original node
	node.queue_free()

	_logger.info("Node packed as scene and replaced with instance", {"source": path, "destination": destination})

	return MCPToolResult.text("Packed node as scene: %s" % destination, {
		"source_path": path,
		"destination": destination,
		"saved": true,
		"instance_path": str(instance.get_path()) if instance.get_parent() != null else ""
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


## Recursively clears owner on node and all descendants
func _clear_ownership(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_ownership(child)


## Recursively sets owner on all descendants (not the node itself)
func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


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


## Converts JSON-compatible value back to Godot Variant based on expected type
func _json_to_variant(value: Variant, expected_type: int) -> Variant:
	if value == null:
		return null

	# If already the right type, return as-is
	if typeof(value) == expected_type:
		return value

	# Convert dictionary to Godot types
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		# Use explicit integer comparisons for match
		if expected_type == TYPE_VECTOR3:
			if d.has("x") and d.has("y") and d.has("z"):
				return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
		elif expected_type == TYPE_VECTOR3I:
			if d.has("x") and d.has("y") and d.has("z"):
				return Vector3i(int(d["x"]), int(d["y"]), int(d["z"]))
		elif expected_type == TYPE_VECTOR2:
			if d.has("x") and d.has("y"):
				return Vector2(float(d["x"]), float(d["y"]))
		elif expected_type == TYPE_VECTOR2I:
			if d.has("x") and d.has("y"):
				return Vector2i(int(d["x"]), int(d["y"]))
		elif expected_type == TYPE_RECT2:
			if d.has("x") and d.has("y") and d.has("w") and d.has("h"):
				return Rect2(float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]))
		elif expected_type == TYPE_COLOR:
			if d.has("r") and d.has("g") and d.has("b"):
				return Color(float(d["r"]), float(d["g"]), float(d["b"]), float(d.get("a", 1.0)))
		elif expected_type == TYPE_QUATERNION:
			if d.has("x") and d.has("y") and d.has("z") and d.has("w"):
				return Quaternion(float(d["x"]), float(d["y"]), float(d["z"]), float(d["w"]))
		elif expected_type == TYPE_OBJECT:
			# Handle resource creation (shapes, meshes, etc.)
			if d.has("type"):
				var resource_type: String = d["type"]
				if ClassDB.class_exists(resource_type):
					var resource: Resource = ClassDB.instantiate(resource_type)
					if resource != null:
						# Set any additional properties on the resource with type conversion
						for key: String in d:
							if key != "type":
								# Get property info to find expected type
								var prop_list: Array[Dictionary] = resource.get_property_list()
								var prop_type: int = TYPE_NIL
								for prop_info: Dictionary in prop_list:
									if prop_info["name"] == key:
										prop_type = prop_info["type"]
										break
								var converted_value: Variant = _json_to_variant(d[key], prop_type)
								resource.set(key, converted_value)
						return resource

	# Convert array elements
	if typeof(value) == TYPE_ARRAY:
		if expected_type == TYPE_PACKED_INT32_ARRAY:
			var arr: PackedInt32Array = []
			for item: Variant in value:
				arr.append(int(item))
			return arr
		elif expected_type == TYPE_PACKED_FLOAT32_ARRAY:
			var arr: PackedFloat32Array = []
			for item: Variant in value:
				arr.append(float(item))
			return arr
		elif expected_type == TYPE_PACKED_STRING_ARRAY:
			var arr: PackedStringArray = []
			for item: Variant in value:
				arr.append(str(item))
			return arr

	return value

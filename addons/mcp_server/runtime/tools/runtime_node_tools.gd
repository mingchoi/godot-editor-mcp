## Runtime Node Tools
## MCP tools for creating, deleting, and instantiating nodes at runtime.
extends RefCounted
class_name RuntimeNodeTools

const TOOL_NODE_CREATE := "runtime_node_create"
const TOOL_NODE_DELETE := "runtime_node_delete"
const TOOL_INSTANTIATE_SCENE := "runtime_instantiate_scene"

var _logger: MCPLogger


func _init(logger: MCPLogger = null) -> void:
	_logger = logger.child("RuntimeNodeTools") if logger else MCPLogger.new("[RuntimeNodeTools]")


## Registers all runtime node tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_node_create_tool())
	registry.register(_create_node_delete_tool())
	registry.register(_create_instantiate_scene_tool())


# --- Tool Definitions ---

func _create_node_create_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_NODE_CREATE,
			"Creates a new node in the running game",
			{
				"type": {"type": "string", "description": "Node type (e.g., 'Sprite2D', 'Node3D')"},
				"parent": {"type": "string", "description": "Parent node path"},
				"name": {"type": "string", "description": "Node name (auto-generated if not provided)"},
				"properties": {"type": "object", "default": {}, "description": "Initial property values"}
			},
			["type", "parent"]
		)
	return MCPToolHandler.new(definition, _execute_node_create)


func _create_node_delete_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_NODE_DELETE,
			"Deletes a node from the running game",
			{
				"path": {"type": "string", "description": "Node path to delete"}
			},
			["path"]
		)
	return MCPToolHandler.new(definition, _execute_node_delete)


func _create_instantiate_scene_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_INSTANTIATE_SCENE,
			"Instantiates a scene file into the running game",
			{
				"scene_path": {"type": "string", "description": "Scene resource path (e.g., 'res://scenes/enemy.tscn')"},
				"parent": {"type": "string", "description": "Parent node path"},
				"name": {"type": "string", "description": "Name for the instance root (uses original if not provided)"}
			},
			["scene_path", "parent"]
		)
	return MCPToolHandler.new(definition, _execute_instantiate_scene)


# --- Helper Methods ---

func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _resolve_node(path: String) -> Node:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return null

	if path.begins_with("/root/"):
		return tree.root.get_node_or_null(path.substr(6))

	return tree.root.get_node_or_null(path)


# --- Tool Implementations ---

func _execute_node_create(params: Dictionary) -> MCPToolResult:
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

	# Set properties with type conversion
	for prop: String in properties:
		var prop_list: Array = new_node.get_property_list()
		var expected_type: int = TYPE_NIL
		for prop_info: Dictionary in prop_list:
			if prop_info["name"] == prop:
				expected_type = prop_info["type"]
				break
		var value: Variant = _json_to_variant(properties[prop], expected_type)
		new_node.set(prop, value)

	# Add to parent
	parent.add_child(new_node)

	var full_path: String = "%s/%s" % [parent_path, new_node.name]
	_logger.info("Node created", {"path": full_path, "type": node_type})

	return MCPToolResult.text("Created node: %s" % full_path, {
		"path": str(new_node.get_path()),
		"name": new_node.name,
		"type": node_type,
		"actual_name": new_node.name
	})


func _execute_node_delete(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	# Protect scene root
	var tree: SceneTree = _get_tree()
	if tree != null and node == tree.root:
		return MCPToolResult.error("Cannot delete scene root", MCPError.Code.INVALID_PARAMS)

	var node_name: String = node.name
	var node_path: String = str(node.get_path())

	# Remove from parent and free
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)

	node.queue_free()

	_logger.info("Node deleted", {"path": path})
	return MCPToolResult.text("Deleted node: %s" % path, {
		"path": node_path,
		"name": node_name,
		"deleted": true
	})


func _execute_instantiate_scene(params: Dictionary) -> MCPToolResult:
	var scene_path: String = params.get("scene_path", "")
	var parent_path: String = params.get("parent", "")
	var custom_name: String = params.get("name", "")

	# Load scene
	if not ResourceLoader.exists(scene_path):
		return MCPToolResult.error("Scene file not found: %s" % scene_path, MCPError.Code.NOT_FOUND)

	var packed: PackedScene = ResourceLoader.load(scene_path)
	if packed == null:
		return MCPToolResult.error("Failed to load scene: %s" % scene_path, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Get parent
	var parent: Node = _resolve_node(parent_path)
	if parent == null:
		return MCPToolResult.error("Parent node not found: %s" % parent_path, MCPError.Code.NOT_FOUND)

	# Instantiate
	var instance: Node = packed.instantiate()
	if instance == null:
		return MCPToolResult.error("Failed to instantiate scene: %s" % scene_path, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Set custom name if provided
	if not custom_name.is_empty():
		instance.name = custom_name

	# Add to parent
	parent.add_child(instance)

	var instance_path: String = str(instance.get_path())
	var child_count: int = instance.get_child_count()

	_logger.info("Scene instantiated", {
		"scene_path": scene_path,
		"instance_path": instance_path,
		"child_count": child_count
	})

	return MCPToolResult.text("Instantiated scene: %s" % instance_path, {
		"path": instance_path,
		"name": instance.name,
		"scene_path": scene_path,
		"child_count": child_count
	})


# --- Type Conversion Helpers ---

func _variant_to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
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
			if value is Node:
				return str(value.get_path())
			return str(value)
		_:
			return str(value)


func _json_to_variant(value: Variant, expected_type: int) -> Variant:
	if value == null:
		return null

	# If already the right type, return as-is
	if typeof(value) == expected_type:
		return value

	# Convert dictionary to Godot types
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		match expected_type:
			TYPE_VECTOR2:
				if d.has("x") and d.has("y"):
					return Vector2(float(d["x"]), float(d["y"]))
			TYPE_VECTOR2I:
				if d.has("x") and d.has("y"):
					return Vector2i(int(d["x"]), int(d["y"]))
			TYPE_VECTOR3:
				if d.has("x") and d.has("y") and d.has("z"):
					return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
			TYPE_VECTOR3I:
				if d.has("x") and d.has("y") and d.has("z"):
					return Vector3i(int(d["x"]), int(d["y"]), int(d["z"]))
			TYPE_RECT2:
				if d.has("x") and d.has("y") and d.has("w") and d.has("h"):
					return Rect2(float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]))
			TYPE_COLOR:
				if d.has("r") and d.has("g") and d.has("b"):
					return Color(float(d["r"]), float(d["g"]), float(d["b"]), float(d.get("a", 1.0)))
			TYPE_QUATERNION:
				if d.has("x") and d.has("y") and d.has("z") and d.has("w"):
					return Quaternion(float(d["x"]), float(d["y"]), float(d["z"]), float(d["w"]))
			TYPE_OBJECT:
				# Handle resource creation
				if d.has("type"):
					var resource_type: String = d["type"]
					if ClassDB.class_exists(resource_type):
						var resource: Resource = ClassDB.instantiate(resource_type)
						if resource != null:
							for key: String in d:
								if key != "type":
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
		match expected_type:
			TYPE_PACKED_INT32_ARRAY:
				var arr: PackedInt32Array = []
				for item: Variant in value:
					arr.append(int(item))
				return arr
			TYPE_PACKED_FLOAT32_ARRAY:
				var arr: PackedFloat32Array = []
				for item: Variant in value:
					arr.append(float(item))
				return arr
			TYPE_PACKED_STRING_ARRAY:
				var arr: PackedStringArray = []
				for item: Variant in value:
					arr.append(str(item))
				return arr

	return value

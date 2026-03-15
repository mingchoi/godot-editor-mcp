## Runtime Node Tools
## MCP tools for creating, deleting, and instantiating nodes at runtime.
extends RefCounted
class_name RuntimeNodeTools

## Registers all runtime node tools
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted) -> RefCounted:
	var tools := RuntimeNodeTools.new()

	registry.register_tool(
		_create_tool_def("runtime_node_create", "Creates a new node in the running game", {
			"type": {"type": "string", "description": "Node type (e.g., 'Sprite2D', 'Node3D')"},
			"parent": {"type": "string", "description": "Parent node path"},
			"name": {"type": "string", "description": "Node name (auto-generated if not provided)"},
			"properties": {"type": "object", "default": {}, "description": "Initial property values"}
		}, ["type", "parent"]),
		tools._execute_node_create
	)

	registry.register_tool(
		_create_tool_def("runtime_node_delete", "Deletes a node from the running game", {
			"path": {"type": "string", "description": "Node path to delete"}
		}, ["path"]),
		tools._execute_node_delete
	)

	registry.register_tool(
		_create_tool_def("runtime_instantiate_scene", "Instantiates a scene file into the running game", {
			"scene_path": {"type": "string", "description": "Scene resource path (e.g., 'res://scenes/enemy.tscn')"},
			"parent": {"type": "string", "description": "Parent node path"},
			"name": {"type": "string", "description": "Name for the instance root (uses original if not provided)"},
			"position": {"type": "object", "default": {}, "description": "Initial position as {x, y, z} for 3D or {x, y} for 2D nodes"},
			"rotation": {"type": "object", "default": {}, "description": "Initial rotation in degrees as {x, y, z} for 3D or {x, y, angle} for 2D nodes"}
		}, ["scene_path", "parent"]),
		tools._execute_instantiate_scene
	)

	return tools


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

func _execute_node_create(args: Dictionary) -> Dictionary:
	var node_type: String = args.get("type", "")
	var node_name: String = args.get("name", "")
	var parent_path: String = args.get("parent", "")
	var properties: Dictionary = args.get("properties", {})

	# Validate type
	if not ClassDB.class_exists(node_type):
		return {"content": [{"type": "text", "text": "Error: Unknown node type: %s" % node_type}], "isError": true}

	# Get parent
	var parent: Node = _resolve_node(parent_path)
	if parent == null:
		return {"content": [{"type": "text", "text": "Error: Parent node not found: %s" % parent_path}], "isError": true}

	# Create node
	var new_node: Node = ClassDB.instantiate(node_type)
	if new_node == null:
		return {"content": [{"type": "text", "text": "Error: Failed to create node of type: %s" % node_type}], "isError": true}

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

	return {
		"content": [{"type": "text", "text": "Created node: %s" % full_path}],
		"isError": false,
		"data": {
			"path": str(new_node.get_path()),
			"name": new_node.name,
			"type": node_type,
			"actual_name": new_node.name
		}
	}


func _execute_node_delete(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	# Protect scene root
	var tree: SceneTree = _get_tree()
	if tree != null and node == tree.root:
		return {"content": [{"type": "text", "text": "Error: Cannot delete scene root"}], "isError": true}

	var node_name: String = node.name
	var node_path: String = str(node.get_path())

	# Remove from parent and free
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)

	node.queue_free()

	return {
		"content": [{"type": "text", "text": "Deleted node: %s" % path}],
		"isError": false,
		"data": {
			"path": node_path,
			"name": node_name,
			"deleted": true
		}
	}


func _execute_instantiate_scene(args: Dictionary) -> Dictionary:
	var scene_path: String = args.get("scene_path", "")
	var parent_path: String = args.get("parent", "")
	var custom_name: String = args.get("name", "")
	var position_data: Dictionary = args.get("position", {})
	var rotation_data: Dictionary = args.get("rotation", {})

	# Load scene
	if not ResourceLoader.exists(scene_path):
		return {"content": [{"type": "text", "text": "Error: Scene file not found: %s" % scene_path}], "isError": true}

	var packed: PackedScene = ResourceLoader.load(scene_path)
	if packed == null:
		return {"content": [{"type": "text", "text": "Error: Failed to load scene: %s" % scene_path}], "isError": true}

	# Get parent
	var parent: Node = _resolve_node(parent_path)
	if parent == null:
		return {"content": [{"type": "text", "text": "Error: Parent node not found: %s" % parent_path}], "isError": true}

	# Instantiate
	var instance: Node = packed.instantiate()
	if instance == null:
		return {"content": [{"type": "text", "text": "Error: Failed to instantiate scene: %s" % scene_path}], "isError": true}

	# Set custom name if provided
	if not custom_name.is_empty():
		instance.name = custom_name

	# Add to parent
	parent.add_child(instance)

	# Apply position if provided
	if not position_data.is_empty():
		if instance is Node3D:
			if position_data.has("x") and position_data.has("y") and position_data.has("z"):
				instance.position = Vector3(
					float(position_data["x"]),
					float(position_data["y"]),
					float(position_data["z"])
				)
			elif position_data.has("x") and position_data.has("y"):
				instance.position = Vector3(
					float(position_data["x"]),
					float(position_data["y"]),
					0.0
				)
		elif instance is Node2D:
			if position_data.has("x") and position_data.has("y"):
				instance.position = Vector2(
					float(position_data["x"]),
					float(position_data["y"])
				)

	# Apply rotation if provided
	if not rotation_data.is_empty():
		if instance is Node3D:
			if rotation_data.has("x") and rotation_data.has("y") and rotation_data.has("z"):
				instance.rotation_degrees = Vector3(
					float(rotation_data["x"]),
					float(rotation_data["y"]),
					float(rotation_data["z"])
				)
		elif instance is Node2D:
			if rotation_data.has("angle"):
				instance.rotation_degrees = float(rotation_data["angle"])
			elif rotation_data.has("x") and rotation_data.has("y"):
				# Treat as angle for 2D
				instance.rotation_degrees = float(rotation_data["x"])

	var instance_path: String = str(instance.get_path())
	var child_count: int = instance.get_child_count()

	return {
		"content": [{"type": "text", "text": "Instantiated scene: %s" % instance_path}],
		"isError": false,
		"data": {
			"path": instance_path,
			"name": instance.name,
			"scene_path": scene_path,
			"child_count": child_count,
			"position": position_data,
			"rotation": rotation_data
		}
	}


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


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}

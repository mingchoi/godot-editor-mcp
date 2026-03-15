## Node Operations Tools
## MCP tools for node operations in the edited scene.
extends RefCounted
class_name NodeTools

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all node tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := NodeTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("node_get", "Gets detailed information about a node", {
			"path": {"type": "string", "description": "Node path (e.g., 'Main/Player' or '/root/Main/Player')"},
			"include_properties": {"type": "boolean", "default": false, "description": "Include all property values"},
			"include_children": {"type": "boolean", "default": false, "description": "Include list of child node names"}
		}, ["path"]),
		tools._execute_get
	)

	registry.register_tool(
		_create_tool_def("node_get_property", "Gets a specific property value from a node", {
			"path": {"type": "string", "description": "Node path"},
			"property": {"type": "string", "description": "Property name"}
		}, ["path", "property"]),
		tools._execute_get_property
	)

	registry.register_tool(
		_create_tool_def("node_set_property", "Sets a property value on a node", {
			"path": {"type": "string", "description": "Node path"},
			"property": {"type": "string", "description": "Property name"},
			"value": {"description": "New property value"}
		}, ["path", "property", "value"]),
		tools._execute_set_property
	)

	registry.register_tool(
		_create_tool_def("node_create", "Creates a new node", {
			"type": {"type": "string", "description": "Node type (e.g., 'Sprite2D', 'Node2D')"},
			"name": {"type": "string", "description": "Node name (auto-generated if not provided)"},
			"parent": {"type": "string", "description": "Parent node path"},
			"properties": {"type": "object", "default": {}, "description": "Initial property values"}
		}, ["type", "parent"]),
		tools._execute_create
	)

	registry.register_tool(
		_create_tool_def("node_delete", "Deletes a node", {
			"path": {"type": "string", "description": "Node path to delete"}
		}, ["path"]),
		tools._execute_delete
	)

	registry.register_tool(
		_create_tool_def("node_list_children", "Lists all children of a node", {
			"path": {"type": "string", "description": "Parent node path"},
			"recursive": {"type": "boolean", "default": false, "description": "Include all descendants"}
		}, ["path"]),
		tools._execute_list_children
	)

	registry.register_tool(
		_create_tool_def("node_duplicate", "Duplicates a node", {
			"path": {"type": "string", "description": "Node to duplicate"},
			"new_name": {"type": "string", "description": "Name for the duplicate"}
		}, ["path"]),
		tools._execute_duplicate
	)

	registry.register_tool(
		_create_tool_def("node_pack_as_scene", "Saves a node branch as a new scene file and converts the node to an instance", {
			"path": {"type": "string", "description": "Source node path to pack"},
			"destination": {"type": "string", "description": "Destination file path (e.g., 'res://scenes/new.tscn')"}
		}, ["path", "destination"]),
		tools._execute_pack_as_scene
	)

	return tools


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


func _execute_get(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var include_properties: bool = args.get("include_properties", false)
	var include_children: bool = args.get("include_children", false)

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

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

	return {
		"content": [{"type": "text", "text": "Node: %s (%s)" % [node.name, node.get_class()]}],
		"isError": false,
		"data": data
	}


func _execute_get_property(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var property: String = args.get("property", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	if not property in node:
		return {"content": [{"type": "text", "text": "Error: Property not found: %s" % property}], "isError": true}

	var value: Variant = node.get(property)
	var value_type: String = type_string(typeof(value))

	var data: Dictionary = {
		"path": path,
		"property": property,
		"value": _variant_to_json(value),
		"type": value_type
	}

	return {
		"content": [{"type": "text", "text": "%s: %s" % [property, str(value)]}],
		"isError": false,
		"data": data
	}


func _execute_set_property(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var property: String = args.get("property", "")
	var raw_value: Variant = args.get("value")

	# Parse JSON string if necessary (MCP may send objects as JSON strings)
	if typeof(raw_value) == TYPE_STRING:
		var parsed = JSON.parse_string(raw_value)
		if parsed != null:
			raw_value = parsed

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	# Get the expected type and convert the value
	var property_list: Array = node.get_property_list()
	var expected_type: int = TYPE_NIL
	for prop: Dictionary in property_list:
		if prop["name"] == property:
			expected_type = prop["type"]
			break

	var value: Variant = _json_to_variant(raw_value, expected_type)
	var old_value: Variant = node.get(property)
	node.set(property, value)

	return {
		"content": [{"type": "text", "text": "Set %s = %s" % [property, str(value)]}],
		"isError": false,
		"data": {
			"path": path,
			"property": property,
			"old_value": _variant_to_json(old_value),
			"new_value": _variant_to_json(value)
		}
	}


func _execute_create(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

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

	# Set properties
	for prop: String in properties:
		new_node.set(prop, properties[prop])

	# Add to parent
	parent.add_child(new_node)
	new_node.owner = _editor_interface.get_edited_scene_root()

	var full_path: String = "%s/%s" % [parent_path, new_node.name]

	return {
		"content": [{"type": "text", "text": "Created node: %s" % full_path}],
		"isError": false,
		"data": {"path": full_path, "name": new_node.name, "type": node_type}
	}


func _execute_delete(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	var node_name: String = node.name
	var parent: Node = node.get_parent()

	if parent != null:
		parent.remove_child(node)

	node.queue_free()

	return {
		"content": [{"type": "text", "text": "Deleted node: %s" % path}],
		"isError": false,
		"data": {"path": path, "name": node_name}
	}


func _execute_list_children(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var recursive: bool = args.get("recursive", false)

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	var children: Array[Dictionary] = _get_children_list(node, recursive)

	return {
		"content": [{"type": "text", "text": "Found %d children" % children.size()}],
		"isError": false,
		"data": {"path": path, "children": children, "count": children.size()}
	}


func _execute_duplicate(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var new_name: String = args.get("new_name", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	var duplicate: Node = node.duplicate()
	if duplicate == null:
		return {"content": [{"type": "text", "text": "Error: Failed to duplicate node"}], "isError": true}

	if new_name.is_empty():
		new_name = node.name + "_duplicate"
	duplicate.name = new_name

	var parent: Node = node.get_parent()
	if parent != null:
		parent.add_child(duplicate)
		duplicate.owner = _editor_interface.get_edited_scene_root()

	var full_path: String = "%s/%s" % [parent.get_path(), new_name] if parent != null else new_name

	return {
		"content": [{"type": "text", "text": "Duplicated node: %s" % full_path}],
		"isError": false,
		"data": {"original_path": path, "duplicate_path": full_path, "name": new_name}
	}


func _execute_pack_as_scene(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var destination: String = args.get("destination", "")

	# Validate destination path
	if not destination.begins_with("res://"):
		return {"content": [{"type": "text", "text": "Error: Destination must be a res:// path"}], "isError": true}

	if not destination.ends_with(".tscn") and not destination.ends_with(".scn"):
		return {"content": [{"type": "text", "text": "Error: Destination must have .tscn or .scn extension"}], "isError": true}

	# Get the node to pack
	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	var parent: Node = node.get_parent()
	if parent == null:
		return {"content": [{"type": "text", "text": "Error: Cannot pack root node (no parent)"}], "isError": true}

	var node_index: int = node.get_index()
	var node_name: String = node.name
	var scene_root: Node = _editor_interface.get_edited_scene_root()

	# Store transform
	var original_transform_3d: Transform3D
	var original_transform_2d: Transform2D
	var is_node3d: bool = node is Node3D
	var is_node2d: bool = node is Node2D

	if is_node3d:
		original_transform_3d = node.transform
	elif is_node2d:
		original_transform_2d = node.transform

	# Duplicate the node for packing (keep original in scene tree)
	var duplicate: Node = node.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	if duplicate == null:
		return {"content": [{"type": "text", "text": "Error: Failed to duplicate node"}], "isError": true}

	# Reset transform on duplicate to avoid "root node transform" warning
	if is_node3d:
		duplicate.transform = Transform3D()
	elif is_node2d:
		duplicate.transform = Transform2D()

	# Set children's owner to the duplicate root so they get packed
	_set_owner_recursive(duplicate, duplicate)

	# Pack the duplicate
	var packed := PackedScene.new()
	var pack_result: int = packed.pack(duplicate)

	# Free the duplicate (we don't need it anymore)
	duplicate.queue_free()

	if pack_result != OK:
		return {"content": [{"type": "text", "text": "Error: Failed to pack node: %s" % path}], "isError": true}

	# Save the packed scene
	var save_result: int = ResourceSaver.save(packed, destination)
	if save_result != OK:
		return {"content": [{"type": "text", "text": "Error: Failed to save scene to: %s" % destination}], "isError": true}

	# Update the filesystem so the new scene is recognized
	var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
	fs.update_file(destination)

	# Load the saved scene from disk so the instance gets scene_file_path set
	var loaded_scene: PackedScene = ResourceLoader.load(destination)
	if loaded_scene == null:
		return {"content": [{"type": "text", "text": "Error: Failed to load saved scene: %s" % destination}], "isError": true}

	# Create an instance from the loaded scene
	var instance: Node = loaded_scene.instantiate()
	instance.name = node_name

	# Restore the original transform on the instance
	if is_node3d:
		instance.transform = original_transform_3d
	elif is_node2d:
		instance.transform = original_transform_2d

	# Remove original node and add instance
	parent.remove_child(node)
	parent.add_child(instance)
	parent.move_child(instance, node_index)
	instance.owner = scene_root

	# Free the original node
	node.queue_free()

	return {
		"content": [{"type": "text", "text": "Packed node as scene: %s" % destination}],
		"isError": false,
		"data": {
			"source_path": path,
			"destination": destination,
			"saved": true,
			"instance_path": str(instance.get_path())
		}
	}


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


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}

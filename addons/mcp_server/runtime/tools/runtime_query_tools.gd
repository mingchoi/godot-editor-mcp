## Runtime Query Tools
## MCP tools for querying and modifying runtime game state.
extends RefCounted
class_name RuntimeQueryTools

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

## Registers all runtime query tools
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted) -> RefCounted:
	var tools := RuntimeQueryTools.new()

	registry.register_tool(
		_create_tool_def("runtime_get_node", "Gets a node from the running scene tree", {
			"path": {"type": "string", "description": "Node path in the running scene"}
		}, ["path"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path"},
				"name": {"type": "string", "description": "Node name"},
				"type": {"type": "string", "description": "Godot class name"},
				"valid": {"type": "boolean", "description": "Whether node is valid"},
				"child_count": {"type": "integer", "description": "Number of children"},
				"children": {"type": "array", "items": {"type": "string"}, "description": "Child node names"},
				"script": {"type": "string", "description": "Script resource path if attached"}
			}
		}),
		tools._execute_get_node
	)
	registry.register_tool(
		_create_tool_def("runtime_get_property", "Gets a property from a runtime node", {
			"path": {"type": "string", "description": "Node path"},
			"property": {"type": "string", "description": "Property name"}
		}, ["path", "property"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path"},
				"property": {"type": "string", "description": "Property name"},
				"value": {"description": "Property value"},
				"type": {"type": "integer", "description": "Godot type enum value"}
			}
		}),
		tools._execute_get_property
	)
	registry.register_tool(
		_create_tool_def("runtime_set_property", "Sets a property value on a node in the running game", {
			"path": {"type": "string", "description": "Node path in the running scene"},
			"property": {"type": "string", "description": "Property name to set"},
			"value": {"description": "New property value (JSON-compatible)"}
		}, ["path", "property", "value"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path"},
				"property": {"type": "string", "description": "Property name"},
				"old_value": {"description": "Previous value"},
				"new_value": {"description": "New value"}
			}
		}),
		tools._execute_set_property
	)
	registry.register_tool(
		_create_tool_def("runtime_call_method", "Calls a method on a runtime node", {
			"path": {"type": "string", "description": "Node path"},
			"method": {"type": "string", "description": "Method name to call"},
			"args": {"type": "array", "default": [], "description": "Arguments to pass to the method"}
		}, ["path", "method"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path"},
				"method": {"type": "string", "description": "Method name"},
				"result": {"description": "Method return value"},
				"success": {"type": "boolean", "description": "Whether call succeeded"}
			}
		}),
		tools._execute_call_method
	)
	registry.register_tool(
		_create_tool_def("runtime_get_performance", "Gets performance statistics", {}, [], {
			"type": "object",
			"properties": {
				"fps": {"type": "number", "description": "Current frames per second"},
				"fps_min": {"type": "number", "description": "Minimum FPS (not tracked)"},
				"fps_max": {"type": "number", "description": "Maximum FPS (not tracked)"},
				"memory_static": {"type": "number", "description": "Static memory usage in bytes"},
				"draw_calls": {"type": "number", "description": "Total draw calls in frame"},
				"objects": {"type": "number", "description": "Total object count"},
				"nodes": {"type": "number", "description": "Node count"}
			}
		}),
		tools._execute_get_performance
	)
	registry.register_tool(
		_create_tool_def("runtime_list_children", "Lists children of a node in the running game", {
			"path": {"type": "string", "description": "Node path in the running scene"},
			"recursive": {"type": "boolean", "default": false, "description": "Include all descendants"}
		}, ["path"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Parent node path"},
				"children": {"type": "array", "items": {"type": "object"}, "description": "Array of child node info"},
				"count": {"type": "integer", "description": "Number of children"}
			}
		}),
		tools._execute_list_children
	)
	registry.register_tool(
		_create_tool_def("runtime_get_node_tree", "Returns the complete node hierarchy tree of the running game", {
			"root_path": {
				"type": "string",
				"default": "",
				"description": "Starting node path (defaults to scene tree root)"
			}
		}, [], {
			"type": "object",
			"properties": {
				"root": {"type": "object", "description": "Root node with nested children hierarchy"}
			}
		}),
		tools._execute_get_node_tree
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

func _execute_get_node(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	var children: Array[String] = []
	for child: Node in node.get_children():
		children.append(child.name)

	var data: Dictionary = {
		"path": str(node.get_path()),
		"name": node.name,
		"type": node.get_class(),
		"valid": true,
		"child_count": children.size(),
		"children": children
	}

	if node.get_script() != null:
		data["script"] = node.get_script().resource_path

	return MCPToolRegistry.create_response("Node: %s (%s)" % [node.name, node.get_class()], data)


func _execute_get_property(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var property: String = args.get("property", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	# Check if property exists
	if not property in node:
		return {"content": [{"type": "text", "text": "Error: Property not found: %s" % property}], "isError": true}

	var value: Variant = node.get(property)
	var value_type: int = typeof(value)

	var data: Dictionary = {
		"path": path,
		"property": property,
		"value": _variant_to_json(value),
		"type": value_type
	}

	return MCPToolRegistry.create_response("%s: %s" % [property, str(value)], data)


func _execute_set_property(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var property: String = args.get("property", "")
	var raw_value: Variant = args.get("value")

	# Parse JSON string if necessary (MCP may send objects as JSON strings)
	if typeof(raw_value) == TYPE_STRING:
		var parsed: Variant = JSON.parse_string(raw_value)
		if parsed != null:
			raw_value = parsed

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	# Check if property exists and get its type info
	var property_list: Array = node.get_property_list()
	var expected_type: int = TYPE_NIL
	var property_usage: int = 0
	var property_found: bool = false

	for prop: Dictionary in property_list:
		if prop["name"] == property:
			expected_type = prop["type"]
			property_usage = prop.get("usage", PROPERTY_USAGE_DEFAULT)
			property_found = true
			break

	if not property_found:
		return {"content": [{"type": "text", "text": "Error: Property not found: %s" % property}], "isError": true}

	# Check for read-only property
	if (property_usage & PROPERTY_USAGE_READ_ONLY) != 0:
		return {"content": [{"type": "text", "text": "Error: Property '%s' is read-only and cannot be modified" % property}], "isError": true}

	# Convert the value to the expected type
	var value: Variant = _json_to_variant(raw_value, expected_type)

	# Get old value for response
	var old_value: Variant = node.get(property)

	# Set the property
	node.set(property, value)

	return MCPToolRegistry.create_response("Set %s = %s" % [property, str(value)], {
		"path": path,
		"property": property,
		"old_value": _variant_to_json(old_value),
		"new_value": _variant_to_json(value)
	})


func _execute_call_method(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var method: String = args.get("method", "")
	var args_array: Array = args.get("args", [])

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	# Check if method exists
	if not node.has_method(method):
		return {"content": [{"type": "text", "text": "Error: Method not found: %s" % method}], "isError": true}

	# Call the method - GDScript doesn't have try/catch, so we use callv which returns the result
	# If the method call fails, Godot will push an error but we can't catch it
	var result: Variant

	# Validate arguments are serializable before calling
	if args_array == null:
		args_array = []

	result = node.callv(method, args_array)

	return MCPToolRegistry.create_response("Called %s" % method, {
		"path": path,
		"method": method,
		"result": _variant_to_json(result),
		"success": true
	})


func _execute_get_performance(_args: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"fps_min": 0,  # Would need tracking
		"fps_max": 0,  # Would need tracking
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	}

	var text: String = "FPS: %d | Memory: %.1fMB | Draw Calls: %d" % [
		data.fps,
		data.memory_static / 1048576.0,
		data.draw_calls
	]

	return MCPToolRegistry.create_response(text, data)


func _execute_list_children(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var recursive: bool = args.get("recursive", false)

	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	var children: Array[Dictionary] = _get_children_list(node, recursive)

	return MCPToolRegistry.create_response("Found %d children" % children.size(), {
		"path": str(node.get_path()),
		"children": children,
		"count": children.size()
	})


func _execute_get_node_tree(args: Dictionary) -> Dictionary:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return {"content": [{"type": "text", "text": "Error: Game not running"}], "isError": true}

	var root_path: String = args.get("root_path", "")
	var root: Node

	if root_path.is_empty():
		root = tree.root  # Start from Viewport
	else:
		root = _resolve_node(root_path)
		if root == null:
			return {"content": [{"type": "text", "text": "Error: Node not found: %s" % root_path}], "isError": true}

	var tree_data: Dictionary = _build_runtime_tree(root)
	var tree_text: String = _format_tree_text(tree_data, "")

	return MCPToolRegistry.create_response("Runtime scene tree:\n%s" % tree_text, {
		"root": tree_data
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


func _build_runtime_tree(node: Node) -> Dictionary:
	var result: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path())
	}

	var children: Array = []
	for child: Node in node.get_children():
		children.append(_build_runtime_tree(child))

	if not children.is_empty():
		result["children"] = children

	return result


func _format_tree_text(node: Dictionary, indent: String) -> String:
	var line: String = "%s|-- %s (%s)\n" % [indent, node.name, node.type]
	var child_indent: String = indent + "|   "

	if node.has("children"):
		for child: Dictionary in node.children:
			line += _format_tree_text(child, child_indent)

	return line


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


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array, output_schema: Dictionary = {}) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	var tool_def: Dictionary = {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}
	if not output_schema.is_empty():
		tool_def["outputSchema"] = output_schema
	return tool_def

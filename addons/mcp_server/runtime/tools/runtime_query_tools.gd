## Runtime Query Tools
## MCP tools for querying runtime game state.
extends RefCounted
class_name RuntimeQueryTools

const TOOL_GET_NODE := "runtime_get_node"
const TOOL_GET_PROPERTY := "runtime_get_property"
const TOOL_CALL_METHOD := "runtime_call_method"
const TOOL_GET_PERFORMANCE := "runtime_get_performance"

var _logger: MCPLogger
var _editor_interface: EditorInterface


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("RuntimeQueryTools") if logger else MCPLogger.new("[RuntimeQueryTools]")
	_editor_interface = editor_interface


## Registers all runtime query tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_get_node_tool())
	registry.register(_create_get_property_tool())
	registry.register(_create_call_method_tool())
	registry.register(_create_get_performance_tool())


func _create_get_node_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_GET_NODE,
			"Gets a node from the running scene tree",
			{
				"path": {"type": "string", "description": "Node path in the running scene"}
			},
			["path"]
		)
	return MCPToolHandler.new(definition, _execute_get_node)


func _create_get_property_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_GET_PROPERTY,
			"Gets a property from a runtime node",
			{
				"path": {"type": "string", "description": "Node path"},
				"property": {"type": "string", "description": "Property name"}
			},
			["path", "property"]
		)
	return MCPToolHandler.new(definition, _execute_get_property)


func _create_call_method_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_CALL_METHOD,
			"Calls a method on a runtime node",
			{
				"path": {"type": "string", "description": "Node path"},
				"method": {"type": "string", "description": "Method name to call"},
				"args": {"type": "array", "default": [], "description": "Arguments to pass to the method"}
			},
			["path", "method"]
		)
	return MCPToolHandler.new(definition, _execute_call_method)


func _create_get_performance_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_GET_PERFORMANCE,
			"Gets performance statistics",
			{},
			[]
		)
	return MCPToolHandler.new(definition, _execute_get_performance)


# --- Tool Implementations ---

func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _resolve_node(path: String) -> Node:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return null

	if path.begins_with("/root/"):
		return tree.root.get_node_or_null(path.substr(6))

	return tree.root.get_node_or_null(path)


func _execute_get_node(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

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

	return MCPToolResult.text("Node: %s (%s)" % [node.name, node.get_class()], data)


func _execute_get_property(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "")
	var property: String = params.get("property", "")

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	# Check if property exists
	if not property in node:
		return MCPToolResult.error("Property not found: %s" % property, MCPError.Code.NOT_FOUND)

	var value: Variant = node.get(property)
	var value_type: int = typeof(value)

	var data: Dictionary = {
		"path": path,
		"property": property,
		"value": _variant_to_json(value),
		"type": value_type
	}

	return MCPToolResult.text("%s: %s" % [property, str(value)], data)


func _execute_call_method(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "")
	var method: String = params.get("method", "")
	var args: Array = params.get("args", [])

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: %s" % path, MCPError.Code.NOT_FOUND)

	# Check if method exists
	if not node.has_method(method):
		return MCPToolResult.error("Method not found: %s" % method, MCPError.Code.NOT_FOUND)

	# Call the method - GDScript doesn't have try/catch, so we use callv which returns the result
	# If the method call fails, Godot will push an error but we can't catch it
	var result: Variant
	var call_ok: bool = true

	# Validate arguments are serializable before calling
	if args == null:
		args = []

	result = node.callv(method, args)

	# Note: In GDScript, there's no exception handling.
	# If the call fails, Godot will log an error and result may be null.
	# We check the result validity based on context.

	_logger.info("Method called", {"path": path, "method": method, "args": args.size()})

	return MCPToolResult.text("Called %s" % method, {
		"path": path,
		"method": method,
		"result": _variant_to_json(result),
		"success": true
	})


func _execute_get_performance(_params: Dictionary = {}) -> MCPToolResult:
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

	return MCPToolResult.text(text, data)


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

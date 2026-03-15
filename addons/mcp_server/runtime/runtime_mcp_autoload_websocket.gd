## Runtime MCP Autoload
## Auto-load singleton that starts the MCP WebSocket server when game runs
extends Node

const RuntimeMCPServerClass = preload("res://addons/mcp_server/runtime/runtime_mcp_websocket.gd")

# Runtime tool imports
const InputToolsClass = preload("res://addons/mcp_server/runtime/tools/input_tools.gd")
const GameControlToolsClass = preload("res://addons/mcp_server/runtime/tools/game_control_tools.gd")
const RuntimeQueryToolsClass = preload("res://addons/mcp_server/runtime/tools/runtime_query_tools.gd")
const RuntimeNodeToolsClass = preload("res://addons/mcp_server/runtime/tools/runtime_node_tools.gd")
const RuntimeCaptureToolsClass = preload("res://addons/mcp_server/runtime/tools/capture_tools.gd")

var _mcp_server: Node
var _port: int = 8766

# Keep references to prevent garbage collection
var _tool_objects: Array[RefCounted] = []


func _ready() -> void:
	_mcp_server = RuntimeMCPServerClass.new(_port)

	if _mcp_server.start():
		print("[Runtime MCP] Server started on port %d (ws://127.0.0.1:%d)" % [_port, _port])
		_register_tools()
	else:
		push_error("[Runtime MCP] Failed to start on port %d" % _port)


func _process(_delta: float) -> void:
	if _mcp_server:
		_mcp_server.poll()


func _register_tools() -> void:
	var registry = _mcp_server.get_tool_registry()

	# Input tools
	var input_tools := InputToolsClass.new(null, null)
	_register_input_tools(registry, input_tools)
	_tool_objects.append(input_tools)

	# Game control tools
	var game_control_tools := GameControlToolsClass.new(null, null)
	_register_game_control_tools(registry, game_control_tools)
	_tool_objects.append(game_control_tools)

	# Runtime query tools
	var query_tools := RuntimeQueryToolsClass.new(null, null)
	_register_query_tools(registry, query_tools)
	_tool_objects.append(query_tools)

	# Runtime node tools
	var node_tools := RuntimeNodeToolsClass.new(null)
	_register_node_tools(registry, node_tools)
	_tool_objects.append(node_tools)

	# Capture tools
	var capture_tools := RuntimeCaptureToolsClass.new(null, null)
	_register_capture_tools(registry, capture_tools)
	_tool_objects.append(capture_tools)

	print("[Runtime MCP] Registered %d tools" % registry.size())


# --- Tool Registration Helpers ---

func _register_input_tools(registry, tools: InputTools) -> void:
	registry.register_tool(
		_create_tool_def("input_key_press", "Simulates a key press and hold", {
			"key": {"type": "string", "description": "Key name (e.g., 'KEY_A', 'KEY_SPACE', 'KEY_UP')"},
			"shift": {"type": "boolean", "default": false},
			"ctrl": {"type": "boolean", "default": false},
			"alt": {"type": "boolean", "default": false},
			"duration_ms": {"type": "integer", "default": 100, "description": "Press duration in milliseconds"}
		}, ["key"]),
		func(args): return _run_tool(tools, "_execute_key_press", args)
	)
	registry.register_tool(
		_create_tool_def("input_key_tap", "Simulates a quick key tap (press and release)", {
			"key": {"type": "string", "description": "Key name"},
			"shift": {"type": "boolean", "default": false},
			"ctrl": {"type": "boolean", "default": false},
			"alt": {"type": "boolean", "default": false}
		}, ["key"]),
		func(args): return _run_tool(tools, "_execute_key_tap", args)
	)
	registry.register_tool(
		_create_tool_def("input_key_release", "Releases a held key", {
			"key": {"type": "string", "description": "Key name to release"}
		}, ["key"]),
		func(args): return _run_tool(tools, "_execute_key_release", args)
	)
	registry.register_tool(
		_create_tool_def("input_mouse_move", "Moves the mouse to a position", {
			"position": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}}, "required": ["x", "y"]},
			"relative": {"type": "boolean", "default": false, "description": "Position is relative"}
		}, ["position"]),
		func(args): return _run_tool(tools, "_execute_mouse_move", args)
	)
	registry.register_tool(
		_create_tool_def("input_mouse_click", "Simulates a mouse button click", {
			"button": {"type": "string", "enum": ["left", "right", "middle"], "default": "left"},
			"position": {"type": "object", "description": "Click position"},
			"double": {"type": "boolean", "default": false, "description": "Double click"},
			"duration_ms": {"type": "integer", "default": 50}
		}, []),
		func(args): return _run_tool(tools, "_execute_mouse_click", args)
	)
	registry.register_tool(
		_create_tool_def("input_action_press", "Simulates an input action press", {
			"action": {"type": "string", "description": "Action name from InputMap"},
			"strength": {"type": "number", "default": 1.0, "minimum": 0.0, "maximum": 1.0}
		}, ["action"]),
		func(args): return _run_tool(tools, "_execute_action_press", args)
	)
	registry.register_tool(
		_create_tool_def("input_action_release", "Releases an input action", {
			"action": {"type": "string", "description": "Action name to release"}
		}, ["action"]),
		func(args): return _run_tool(tools, "_execute_action_release", args)
	)
	registry.register_tool(
		_create_tool_def("input_type_text", "Types a string of text character by character", {
			"text": {"type": "string", "description": "Text to type"},
			"interval_ms": {"type": "integer", "default": 50, "description": "Delay between keystrokes"}
		}, ["text"]),
		func(args): return _run_tool(tools, "_execute_type_text", args)
	)


func _register_game_control_tools(registry, tools: GameControlTools) -> void:
	registry.register_tool(
		_create_tool_def("game_pause", "Pauses the game", {}, []),
		func(args): return _run_tool(tools, "_execute_pause", args)
	)
	registry.register_tool(
		_create_tool_def("game_resume", "Resumes the game", {}, []),
		func(args): return _run_tool(tools, "_execute_resume", args)
	)
	registry.register_tool(
		_create_tool_def("game_set_time_scale", "Sets the game time scale", {
			"scale": {"type": "number", "minimum": 0.0, "maximum": 10.0, "description": "Time scale (1.0 = normal, 0.5 = half speed, 2.0 = double speed)"}
		}, ["scale"]),
		func(args): return _run_tool(tools, "_execute_set_time_scale", args)
	)
	registry.register_tool(
		_create_tool_def("game_is_running", "Checks if the game is currently running and returns state", {}, []),
		func(args): return _run_tool(tools, "_execute_is_running", args)
	)


func _register_query_tools(registry, tools: RuntimeQueryTools) -> void:
	registry.register_tool(
		_create_tool_def("runtime_get_node", "Gets a node from the running scene tree", {
			"path": {"type": "string", "description": "Node path in the running scene"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_get_node", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_get_property", "Gets a property from a runtime node", {
			"path": {"type": "string", "description": "Node path"},
			"property": {"type": "string", "description": "Property name"}
		}, ["path", "property"]),
		func(args): return _run_tool(tools, "_execute_get_property", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_set_property", "Sets a property value on a node in the running game", {
			"path": {"type": "string", "description": "Node path in the running scene"},
			"property": {"type": "string", "description": "Property name to set"},
			"value": {"description": "New property value (JSON-compatible)"}
		}, ["path", "property", "value"]),
		func(args): return _run_tool(tools, "_execute_set_property", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_call_method", "Calls a method on a runtime node", {
			"path": {"type": "string", "description": "Node path"},
			"method": {"type": "string", "description": "Method name to call"},
			"args": {"type": "array", "default": [], "description": "Arguments to pass to the method"}
		}, ["path", "method"]),
		func(args): return _run_tool(tools, "_execute_call_method", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_get_performance", "Gets performance statistics", {}, []),
		func(args): return _run_tool(tools, "_execute_get_performance", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_list_children", "Lists children of a node in the running game", {
			"path": {"type": "string", "description": "Node path in the running scene"},
			"recursive": {"type": "boolean", "default": false, "description": "Include all descendants"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_list_children", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_get_node_tree", "Returns the complete node hierarchy tree of the running game", {
			"root_path": {"type": "string", "default": "", "description": "Starting node path (defaults to scene tree root)"}
		}, []),
		func(args): return _run_tool(tools, "_execute_get_node_tree", args)
	)


func _register_node_tools(registry, tools: RuntimeNodeTools) -> void:
	registry.register_tool(
		_create_tool_def("runtime_node_create", "Creates a new node in the running game", {
			"type": {"type": "string", "description": "Node type (e.g., 'Sprite2D', 'Node3D')"},
			"parent": {"type": "string", "description": "Parent node path"},
			"name": {"type": "string", "description": "Node name (auto-generated if not provided)"},
			"properties": {"type": "object", "default": {}, "description": "Initial property values"}
		}, ["type", "parent"]),
		func(args): return _run_tool(tools, "_execute_node_create", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_node_delete", "Deletes a node from the running game", {
			"path": {"type": "string", "description": "Node path to delete"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_node_delete", args)
	)
	registry.register_tool(
		_create_tool_def("runtime_instantiate_scene", "Instantiates a scene file into the running game", {
			"scene_path": {"type": "string", "description": "Scene resource path (e.g., 'res://scenes/enemy.tscn')"},
			"parent": {"type": "string", "description": "Parent node path"},
			"name": {"type": "string", "description": "Name for the instance root"},
			"position": {"type": "object", "default": {}, "description": "Initial position"},
			"rotation": {"type": "object", "default": {}, "description": "Initial rotation"}
		}, ["scene_path", "parent"]),
		func(args): return _run_tool(tools, "_execute_instantiate_scene", args)
	)


func _register_capture_tools(registry, tools) -> void:
	registry.register_tool(
		_create_tool_def("screenshot_capture_runtime", "Captures a screenshot of the running game viewport", {
			"filename": {"type": "string", "description": "Custom filename (without extension)"},
			"format": {"type": "string", "enum": ["png", "jpg"], "default": "png"},
			"quality": {"type": "integer", "minimum": 1, "maximum": 100, "default": 90}
		}, []),
		func(args): return _run_tool(tools, "_execute_capture_runtime", args)
	)
	registry.register_tool(
		_create_tool_def("screenshot_list", "Lists all captured screenshots", {}, []),
		func(args): return _run_tool(tools, "_execute_list", args)
	)


# --- Helper Functions ---

func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}


func _run_tool(tool_obj, method_name: String, args: Dictionary) -> Dictionary:
	var result = tool_obj.call(method_name, args)
	if result is MCPToolResult:
		return result.to_response_dict()
	return result

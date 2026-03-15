## Runtime MCP Server Autoload
## Runs SimpleMCPServer in the game runtime
extends Node

const SimpleMCPServerClass = preload("res://addons/mcp_server/simple_mcp_server.gd")

var _mcp_server: SimpleMCPServer
var _port: int = 8766  # Different port from editor (8765) to avoid conflicts
var _tool_objects: Array[RefCounted] = []


func _ready() -> void:
	print("[Runtime MCP Server] Initializing on port %d..." % _port)
	_mcp_server = SimpleMCPServerClass.new(_port)

	if _mcp_server.start():
		print("[Runtime MCP Server] Started on port %d (ws://127.0.0.1:%d)" % [_port, _port])
		_register_tools()
	else:
		push_error("[Runtime MCP Server] Failed to start on port %d" % _port)


func _process(_delta: float) -> void:
	if _mcp_server and _mcp_server.is_running():
		_mcp_server.poll()


## Stop the server (call before game quits)
func stop_server() -> void:
	if _mcp_server:
		_mcp_server.stop()
		print("[Runtime MCP Server] Stopped")


func _register_tools() -> void:
	var registry = _mcp_server.get_tool_registry()

	# Import runtime tool classes
	const RuntimeQueryToolsClass = preload("res://addons/mcp_server/runtime/tools/runtime_query_tools.gd")
	const RuntimeNodeToolsClass = preload("res://addons/mcp_server/runtime/tools/runtime_node_tools.gd")
	const InputToolsClass = preload("res://addons/mcp_server/runtime/tools/input_tools.gd")
	const CaptureToolsClass = preload("res://addons/mcp_server/runtime/tools/capture_tools.gd")
	const GameControlToolsClass = preload("res://addons/mcp_server/runtime/tools/game_control_tools.gd")

	# Register Query Tools
	var query_tools := RuntimeQueryToolsClass.new()
	_register_runtime_query_tools(registry, query_tools)
	_tool_objects.append(query_tools)

	# Register Node Tools
	var node_tools := RuntimeNodeToolsClass.new()
	_register_runtime_node_tools(registry, node_tools)
	_tool_objects.append(node_tools)

	# Register Input Tools
	var input_tools := InputToolsClass.new()
	_register_input_tools(registry, input_tools)
	_tool_objects.append(input_tools)

	# Register Capture Tools
	var capture_tools := CaptureToolsClass.new()
	_register_capture_tools(registry, capture_tools)
	_tool_objects.append(capture_tools)

	# Register Game Control Tools
	var game_control_tools := GameControlToolsClass.new()
	_register_game_control_tools(registry, game_control_tools)
	_tool_objects.append(game_control_tools)

	print("[Runtime MCP Server] Registered %d tools" % registry.size())


# --- Tool Registration Helpers ---
# Adapt runtime tools to SimpleToolRegistry pattern

func _register_runtime_query_tools(registry: SimpleToolRegistry, tools: RuntimeQueryTools) -> void:
	registry.register_tool(
		_create_tool_def("runtime_get_node", "Gets a node from the running scene tree", {
			"path": {"type": "string", "description": "Node path in the running scene"}
		}, ["path"]),
		_make_tool_wrapper(tools, "_execute_get_node")
	)
	registry.register_tool(
		_create_tool_def("runtime_get_property", "Gets a property from a runtime node", {
			"path": {"type": "string", "description": "Node path"},
			"property": {"type": "string", "description": "Property name"}
		}, ["path", "property"]),
		_make_tool_wrapper(tools, "_execute_get_property")
	)
	registry.register_tool(
		_create_tool_def("runtime_set_property", "Sets a property value on a node in the running game", {
			"path": {"type": "string", "description": "Node path in the running scene"},
			"property": {"type": "string", "description": "Property name to set"},
			"value": {"description": "New property value (JSON-compatible)"}
		}, ["path", "property", "value"]),
		_make_tool_wrapper(tools, "_execute_set_property")
	)
	registry.register_tool(
		_create_tool_def("runtime_call_method", "Calls a method on a runtime node", {
			"path": {"type": "string", "description": "Node path"},
			"method": {"type": "string", "description": "Method name to call"},
			"args": {"type": "array", "default": [], "description": "Arguments to pass to the method"}
		}, ["path", "method"]),
		_make_tool_wrapper(tools, "_execute_call_method")
	)
	registry.register_tool(
		_create_tool_def("runtime_get_performance", "Gets performance statistics", {}, []),
		_make_tool_wrapper(tools, "_execute_get_performance")
	)
	registry.register_tool(
		_create_tool_def("runtime_list_children", "Lists children of a node in the running game", {
			"path": {"type": "string", "description": "Node path in the running scene"},
			"recursive": {"type": "boolean", "default": false, "description": "Include all descendants"}
		}, ["path"]),
		_make_tool_wrapper(tools, "_execute_list_children")
	)
	registry.register_tool(
		_create_tool_def("runtime_get_node_tree", "Returns the complete node hierarchy tree of the running game", {
			"root_path": {"type": "string", "default": "", "description": "Starting node path"}
		}, []),
		_make_tool_wrapper(tools, "_execute_get_node_tree")
	)


func _register_runtime_node_tools(registry: SimpleToolRegistry, tools: RuntimeNodeTools) -> void:
	registry.register_tool(
		_create_tool_def("runtime_node_create", "Creates a new node in the running game", {
			"type": {"type": "string", "description": "Node type (e.g., 'Sprite2D', 'Node3D')"},
			"parent": {"type": "string", "description": "Parent node path"},
			"name": {"type": "string", "description": "Node name (auto-generated if not provided)"},
			"properties": {"type": "object", "default": {}, "description": "Initial property values"}
		}, ["type", "parent"]),
		_make_tool_wrapper(tools, "_execute_node_create")
	)
	registry.register_tool(
		_create_tool_def("runtime_node_delete", "Deletes a node from the running game", {
			"path": {"type": "string", "description": "Node path to delete"}
		}, ["path"]),
		_make_tool_wrapper(tools, "_execute_node_delete")
	)
	registry.register_tool(
		_create_tool_def("runtime_instantiate_scene", "Instantiates a scene file into the running game", {
			"scene_path": {"type": "string", "description": "Scene resource path (e.g., 'res://scenes/enemy.tscn')"},
			"parent": {"type": "string", "description": "Parent node path"},
			"name": {"type": "string", "description": "Name for the instance root (uses original if not provided)"},
			"position": {"type": "object", "default": {}, "description": "Initial position as {x, y, z} for 3D or {x, y} for 2D nodes"},
			"rotation": {"type": "object", "default": {}, "description": "Initial rotation in degrees as {x, y, z} for 3D or {x, y, angle} for 2D nodes"}
		}, ["scene_path", "parent"]),
		_make_tool_wrapper(tools, "_execute_instantiate_scene")
	)


func _register_input_tools(registry: SimpleToolRegistry, tools: InputTools) -> void:
	registry.register_tool(
		_create_tool_def("runtime_input_key_press", "Simulates a key press and hold", {
			"key": {"type": "string", "description": "Key name (e.g., 'KEY_A', 'KEY_SPACE', 'KEY_UP')"},
			"shift": {"type": "boolean", "default": false},
			"ctrl": {"type": "boolean", "default": false},
			"alt": {"type": "boolean", "default": false},
			"duration_ms": {"type": "integer", "default": 100, "description": "Press duration in milliseconds"}
		}, ["key"]),
		_make_tool_wrapper(tools, "_execute_key_press")
	)
	registry.register_tool(
		_create_tool_def("runtime_input_key_tap", "Simulates a quick key tap (press and release)", {
			"key": {"type": "string", "description": "Key name"},
			"shift": {"type": "boolean", "default": false},
			"ctrl": {"type": "boolean", "default": false},
			"alt": {"type": "boolean", "default": false}
		}, ["key"]),
		_make_tool_wrapper(tools, "_execute_key_tap")
	)
	registry.register_tool(
		_create_tool_def("runtime_input_key_release", "Releases a held key", {
			"key": {"type": "string", "description": "Key name to release"}
		}, ["key"]),
		_make_tool_wrapper(tools, "_execute_key_release")
	)
	registry.register_tool(
		_create_tool_def("runtime_input_mouse_move", "Moves the mouse to a position", {
			"position": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}}, "required": ["x", "y"]},
			"relative": {"type": "boolean", "default": false, "description": "Position is relative"}
		}, ["position"]),
		_make_tool_wrapper(tools, "_execute_mouse_move")
	)
	registry.register_tool(
		_create_tool_def("runtime_input_mouse_click", "Simulates a mouse button click", {
			"button": {"type": "string", "enum": ["left", "right", "middle"], "default": "left"},
			"position": {"type": "object", "description": "Click position"},
			"double": {"type": "boolean", "default": false, "description": "Double click"},
			"duration_ms": {"type": "integer", "default": 50}
		}, []),
		_make_tool_wrapper(tools, "_execute_mouse_click")
	)
	registry.register_tool(
		_create_tool_def("runtime_input_action_press", "Simulates an input action press", {
			"action": {"type": "string", "description": "Action name from InputMap"},
			"strength": {"type": "number", "default": 1.0, "minimum": 0.0, "maximum": 1.0}
		}, ["action"]),
		_make_tool_wrapper(tools, "_execute_action_press")
	)
	registry.register_tool(
		_create_tool_def("runtime_input_action_release", "Releases an input action", {
			"action": {"type": "string", "description": "Action name to release"}
		}, ["action"]),
		_make_tool_wrapper(tools, "_execute_action_release")
	)
	registry.register_tool(
		_create_tool_def("runtime_input_type_text", "Types a string of text character by character", {
			"text": {"type": "string", "description": "Text to type"},
			"interval_ms": {"type": "integer", "default": 50, "description": "Delay between keystrokes"}
		}, ["text"]),
		_make_tool_wrapper(tools, "_execute_type_text")
	)


func _register_capture_tools(registry: SimpleToolRegistry, tools: CaptureTools) -> void:
	registry.register_tool(
		_create_tool_def("runtime_screenshot_capture", "Captures a screenshot of the running game viewport and saves it to disk", {
			"filename": {"type": "string", "description": "Custom filename (without extension). If not provided, auto-generates timestamp-based name"},
			"format": {"type": "string", "enum": ["png", "jpg"], "default": "png", "description": "Image format. PNG for lossless, JPG for smaller files"},
			"quality": {"type": "integer", "minimum": 1, "maximum": 100, "default": 90, "description": "JPG quality (1-100). Only used when format is jpg"}
		}, []),
		_make_tool_wrapper(tools, "_execute_capture_runtime")
	)
	registry.register_tool(
		_create_tool_def("runtime_screenshot_list", "Lists all captured screenshots in the MCP screenshots directory with metadata", {}, []),
		_make_tool_wrapper(tools, "_execute_list")
	)


func _register_game_control_tools(registry: SimpleToolRegistry, tools: GameControlTools) -> void:
	registry.register_tool(
		_create_tool_def("runtime_game_pause", "Pauses the game", {}, []),
		_make_tool_wrapper(tools, "_execute_pause")
	)
	registry.register_tool(
		_create_tool_def("runtime_game_resume", "Resumes the game", {}, []),
		_make_tool_wrapper(tools, "_execute_resume")
	)
	registry.register_tool(
		_create_tool_def("runtime_game_set_time_scale", "Sets the game time scale", {
			"scale": {"type": "number", "minimum": 0.0, "maximum": 10.0, "description": "Time scale (1.0 = normal, 0.5 = half speed, 2.0 = double speed)"}
		}, ["scale"]),
		_make_tool_wrapper(tools, "_execute_set_time_scale")
	)
	registry.register_tool(
		_create_tool_def("runtime_game_is_running", "Checks if the game is currently running and returns state", {}, []),
		_make_tool_wrapper(tools, "_execute_is_running")
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


## Creates a wrapper for tool methods (simple synchronous call)
func _make_tool_wrapper(tool_obj, method_name: String) -> Callable:
	return func(args: Dictionary) -> Dictionary:
		var result = await tool_obj.call(method_name, args)
		if result is MCPToolResult:
			return result.to_response_dict()
		return result

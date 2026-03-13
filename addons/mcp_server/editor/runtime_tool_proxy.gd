## Runtime Tool Proxy
## Proxies runtime tools from game to editor MCP server.
## Registers tool definitions in editor and forwards execution to game via HTTP.
class_name RuntimeToolProxy
extends RefCounted

const PROXY_PREFIX: String = ""  # No prefix needed - tools keep original names

var _http_client: RuntimeHTTPClient
var _logger: MCPLogger
var _tool_definitions: Array[Dictionary] = []
var _is_registered: bool = false

# Static tool definitions - these are the tools the game provides
# These are defined statically since we need to register them before the game runs
var _runtime_tool_names: Array[String] = [
	# Input tools
	"input_key_press",
	"input_key_tap",
	"input_key_release",
	"input_mouse_move",
	"input_mouse_click",
	"input_action_press",
	"input_action_release",
	"input_type_text",
	# Game control tools
	"game_pause",
	"game_resume",
	"game_set_time_scale",
	"game_is_running",
	# Runtime query tools
	"runtime_get_node",
	"runtime_call_method",
	"runtime_get_property",
	"runtime_get_performance",
	# Capture tools
	"screenshot_capture_runtime",
	"screenshot_list",
]


func _init(config: RuntimeHTTPConfig, logger: MCPLogger = null) -> void:
	_logger = logger.child("RuntimeToolProxy") if logger else MCPLogger.new("[RuntimeToolProxy]")
	_http_client = RuntimeHTTPClient.new(config, _logger)
	_build_tool_definitions()


## Register all proxied tools with the editor's tool registry
func register_all(registry: ToolRegistry) -> void:
	if _is_registered:
		_logger.warning("Tools already registered")
		return

	for tool_def: Dictionary in _tool_definitions:
		var handler := _create_proxy_handler(tool_def)
		registry.register(handler)

	_is_registered = true
	_logger.info("Runtime tool proxies registered", {"count": _tool_definitions.size()})


## Unregister all proxied tools
func unregister_all(registry: ToolRegistry) -> void:
	for tool_def: Dictionary in _tool_definitions:
		registry.unregister(tool_def.name)

	_is_registered = false
	_logger.info("Runtime tool proxies unregistered")


## Check if a tool is a runtime tool
func is_runtime_tool(tool_name: String) -> bool:
	return _runtime_tool_names.has(tool_name)


## Get the HTTP client for direct status checks
func get_http_client() -> RuntimeHTTPClient:
	return _http_client


## Forward tool execution to game runtime
func forward_to_game(tool_name: String, params: Dictionary) -> MCPToolResult:
	_logger.debug("Forwarding tool to game", {"tool": tool_name})

	var result: Dictionary = await _http_client.execute_tool(tool_name, params)

	if result.get("success", false):
		var tool_result: Dictionary = result.get("result", {})
		return _convert_to_mcp_result(tool_result)
	else:
		var error: Dictionary = result.get("error", {})
		var error_code: String = error.get("code", "UNKNOWN")
		var error_message: String = error.get("message", "Unknown error")
		return MCPToolResult.error(error_message, _error_code_to_mcp(error_code))


## Build tool definitions for all runtime tools
func _build_tool_definitions() -> void:
	_tool_definitions.clear()

	# Input tools
	_tool_definitions.append({
		"name": "input_key_press",
		"description": "Press and hold a key in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"key": {"type": "string", "description": "Key name (e.g., 'KEY_A', 'KEY_SPACE', 'KEY_UP')"},
				"shift": {"type": "boolean", "default": false},
				"ctrl": {"type": "boolean", "default": false},
				"alt": {"type": "boolean", "default": false},
				"duration_ms": {"type": "integer", "default": 100, "description": "Press duration in milliseconds"}
			},
			"required": ["key"]
		}
	})

	_tool_definitions.append({
		"name": "input_key_tap",
		"description": "Simulates a quick key tap (press and release) in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"key": {"type": "string", "description": "Key name"},
				"shift": {"type": "boolean", "default": false},
				"ctrl": {"type": "boolean", "default": false},
				"alt": {"type": "boolean", "default": false}
			},
			"required": ["key"]
		}
	})

	_tool_definitions.append({
		"name": "input_key_release",
		"description": "Release a held key in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"key": {"type": "string", "description": "Key name to release"}
			},
			"required": ["key"]
		}
	})

	_tool_definitions.append({
		"name": "input_mouse_move",
		"description": "Move the mouse cursor in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"position": {
					"type": "object",
					"properties": {
						"x": {"type": "number"},
						"y": {"type": "number"}
					},
					"required": ["x", "y"]
				},
				"relative": {"type": "boolean", "default": false, "description": "Position is relative"}
			},
			"required": ["position"]
		}
	})

	_tool_definitions.append({
		"name": "input_mouse_click",
		"description": "Click a mouse button in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"button": {"type": "string", "enum": ["left", "right", "middle"], "default": "left"},
				"position": {"type": "object", "description": "Click position {x, y}"},
				"double": {"type": "boolean", "default": false, "description": "Double click"},
				"duration_ms": {"type": "integer", "default": 50}
			},
			"required": []
		}
	})

	_tool_definitions.append({
		"name": "input_action_press",
		"description": "Press an input action in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"action": {"type": "string", "description": "Action name from InputMap"},
				"strength": {"type": "number", "default": 1.0, "minimum": 0.0, "maximum": 1.0}
			},
			"required": ["action"]
		}
	})

	_tool_definitions.append({
		"name": "input_action_release",
		"description": "Release an input action in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"action": {"type": "string", "description": "Action name to release"}
			},
			"required": ["action"]
		}
	})

	_tool_definitions.append({
		"name": "input_type_text",
		"description": "Type text character by character in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"text": {"type": "string", "description": "Text to type"},
				"interval_ms": {"type": "integer", "default": 50, "description": "Delay between keystrokes"}
			},
			"required": ["text"]
		}
	})

	# Game control tools
	_tool_definitions.append({
		"name": "game_pause",
		"description": "Pause the running game",
		"inputSchema": {
			"type": "object",
			"properties": {},
			"required": []
		}
	})

	_tool_definitions.append({
		"name": "game_resume",
		"description": "Resume the paused game",
		"inputSchema": {
			"type": "object",
			"properties": {},
			"required": []
		}
	})

	_tool_definitions.append({
		"name": "game_set_time_scale",
		"description": "Set the game time scale (1.0 = normal, 0.5 = half speed, 2.0 = double speed)",
		"inputSchema": {
			"type": "object",
			"properties": {
				"scale": {"type": "number", "minimum": 0.0, "maximum": 10.0, "description": "Time scale factor"}
			},
			"required": ["scale"]
		}
	})

	_tool_definitions.append({
		"name": "game_is_running",
		"description": "Check if the game is currently running and responsive",
		"inputSchema": {
			"type": "object",
			"properties": {},
			"required": []
		}
	})

	# Runtime query tools
	_tool_definitions.append({
		"name": "runtime_get_node",
		"description": "Get a node from the running game scene tree",
		"inputSchema": {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path in the running scene"}
			},
			"required": ["path"]
		}
	})

	_tool_definitions.append({
		"name": "runtime_call_method",
		"description": "Call a method on a node in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path"},
				"method": {"type": "string", "description": "Method name to call"},
				"args": {"type": "array", "default": [], "description": "Arguments to pass"}
			},
			"required": ["path", "method"]
		}
	})

	_tool_definitions.append({
		"name": "runtime_get_property",
		"description": "Get a property value from a node in the running game",
		"inputSchema": {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path"},
				"property": {"type": "string", "description": "Property name"}
			},
			"required": ["path", "property"]
		}
	})

	_tool_definitions.append({
		"name": "runtime_get_performance",
		"description": "Get performance statistics from the running game",
		"inputSchema": {
			"type": "object",
			"properties": {},
			"required": []
		}
	})

	# Capture tools
	_tool_definitions.append({
		"name": "screenshot_capture_runtime",
		"description": "Capture a screenshot of the running game viewport",
		"inputSchema": {
			"type": "object",
			"properties": {
				"format": {"type": "string", "enum": ["png", "jpg"], "default": "png"},
				"quality": {"type": "integer", "default": 90, "minimum": 1, "maximum": 100}
			},
			"required": []
		}
	})

	_tool_definitions.append({
		"name": "screenshot_list",
		"description": "List all captured screenshots",
		"inputSchema": {
			"type": "object",
			"properties": {},
			"required": []
		}
	})


## Create a proxy handler for a tool definition
func _create_proxy_handler(tool_def: Dictionary) -> MCPToolHandler:
	var definition := MCPToolDefinition.new(
		tool_def.name,
		tool_def.description,
		tool_def.inputSchema
	)
	return MCPToolHandler.new(definition, _execute_proxy.bind(tool_def.name))


## Execute proxied tool (callback for MCPToolHandler)
func _execute_proxy(params: Dictionary, tool_name: String) -> MCPToolResult:
	return await forward_to_game(tool_name, params)


## Convert HTTP response to MCPToolResult
func _convert_to_mcp_result(result: Dictionary) -> MCPToolResult:
	var content: Array = result.get("content", [])

	if content.is_empty():
		return MCPToolResult.text("Tool executed successfully")

	# Check if it's an image result
	if result.get("type") == "image" or (content.size() > 0 and content[0].get("type") == "image"):
		var data: String = result.get("data", "")
		if data.is_empty() and content.size() > 0:
			data = content[0].get("data", "")
		var mime_type: String = result.get("mimeType", "image/png")
		if mime_type.is_empty() and content.size() > 0:
			mime_type = content[0].get("mimeType", "image/png")
		if not data.is_empty():
			return MCPToolResult.image(data, mime_type)

	# Text result
	var text: String = ""
	for item: Dictionary in content:
		if item.get("type") == "text":
			text += item.get("text", "")

	if text.is_empty():
		text = "Tool executed successfully"

	return MCPToolResult.text(text)


## Convert HTTP error code to MCP error code
func _error_code_to_mcp(code: String) -> int:
	match code:
		MCPConstants.HTTP_ERROR_GAME_NOT_RUNNING:
			return MCPError.Code.CONNECTION_REJECTED  # Game not available
		MCPConstants.HTTP_ERROR_TOOL_NOT_FOUND:
			return MCPError.Code.NOT_FOUND
		MCPConstants.HTTP_ERROR_INVALID_PARAMS:
			return MCPError.Code.INVALID_PARAMS
		MCPConstants.HTTP_ERROR_EXECUTION_ERROR:
			return MCPError.Code.INTERNAL_ERROR
		MCPConstants.HTTP_ERROR_TIMEOUT:
			return MCPError.Code.INTERNAL_ERROR
		MCPConstants.HTTP_ERROR_INVALID_REQUEST:
			return MCPError.Code.INVALID_REQUEST
		_:
			return MCPError.Code.INTERNAL_ERROR

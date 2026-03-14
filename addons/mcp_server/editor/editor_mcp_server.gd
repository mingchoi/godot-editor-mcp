## Editor MCP Server
## Main server for handling editor-related MCP requests.
extends Node
class_name EditorMCPServer

const SERVER_NAME: String = "EditorMCP"

var _config: MCPServerConfig
var _ws_server: MCPWebSocketServer
var _tool_registry: ToolRegistry
var _request_router: RequestRouter
var _logger: MCPLogger
var _editor_interface: EditorInterface
var _runtime_tool_proxy: RuntimeToolProxy
var _settings: MCPSettings

# Keep references to tool objects to prevent garbage collection
# (MCPToolHandler Callables reference methods on these objects)
var _tool_objects: Array[RefCounted] = []


func _init(config: MCPServerConfig, logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_config = config
	_logger = logger.child(SERVER_NAME) if logger else MCPLogger.new("[%s]" % SERVER_NAME)
	_editor_interface = editor_interface
	_tool_registry = ToolRegistry.new()
	_request_router = RequestRouter.new(_tool_registry, _logger.child("Router"))

	# Load settings for runtime tool proxy
	_settings = MCPSettings.load_or_create()


func _ready() -> void:
	# Register all editor tools
	_register_tools()

	# Register runtime tool proxy
	_register_runtime_tools()


## Starts the WebSocket server
func start() -> Error:
	if _ws_server != null:
		_logger.warning("Server already exists")
		return OK

	_ws_server = MCPWebSocketServer.new(_config.port, _config.host)
	_ws_server.set_auth_token(_config.token)

	# Connect signal handlers
	_ws_server.client_connected.connect(_on_client_connected)
	_ws_server.client_disconnected.connect(_on_client_disconnected)
	_ws_server.message_received.connect(_on_message_received)

	add_child(_ws_server)

	var err: Error = _ws_server.start()
	if err != OK:
		_logger.error("Failed to start server", {"error": err})
		return err

	_logger.info("Server started", {"port": _config.port, "host": _config.host})
	return OK


## Stops the WebSocket server
func stop() -> void:
	if _ws_server != null:
		_ws_server.stop()
		_ws_server.queue_free()
		_ws_server = null
		_logger.info("Server stopped")


## Checks if the server is running
func is_running() -> bool:
	return _ws_server != null and _ws_server.is_running()


## Gets the tool registry for external tool registration
func get_tool_registry() -> ToolRegistry:
	return _tool_registry


## Registers all editor tools
func _register_tools() -> void:
	# Scene tools - pass EditorInterface
	var scene_tools := SceneTools.new(_logger, _editor_interface)
	scene_tools.register_all(_tool_registry)
	_tool_objects.append(scene_tools)

	# Node tools
	var node_tools := NodeTools.new(_logger, _editor_interface)
	node_tools.register_all(_tool_registry)
	_tool_objects.append(node_tools)

	# FileSystem tools
	var filesystem_tools := FileSystemTools.new(_logger, _editor_interface)
	filesystem_tools.register_all(_tool_registry)
	_tool_objects.append(filesystem_tools)

	# Selection tools
	var selection_tools := SelectionTools.new(_logger, _editor_interface)
	selection_tools.register_all(_tool_registry)
	_tool_objects.append(selection_tools)

	# Script tools
	var script_tools := ScriptTools.new(_logger, _editor_interface)
	script_tools.register_all(_tool_registry)
	_tool_objects.append(script_tools)

	# Undo tools
	var undo_tools := UndoTools.new(_logger, _editor_interface)
	undo_tools.register_all(_tool_registry)
	_tool_objects.append(undo_tools)

	# Capture tools (screenshots)
	var capture_tools := EditorCaptureTools.new(_logger, _editor_interface)
	capture_tools.register_all(_tool_registry)
	_tool_objects.append(capture_tools)

	# Viewport navigation tools
	var viewport_tools := EditorViewportTools.new(_logger, _editor_interface)
	viewport_tools.register_all(_tool_registry)
	_tool_objects.append(viewport_tools)

	# Editor log tools
	var editor_log_tools := EditorLogTools.new(_logger, _editor_interface)
	editor_log_tools.register_all(_tool_registry)
	_tool_objects.append(editor_log_tools)

	# Editor restart tools
	var editor_restart_tool := EditorRestartTool.new(_logger, _editor_interface)
	editor_restart_tool.register_all(_tool_registry)
	_tool_objects.append(editor_restart_tool)

	_logger.info("Tools registered", {"count": _tool_registry.size()})


## Registers runtime tool proxy (for forwarding to game)
func _register_runtime_tools() -> void:
	if _settings == null or _settings.runtime_http == null:
		_logger.warning("Runtime HTTP config not available, skipping runtime tool proxy")
		return

	_runtime_tool_proxy = RuntimeToolProxy.new(_settings.runtime_http, _logger)
	_runtime_tool_proxy.register_all(_tool_registry)
	_logger.info("Runtime tool proxy registered", {"count": _runtime_tool_proxy._tool_definitions.size() if _runtime_tool_proxy else 0})


## Handles new client connections
func _on_client_connected(conn_id: int) -> void:
	_logger.info("Client connected", {"conn_id": conn_id})


## Handles client disconnections
func _on_client_disconnected(conn_id: int) -> void:
	_logger.info("Client disconnected", {"conn_id": conn_id})


## Handles incoming messages (supports async tool execution)
func _on_message_received(conn_id: int, message: String) -> void:
	_logger.debug("Message received", {"conn_id": conn_id, "length": message.length()})

	# Parse the request
	var parse_result: Dictionary = MCPJSONRPC.parse_request(message)
	if not parse_result.valid:
		var error_response: String = MCPJSONRPC.create_error(
			null,
			parse_result.error.code,
			parse_result.error.message,
			parse_result.error.data
		)
		_ws_server.send_to(conn_id, error_response)
		return

	var request: MCPRequest = parse_result.request

	# Route and execute (await for async tool support)
	var response: String = await _request_router.route(request)

	# Send response (skip if empty - notifications don't need response)
	if not response.is_empty():
		_ws_server.send_to(conn_id, response)

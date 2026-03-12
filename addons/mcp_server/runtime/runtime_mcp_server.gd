## Runtime MCP Server
## Server for handling runtime MCP requests (input, capture, game control).
extends Node
class_name RuntimeMCPServer

const SERVER_NAME: String = "RuntimeMCP"

var _config: MCPServerConfig
var _ws_server: MCPWebSocketServer
var _tool_registry: ToolRegistry
var _request_router: RequestRouter
var _logger: MCPLogger

# Keep references to tool objects to prevent garbage collection
# (MCPToolHandler Callables reference methods on these objects)
var _tool_objects: Array[RefCounted] = []


func _init(config: MCPServerConfig, logger: MCPLogger = null) -> void:
	_config = config
	_logger = logger.child(SERVER_NAME) if logger else MCPLogger.new("[%s]" % SERVER_NAME)
	_tool_registry = ToolRegistry.new()
	_request_router = RequestRouter.new(_tool_registry, _logger.child("Router"))


func _ready() -> void:
	# Register all runtime tools
	_register_tools()


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


## Registers all runtime tools
func _register_tools() -> void:
	# Input tools
	var input_tools := InputTools.new(_logger)
	input_tools.register_all(_tool_registry)
	_tool_objects.append(input_tools)

	# Capture tools
	var capture_tools := CaptureTools.new(_logger)
	capture_tools.register_all(_tool_registry)
	_tool_objects.append(capture_tools)

	# Game control tools
	var game_control_tools := GameControlTools.new(_logger)
	game_control_tools.register_all(_tool_registry)
	_tool_objects.append(game_control_tools)

	# Runtime query tools
	var runtime_query_tools := RuntimeQueryTools.new(_logger)
	runtime_query_tools.register_all(_tool_registry)
	_tool_objects.append(runtime_query_tools)

	_logger.info("Tools registered", {"count": _tool_registry.size()})


## Handles new client connections
func _on_client_connected(conn_id: int) -> void:
	_logger.info("Client connected", {"conn_id": conn_id})


## Handles client disconnections
func _on_client_disconnected(conn_id: int) -> void:
	_logger.info("Client disconnected", {"conn_id": conn_id})


## Handles incoming messages
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

	# Route and execute
	var response: String = _request_router.route(request)

	# Send response (skip if empty - notifications don't need response)
	if not response.is_empty():
		_ws_server.send_to(conn_id, response)

## Runtime HTTP Server
## Lightweight HTTP server running in the game runtime.
## Handles tool execution requests from the editor.
extends Node
class_name RuntimeHTTPServer

const SERVER_NAME: String = "RuntimeHTTP"

var _config: RuntimeHTTPConfig
var _logger: MCPLogger
var _tcp_server: TCPServer
var _connections: Array[HTTPConnection] = []
var _tool_registry: ToolRegistry
var _start_time: float = 0.0

# Performance tracking (T036)
var _total_requests: int = 0
var _total_errors: int = 0
var _total_execution_time_ms: int = 0

# Request queue for concurrent handling (T035)
var _request_queue: Array[Dictionary] = []
var _is_processing_queue: bool = false

# Keep references to tool objects to prevent garbage collection
var _tool_objects: Array[RefCounted] = []


func _init(config: RuntimeHTTPConfig, logger: MCPLogger = null) -> void:
	_config = config
	_logger = logger.child(SERVER_NAME) if logger else MCPLogger.new("[%s]" % SERVER_NAME)
	_tool_registry = ToolRegistry.new()


func _ready() -> void:
	_register_tools()


func _process(_delta: float) -> void:
	if _tcp_server == null:
		return

	# Optimized: Early exit if no connections and no pending requests (T033)
	if _connections.is_empty() and not _tcp_server.is_connection_available():
		return

	# Accept new connections
	_accept_new_connections()

	# Poll existing connections (optimized - only poll active connections)
	_poll_connections_optimized()

	# Process request queue (T035)
	_process_request_queue()


## Starts the HTTP server
func start() -> Error:
	if _tcp_server != null:
		_logger.warning("Server already running")
		return OK

	_tcp_server = TCPServer.new()
	var err: Error = _tcp_server.listen(_config.port, _config.host)
	if err != OK:
		_logger.error("Failed to start HTTP server", {"error": err, "port": _config.port})
		return err

	_start_time = Time.get_ticks_msec() / 1000.0
	_logger.info("HTTP server started", {"port": _config.port, "host": _config.host})
	return OK


## Stops the HTTP server
func stop() -> void:
	if _tcp_server == null:
		return

	# Close all connections
	for conn: HTTPConnection in _connections:
		conn.close()
	_connections.clear()

	_tcp_server.stop()
	_tcp_server = null
	_logger.info("HTTP server stopped")


## Checks if the server is running
func is_running() -> bool:
	return _tcp_server != null and _tcp_server.is_listening()


## Gets the tool registry for external tool registration
func get_tool_registry() -> ToolRegistry:
	return _tool_registry


## Gets server uptime in seconds
func get_uptime() -> float:
	if _start_time == 0.0:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - _start_time


## Gets performance metrics (T036)
func get_metrics() -> Dictionary:
	var avg_time: float = 0.0
	if _total_requests > 0:
		avg_time = float(_total_execution_time_ms) / float(_total_requests)

	return {
		"total_requests": _total_requests,
		"total_errors": _total_errors,
		"total_execution_time_ms": _total_execution_time_ms,
		"average_execution_time_ms": avg_time,
		"active_connections": _connections.size(),
		"queued_requests": _request_queue.size(),
		"uptime_seconds": get_uptime(),
		"tools_registered": _tool_registry.size()
	}


## Accept new connections
func _accept_new_connections() -> void:
	if _tcp_server == null:
		return

	if not _tcp_server.is_connection_available():
		return

	if _connections.size() >= _config.max_connections:
		_logger.warning("Max connections reached, rejecting new connection")
		return

	var peer: StreamPeerTCP = _tcp_server.take_connection()
	if peer == null:
		return

	var conn := HTTPConnection.new(peer, _logger)
	conn.response_ready.connect(_on_response_ready.bind(conn))
	conn.connection_closed.connect(_on_connection_closed.bind(conn))
	_connections.append(conn)

	_logger.debug("New connection accepted")


## Poll existing connections
func _poll_connections() -> void:
	var to_remove: Array[int] = []

	for i: int in range(_connections.size()):
		var conn: HTTPConnection = _connections[i]
		conn.poll()

		if conn.is_closed():
			to_remove.append(i)
		elif conn.get_request() != null and conn.get_request().method != HTTPRequestParser.Method.UNKNOWN:
			# Request is complete, handle it
			_handle_request(conn)

	# Remove closed connections (reverse order to maintain indices)
	for i: int in range(to_remove.size() - 1, -1, -1):
		_connections.remove_at(to_remove[i])


## Optimized poll for connections (T033)
func _poll_connections_optimized() -> void:
	var write_idx: int = 0

	for i: int in range(_connections.size()):
		var conn: HTTPConnection = _connections[i]
		conn.poll()

		if not conn.is_closed():
			# Keep connection, move to write position if needed
			if write_idx != i:
				_connections[write_idx] = conn
			write_idx += 1

			# Handle complete requests
			if conn.get_request() != null and conn.get_request().method != HTTPRequestParser.Method.UNKNOWN:
				_handle_request(conn)

	# Trim array to remove closed connections
	while _connections.size() > write_idx:
		_connections.pop_back()


## Process request queue (T035)
func _process_request_queue() -> void:
	if _is_processing_queue or _request_queue.is_empty():
		return

	_is_processing_queue = true

	# Process up to 5 requests per frame to avoid blocking
	var processed: int = 0
	while not _request_queue.is_empty() and processed < 5:
		var req: Dictionary = _request_queue.pop_front()
		_process_queued_request(req)
		processed += 1

	_is_processing_queue = false


## Process a queued request
func _process_queued_request(req: Dictionary) -> void:
	var conn: HTTPConnection = req.get("conn", null)
	var request: HTTPRequestParser.ParsedRequest = req.get("request", null)

	if conn == null or request == null:
		return

	_handle_request_for_connection(conn, request)


## Handle request for specific connection (extracted for queue support)
func _handle_request_for_connection(conn: HTTPConnection, request: HTTPRequestParser.ParsedRequest) -> void:
	_log_debug_request(request)

	# Route based on path and method
	match request.path:
		"/execute":
			if request.method == HTTPRequestParser.Method.POST:
				_handle_execute(conn, request)
			elif request.method == HTTPRequestParser.Method.OPTIONS:
				conn.send_response(HTTPResponseBuilder.cors_preflight())
			else:
				conn.send_response(HTTPResponseBuilder.error(405, "METHOD_NOT_ALLOWED", "Method not allowed"))

		"/status":
			if request.method == HTTPRequestParser.Method.GET:
				_handle_status(conn)
			else:
				conn.send_response(HTTPResponseBuilder.error(405, "METHOD_NOT_ALLOWED", "Method not allowed"))

		"/tools":
			if request.method == HTTPRequestParser.Method.GET:
				_handle_tools(conn)
			else:
				conn.send_response(HTTPResponseBuilder.error(405, "METHOD_NOT_ALLOWED", "Method not allowed"))

		_:
			conn.send_response(HTTPResponseBuilder.not_found("Endpoint not found: %s" % request.path))


## Handle a complete HTTP request
func _handle_request(conn: HTTPConnection) -> void:
	var request: HTTPRequestParser.ParsedRequest = conn.get_request()
	if request == null:
		conn.send_response(HTTPResponseBuilder.bad_request("Invalid request"))
		return

	_log_debug_request(request)

	# Route based on path and method
	match request.path:
		"/execute":
			if request.method == HTTPRequestParser.Method.POST:
				_handle_execute(conn, request)
			elif request.method == HTTPRequestParser.Method.OPTIONS:
				conn.send_response(HTTPResponseBuilder.cors_preflight())
			else:
				conn.send_response(HTTPResponseBuilder.error(405, "METHOD_NOT_ALLOWED", "Method not allowed"))

		"/status":
			if request.method == HTTPRequestParser.Method.GET:
				_handle_status(conn)
			else:
				conn.send_response(HTTPResponseBuilder.error(405, "METHOD_NOT_ALLOWED", "Method not allowed"))

		"/tools":
			if request.method == HTTPRequestParser.Method.GET:
				_handle_tools(conn)
			else:
				conn.send_response(HTTPResponseBuilder.error(405, "METHOD_NOT_ALLOWED", "Method not allowed"))

		_:
			conn.send_response(HTTPResponseBuilder.not_found("Endpoint not found: %s" % request.path))


## Handle /execute endpoint (supports async tools)
func _handle_execute(conn: HTTPConnection, request: HTTPRequestParser.ParsedRequest) -> void:
	var body: Dictionary = HTTPRequestParser.parse_json_body(request)

	if not body.has("tool"):
		conn.send_response(HTTPResponseBuilder.bad_request("Missing 'tool' field"))
		return

	var tool_name: String = body.get("tool", "")
	var params: Dictionary = body.get("params", {})

	if not _tool_registry.has_tool(tool_name):
		conn.send_response(HTTPResponseBuilder.not_found("Tool not found: %s" % tool_name))
		return

	var handler: MCPToolHandler = _tool_registry.get_tool(tool_name)

	# Validate parameters
	var validation_errors: Array[String] = handler.validate_params(params)
	if not validation_errors.is_empty():
		conn.send_response(HTTPResponseBuilder.error(400, MCPConstants.HTTP_ERROR_INVALID_PARAMS,
			"Parameter validation failed", {"errors": validation_errors}))
		return

	# Execute tool (await for async tool support)
	var start_time: int = Time.get_ticks_msec()
	var result: MCPToolResult = await handler.execute(params)
	var execution_time: int = Time.get_ticks_msec() - start_time

	# Build response
	if result.is_error:
		var error_msg: String = ""
		if not result.content.is_empty():
			error_msg = result.content[0].get("text", "Unknown error")
		conn.send_response(HTTPResponseBuilder.error(500, MCPConstants.HTTP_ERROR_EXECUTION_ERROR, error_msg))
	else:
		conn.send_response(HTTPResponseBuilder.success(result.to_response_dict(), execution_time))


## Handle /status endpoint
func _handle_status(conn: HTTPConnection) -> void:
	var status: Dictionary = {
		"status": "running",
		"tools_available": _tool_registry.size(),
		"uptime_seconds": get_uptime()
	}
	conn.send_response(HTTPResponseBuilder.ok(status))


## Handle /tools endpoint
func _handle_tools(conn: HTTPConnection) -> void:
	var tools: Array[Dictionary] = _tool_registry.list_tools()
	conn.send_response(HTTPResponseBuilder.ok({"tools": tools}))


## Register all runtime tools
func _register_tools() -> void:
	# Input tools
	var input_tools := InputTools.new(_logger)
	input_tools.register_all(_tool_registry)
	_tool_objects.append(input_tools)

	# Game control tools
	var game_control_tools := GameControlTools.new(_logger)
	game_control_tools.register_all(_tool_registry)
	_tool_objects.append(game_control_tools)

	# Runtime query tools
	var runtime_query_tools := RuntimeQueryTools.new(_logger)
	runtime_query_tools.register_all(_tool_registry)
	_tool_objects.append(runtime_query_tools)

	# Capture tools (screenshots)
	var capture_tools := CaptureTools.new(_logger)
	capture_tools.register_all(_tool_registry)
	_tool_objects.append(capture_tools)

	_logger.info("Runtime tools registered", {"count": _tool_registry.size()})


## Response ready callback
func _on_response_ready(_response: String, conn: HTTPConnection) -> void:
	# Response is already set in connection, will be sent in poll
	_logger.debug("Response ready for connection")


## Connection closed callback
func _on_connection_closed(conn: HTTPConnection) -> void:
	var idx: int = _connections.find(conn)
	if idx >= 0:
		_connections.remove_at(idx)
	_logger.debug("Connection closed")


## Log debug request info
func _log_debug_request(request: HTTPRequestParser.ParsedRequest) -> void:
	_logger.debug("Request: %s %s" % [HTTPRequestParser.ParsedRequest._method_to_string(request.method), request.path])

## Runtime HTTP Client
## HTTP client in editor for communicating with game runtime HTTP server.
## Uses Godot's HTTPClient for non-blocking requests.
class_name RuntimeHTTPClient
extends RefCounted

## Signal emitted when request completes
signal request_completed(response: Dictionary)

## Signal emitted when request fails
signal request_failed(error_code: String, error_message: String)

## Signal emitted when connection status changes
signal connection_status_changed(is_connected: bool)

## Connection status structure (from data-model.md)
class ConnectionStatus extends RefCounted:
	var is_connected: bool = false
	var last_heartbeat: float = 0.0
	var game_pid: int = -1
	var port: int = 0
	var tools_available: int = 0
	var uptime_seconds: float = 0.0

	func _to_string() -> String:
		return "ConnectionStatus[connected=%s, port=%d, tools=%d]" % [is_connected, port, tools_available]

var _config: RuntimeHTTPConfig
var _logger: MCPLogger
var _http_client: HTTPClient
var _is_busy: bool = false
var _status_cache: Dictionary = {}
var _last_status_check: float = 0.0
var _status_cache_ttl: float = 1.0  # Cache status for 1 second
var _connection_status: ConnectionStatus
var _was_connected: bool = false


func _init(config: RuntimeHTTPConfig, logger: MCPLogger = null) -> void:
	_config = config
	_logger = logger.child("RuntimeHTTPClient") if logger else MCPLogger.new("[RuntimeHTTPClient]")
	_connection_status = ConnectionStatus.new()
	_connection_status.port = config.port


## Execute a tool on the game runtime
## Returns immediately, emits request_completed or request_failed when done
func execute_tool_async(tool_name: String, params: Dictionary) -> void:
	if _is_busy:
		_logger.warning("Client busy, cannot execute tool")
		request_failed.emit("CLIENT_BUSY", "HTTP client is busy with another request")
		return

	_is_busy = true
	_perform_request("/execute", {"tool": tool_name, "params": params}, tool_name)


## Execute a tool and wait for result (synchronous style using await)
func execute_tool(tool_name: String, params: Dictionary) -> Dictionary:
	if _is_busy:
		return {
			"success": false,
			"error": {
				"code": "CLIENT_BUSY",
				"message": "HTTP client is busy with another request"
			}
		}

	_is_busy = true
	var result: Dictionary = await _perform_request_awaitable("/execute", {"tool": tool_name, "params": params}, tool_name)
	_is_busy = false
	return result


## Check if the game runtime is running
func check_status() -> Dictionary:
	# Use cached status if available and fresh
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _status_cache.is_empty() and (now - _last_status_check) < _status_cache_ttl:
		return _status_cache

	var result: Dictionary = await _perform_request_awaitable("/status", {}, "", HTTPClient.METHOD_GET)
	_last_status_check = now

	if result.get("success", false):
		_status_cache = result
		# Update connection status
		var data: Dictionary = result.get("result", result)
		_connection_status.is_connected = true
		_connection_status.last_heartbeat = now
		_connection_status.tools_available = data.get("tools_available", 0)
		_connection_status.uptime_seconds = data.get("uptime_seconds", 0.0)

		# Emit signal on connection change
		if not _was_connected:
			connection_status_changed.emit(true)
			_was_connected = true
	else:
		_status_cache = {
			"success": false,
			"error": result.get("error", {"code": "UNKNOWN", "message": "Status check failed"})
		}
		_connection_status.is_connected = false

		# Emit signal on disconnection
		if _was_connected:
			connection_status_changed.emit(false)
			_was_connected = false

	return _status_cache


## Check if game is connected (cached)
func is_game_connected() -> bool:
	return _connection_status.is_connected


## Get connection status object
func get_connection_status() -> ConnectionStatus:
	return _connection_status


## Get cached status (no HTTP call)
func get_cached_status() -> Dictionary:
	return _status_cache


## Clear status cache
func clear_status_cache() -> void:
	_status_cache.clear()
	_last_status_check = 0.0
	_connection_status.is_connected = false
	_was_connected = false


## Perform async request
func _perform_request(endpoint: String, body: Dictionary, tool_name: String = "", method: int = HTTPClient.METHOD_POST) -> void:
	var result: Dictionary = await _perform_request_awaitable(endpoint, body, tool_name, method)
	_is_busy = false

	if result.get("success", false):
		request_completed.emit(result)
	else:
		var error: Dictionary = result.get("error", {})
		request_failed.emit(error.get("code", "UNKNOWN"), error.get("message", "Request failed"))


## Perform request and return result (awaitable)
func _perform_request_awaitable(endpoint: String, body: Dictionary, tool_name: String = "", method: int = HTTPClient.METHOD_POST) -> Dictionary:
	var http := HTTPClient.new()
	var timeout_ms: int = _get_timeout_for_tool(tool_name)
	var connection_timeout_ms: int = _config.connection_timeout_ms

	# Connect to server
	var err: Error = http.connect_to_host(_config.host, _config.port)
	if err != OK:
		_logger.error("Failed to connect to host", {"error": err})
		return _create_error_response("CONNECTION_FAILED", "Failed to connect to game runtime")

	# Wait for connection with timeout
	var start_time: int = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		await _get_tree().process_frame

		if Time.get_ticks_msec() - start_time > connection_timeout_ms:
			http.close()
			return _create_error_response(MCPConstants.HTTP_ERROR_GAME_NOT_RUNNING,
				"Game runtime is not available. Start the game to use runtime tools.")

	var status: int = http.get_status()
	if status != HTTPClient.STATUS_CONNECTED:
		http.close()
		return _create_error_response(MCPConstants.HTTP_ERROR_GAME_NOT_RUNNING,
			"Failed to connect to game runtime (status: %d)" % status)

	# Build request
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Accept: application/json"
	]

	var body_str: String = ""
	if method == HTTPClient.METHOD_POST:
		body_str = JSON.stringify(body)
		headers.append("Content-Length: %d" % body_str.length())

	# Send request
	err = http.request(method, endpoint, headers, body_str)
	if err != OK:
		http.close()
		return _create_error_response("REQUEST_FAILED", "Failed to send request to game runtime")

	# Wait for response with timeout
	start_time = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await _get_tree().process_frame

		if Time.get_ticks_msec() - start_time > timeout_ms:
			http.close()
			return _create_error_response(MCPConstants.HTTP_ERROR_TIMEOUT,
				"Tool execution timed out after %dms" % timeout_ms)

	# Read response
	if http.get_status() != HTTPClient.STATUS_BODY and http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		return _create_error_response("RESPONSE_ERROR", "Unexpected response status: %d" % http.get_status())

	# Read response body
	var response_body: PackedByteArray = []
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk: PackedByteArray = http.read_response_body_chunk()
		if not chunk.is_empty():
			response_body.append_array(chunk)
		await _get_tree().process_frame

	# Check response code
	var response_code: int = http.get_response_code()
	http.close()

	if response_code == 0:
		return _create_error_response(MCPConstants.HTTP_ERROR_GAME_NOT_RUNNING,
			"Game runtime is not available")

	if response_code >= 400:
		# Try to parse error from body
		var error_body: String = response_body.get_string_from_utf8()
		var error_response: Dictionary = _parse_json(error_body)
		if error_response.has("error"):
			return error_response
		return _create_error_response("HTTP_ERROR", "HTTP error %d" % response_code)

	# Parse success response
	var response_str: String = response_body.get_string_from_utf8()
	var result: Dictionary = _parse_json(response_str)

	if result.is_empty():
		return _create_error_response("PARSE_ERROR", "Failed to parse response from game runtime")

	_logger.debug("Request completed", {"endpoint": endpoint, "response_code": response_code})
	return result


## Get timeout for specific tool
func _get_timeout_for_tool(tool_name: String) -> int:
	return _config.get_timeout_for_tool(tool_name)


## Create error response dictionary
func _create_error_response(code: String, message: String) -> Dictionary:
	return {
		"success": false,
		"error": {
			"code": code,
			"message": message
		}
	}


## Parse JSON string safely
func _parse_json(json_str: String) -> Dictionary:
	if json_str.is_empty():
		return {}

	var json := JSON.new()
	var err: Error = json.parse(json_str)
	if err != OK:
		return {}

	return json.data if json.data is Dictionary else {}


## Get scene tree for await
func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

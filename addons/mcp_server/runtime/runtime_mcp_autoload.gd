## Runtime MCP Autoload
## Singleton that manages the Runtime MCP Server and HTTP Server.
## Only active in debug builds.
extends Node

const AUTOLOAD_NAME: String = "RuntimeMCP"

var _server: RuntimeMCPServer
var _http_server: RuntimeHTTPServer
var _settings: MCPSettings
var _logger: MCPLogger


func _ready() -> void:
	# Only run in debug builds (per constitution)
	if not OS.is_debug_build():
		push_warning("Runtime MCP: Skipping startup in release build")
		queue_free()
		return

	_logger = MCPLogger.new("[RuntimeMCP]")
	_logger.info("Runtime MCP initializing")

	# Load settings
	_settings = MCPSettings.load_or_create()

	# Start WebSocket server if enabled (legacy, for backward compatibility)
	if _settings.runtime_mcp.enabled:
		_start_server()
	else:
		_logger.info("Runtime MCP WebSocket server disabled in settings")

	# Start HTTP server if enabled (new HTTP relay architecture)
	if _settings.runtime_http != null and _settings.runtime_http.enabled:
		_start_http_server()
	else:
		_logger.info("Runtime HTTP server disabled in settings")


func _exit_tree() -> void:
	if _server != null:
		_server.stop()
		_server.queue_free()
		_server = null

	if _http_server != null:
		_http_server.stop()
		_http_server.queue_free()
		_http_server = null


func _start_server() -> void:
	if _server != null:
		_logger.warning("WebSocket server already running")
		return

	_server = RuntimeMCPServer.new(_settings.runtime_mcp, _logger)
	add_child(_server)

	var err: Error = _server.start()
	if err != OK:
		_logger.error("Failed to start Runtime MCP Server", {"error": err})
		_server.queue_free()
		_server = null
	else:
		_logger.info("Runtime MCP WebSocket Server started", {
			"port": _settings.runtime_mcp.port,
			"host": _settings.runtime_mcp.host
		})


func _start_http_server() -> void:
	if _http_server != null:
		_logger.warning("HTTP server already running")
		return

	_http_server = RuntimeHTTPServer.new(_settings.runtime_http, _logger)
	add_child(_http_server)

	var err: Error = _http_server.start()
	if err != OK:
		_logger.error("Failed to start Runtime HTTP Server", {"error": err})
		_http_server.queue_free()
		_http_server = null
	else:
		_logger.info("Runtime HTTP Server started", {
			"port": _settings.runtime_http.port,
			"host": _settings.runtime_http.host
		})


func _stop_server() -> void:
	if _server == null:
		return

	_server.stop()
	_server.queue_free()
	_server = null
	_logger.info("Runtime MCP WebSocket Server stopped")


func _stop_http_server() -> void:
	if _http_server == null:
		return

	_http_server.stop()
	_http_server.queue_free()
	_http_server = null
	_logger.info("Runtime HTTP Server stopped")


## Checks if the WebSocket server is running
func is_running() -> bool:
	return _server != null and _server.is_running()


## Checks if the HTTP server is running
func is_http_running() -> bool:
	return _http_server != null and _http_server.is_running()


## Gets the WebSocket server port
func get_port() -> int:
	if _settings == null or _settings.runtime_mcp == null:
		return MCPConstants.DEFAULT_RUNTIME_PORT
	return _settings.runtime_mcp.port


## Gets the HTTP server port
func get_http_port() -> int:
	if _settings == null or _settings.runtime_http == null:
		return MCPConstants.DEFAULT_RUNTIME_HTTP_PORT
	return _settings.runtime_http.port


## Restarts the WebSocket server
func restart() -> void:
	_stop_server()
	if _settings != null and _settings.runtime_mcp.enabled:
		_start_server()


## Restarts the HTTP server
func restart_http() -> void:
	_stop_http_server()
	if _settings != null and _settings.runtime_http != null and _settings.runtime_http.enabled:
		_start_http_server()


## Gets the HTTP server instance (for tool access)
func get_http_server() -> RuntimeHTTPServer:
	return _http_server

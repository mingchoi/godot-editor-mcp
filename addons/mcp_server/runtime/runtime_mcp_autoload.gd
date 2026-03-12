## Runtime MCP Autoload
## Singleton that manages the Runtime MCP Server.
## Only active in debug builds.
extends Node
class_name RuntimeMCPAutoload

const AUTOLOAD_NAME: String = "RuntimeMCP"

var _server: RuntimeMCPServer
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

	# Start server if enabled
	if _settings.runtime_mcp.enabled:
		_start_server()
	else:
		_logger.info("Runtime MCP disabled in settings")


func _exit_tree() -> void:
	if _server != null:
		_server.stop()
		_server.queue_free()
		_server = null


func _start_server() -> void:
	if _server != null:
		_logger.warning("Server already running")
		return

	_server = RuntimeMCPServer.new(_settings.runtime_mcp, _logger)
	add_child(_server)

	var err: Error = _server.start()
	if err != OK:
		_logger.error("Failed to start Runtime MCP Server", {"error": err})
		_server.queue_free()
		_server = null
	else:
		_logger.info("Runtime MCP Server started", {
			"port": _settings.runtime_mcp.port,
			"host": _settings.runtime_mcp.host
		})


func _stop_server() -> void:
	if _server == null:
		return

	_server.stop()
	_server.queue_free()
	_server = null
	_logger.info("Runtime MCP Server stopped")


## Checks if the server is running
func is_running() -> bool:
	return _server != null and _server.is_running()


## Gets the server port
func get_port() -> int:
	if _settings == null or _settings.runtime_mcp == null:
		return MCPConstants.DEFAULT_RUNTIME_PORT
	return _settings.runtime_mcp.port


## Restarts the server
func restart() -> void:
	_stop_server()
	if _settings != null and _settings.runtime_mcp.enabled:
		_start_server()

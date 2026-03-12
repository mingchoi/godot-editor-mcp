@tool
## MCP Server Plugin
## Main EditorPlugin entry point for the MCP server.
##
## This plugin provides two MCP servers:
## - Editor MCP Server (port 8765): Control the Godot editor
## - Runtime MCP Server (port 8766): Interact with running games (debug only)
extends EditorPlugin
class_name MCPPlugin

const PLUGIN_NAME: String = "MCP Server"
const PLUGIN_VERSION: String = "1.0.0"

var _settings: MCPSettings
var _editor_server: EditorMCPServer
var _logger: MCPLogger


func _enter_tree() -> void:
	# Initialize logger
	_logger = MCPLogger.new("[MCP]", MCPLogger.Level.INFO)
	_logger.info("Plugin initializing", {"version": PLUGIN_VERSION})

	# Load settings
	_settings = MCPSettings.load_or_create()
	_apply_settings()

	# Start Editor MCP Server if enabled
	if _settings.editor_mcp.enabled:
		_start_editor_server()

	_logger.info("Plugin ready")


func _exit_tree() -> void:
	_logger.info("Plugin shutting down")

	# Stop Editor MCP Server
	if _editor_server != null:
		_editor_server.stop()
		_editor_server.queue_free()
		_editor_server = null

	_logger.info("Plugin stopped")


## Gets the plugin settings
func get_settings() -> MCPSettings:
	return _settings


## Saves the current settings
func save_settings() -> Error:
	if _settings == null:
		return ERR_UNCONFIGURED
	return _settings.save_to_file()


## Applies settings to running components
func _apply_settings() -> void:
	if _settings == null:
		return

	# Update log level
	if _logger != null:
		_logger.set_level(_settings.get_log_level_enum())


## Starts the Editor MCP Server
func _start_editor_server() -> void:
	if _editor_server != null:
		_logger.warning("Editor server already running")
		return

	_editor_server = EditorMCPServer.new(_settings.editor_mcp, _logger, get_editor_interface())
	add_child(_editor_server)

	var err: Error = _editor_server.start()
	if err != OK:
		_logger.error("Failed to start Editor MCP Server", {"error": err})
		_editor_server.queue_free()
		_editor_server = null
	else:
		_logger.info("Editor MCP Server started", {
			"port": _settings.editor_mcp.port,
			"host": _settings.editor_mcp.host
		})


## Stops the Editor MCP Server
func _stop_editor_server() -> void:
	if _editor_server == null:
		return

	_editor_server.stop()
	_editor_server.queue_free()
	_editor_server = null
	_logger.info("Editor MCP Server stopped")


## Restarts the Editor MCP Server with current settings
func restart_editor_server() -> void:
	_stop_editor_server()
	if _settings.editor_mcp.enabled:
		_start_editor_server()


## Checks if the Editor MCP Server is running
func is_editor_server_running() -> bool:
	return _editor_server != null and _editor_server.is_running()


## Gets the Editor MCP Server port
func get_editor_server_port() -> int:
	if _settings == null or _settings.editor_mcp == null:
		return MCPConstants.DEFAULT_EDITOR_PORT
	return _settings.editor_mcp.port

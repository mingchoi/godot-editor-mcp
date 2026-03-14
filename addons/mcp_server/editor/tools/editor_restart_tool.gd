## Editor Restart Tool
##
## MCP tool for programmatically restarting the Godot editor.
##
## Tools:
## - editor_restart: Triggers Godot editor restart. The response is returned
##   before the restart begins to ensure the MCP client receives confirmation.
##
## Async Execution:
## The restart is triggered via call_deferred() to ensure the response is sent
## before the editor shuts down. This is critical because:
## 1. The MCP response must be transmitted to the client
## 2. Immediate restart would terminate the WebSocket connection first
## 3. call_deferred() schedules the restart for the next idle frame
##
## Error Handling:
## - Returns error if EditorInterface is not available
## - Logs at info level when restart is triggered
extends RefCounted
class_name EditorRestartTool

const TOOL_RESTART := "editor_restart"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("EditorRestartTool") if logger else MCPLogger.new("[EditorRestartTool]")
	_editor_interface = editor_interface


## Registers all editor restart tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_restart_tool())


func _create_restart_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_RESTART,
		"Restarts the Godot editor. The response is returned before the restart begins.",
		{},  # No input parameters
		[]
	)
	return MCPToolHandler.new(definition, _execute_restart)


# --- Tool Implementations ---

func _execute_restart(_params: Dictionary = {}) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	# Schedule restart AFTER this frame completes
	# This ensures the response is sent before the editor shuts down
	_editor_interface.call_deferred("restart_editor")

	_logger.info("Editor restart initiated")

	return MCPToolResult.text("Editor restart initiated. The MCP connection will be terminated.")

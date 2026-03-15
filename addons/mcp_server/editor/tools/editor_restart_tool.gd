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

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all editor restart tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := EditorRestartTool.new(editor_interface)

	registry.register_tool(
		_create_tool_def("editor_restart", "Restarts the Godot editor. The response is returned before the restart begins.", {}, []),
		tools._execute_restart
	)

	return tools


# --- Tool Implementations ---

func _execute_restart(_args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	# Schedule restart AFTER this frame completes
	# This ensures the response is sent before the editor shuts down
	_editor_interface.call_deferred("restart_editor")

	return MCPToolRegistry.create_response("Editor restart initiated. The MCP connection will be terminated.")


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array, output_schema: Dictionary = {}) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	var tool_def: Dictionary = {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}
	if not output_schema.is_empty():
		tool_def["outputSchema"] = output_schema
	return tool_def

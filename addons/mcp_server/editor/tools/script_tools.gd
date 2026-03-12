## Script Editor Tools
## MCP tools for script editor integration.
extends RefCounted
class_name ScriptTools

const TOOL_OPEN := "script_open"
const TOOL_GET_CURRENT := "script_get_current"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("ScriptTools") if logger else MCPLogger.new("[ScriptTools]")
	_editor_interface = editor_interface


## Registers all script tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_open_tool())
	registry.register(_create_get_current_tool())


func _create_open_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_OPEN,
			"Opens a script in the script editor",
			{
				"path": {"type": "string", "description": "Script file path"},
				"line": {"type": "integer", "default": 1, "description": "Line to scroll to"},
				"column": {"type": "integer", "default": 0, "description": "Column position"}
			},
			["path"]
		)
	return MCPToolHandler.new(definition, _execute_open)


func _create_get_current_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_GET_CURRENT,
			"Gets the currently edited script",
			{},
			[]
		)
	return MCPToolHandler.new(definition, _execute_get_current)


# --- Tool Implementations ---

func _execute_open(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)
	var path: String = params.get("path", "")
	var line: int = params.get("line", 1)
	var column: int = params.get("column", 0)

	# Validate path
	if not FileAccess.file_exists(path):
		return MCPToolResult.error("Script file not found: %s" % path, MCPError.Code.NOT_FOUND)

	# Load the script
	var script: Resource = load(path)
	if script == null:
		return MCPToolResult.error("Failed to load script: %s" % path, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Open in editor
	_editor_interface.edit_script(script, line - 1, column)  # Line is 0-indexed in API

	_logger.info("Script opened", {"path": path, "line": line})
	return MCPToolResult.text("Opened script: %s at line %d" % [path, line], {
		"path": path,
		"line": line,
		"column": column
	})


func _execute_get_current(_params: Dictionary = {}) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)
	var script: Script = _editor_interface.get_current_script()

	if script == null:
		return MCPToolResult.text("No script is currently open", {
			"path": "",
			"has_script": false
		})

	return MCPToolResult.text("Current script: %s" % script.resource_path, {
		"path": script.resource_path,
		"has_script": true,
		"language": _get_script_language(script)
	})


func _get_script_language(script: Script) -> String:
	if script is GDScript:
		return "GDScript"
	# Add more language checks as needed
	return "Unknown"

## Script Editor Tools
## MCP tools for script editor integration.
extends RefCounted
class_name ScriptTools

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all script tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := ScriptTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("script_open", "Opens a script in the script editor", {
			"path": {"type": "string", "description": "Script file path"},
			"line": {"type": "integer", "default": 1, "description": "Line to scroll to"},
			"column": {"type": "integer", "default": 0, "description": "Column position"}
		}, ["path"]),
		tools._execute_open
	)

	registry.register_tool(
		_create_tool_def("script_get_current", "Gets the currently edited script", {}, []),
		tools._execute_get_current
	)

	return tools


# --- Tool Implementations ---

func _execute_open(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var line: int = args.get("line", 1)
	var column: int = args.get("column", 0)

	# Validate path
	if not FileAccess.file_exists(path):
		return {"content": [{"type": "text", "text": "Error: Script file not found: %s" % path}], "isError": true}

	# Load the script
	var script: Resource = load(path)
	if script == null:
		return {"content": [{"type": "text", "text": "Error: Failed to load script: %s" % path}], "isError": true}

	# Open in editor
	_editor_interface.edit_script(script, line - 1, column)  # Line is 0-indexed in API

	return {
		"content": [{"type": "text", "text": "Opened script: %s at line %d" % [path, line]}],
		"isError": false,
		"data": {"path": path, "line": line, "column": column}
	}


func _execute_get_current(_args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var script: Script = _editor_interface.get_current_script()

	if script == null:
		return {
			"content": [{"type": "text", "text": "No script is currently open"}],
			"isError": false,
			"data": {"path": "", "has_script": false}
		}

	return {
		"content": [{"type": "text", "text": "Current script: %s" % script.resource_path}],
		"isError": false,
		"data": {"path": script.resource_path, "has_script": true, "language": _get_script_language(script)}
	}


func _get_script_language(script: Script) -> String:
	if script is GDScript:
		return "GDScript"
	# Add more language checks as needed
	return "Unknown"


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}

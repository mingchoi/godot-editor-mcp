## Script Editor Tools
## MCP tools for script editor integration.
extends RefCounted
class_name ScriptTools

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

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
		}, ["path"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Script file path that was opened"},
				"line": {"type": "integer", "description": "Line number scrolled to"},
				"column": {"type": "integer", "description": "Column position"}
			}
		}),
		tools._execute_open
	)

	registry.register_tool(
		_create_tool_def("script_get_current", "Gets the currently edited script", {}, [], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Script file path (empty if none)"},
				"has_script": {"type": "boolean", "description": "Whether a script is currently open"},
				"language": {"type": "string", "description": "Script language (GDScript, C#, etc.)"}
			}
		}),
		tools._execute_get_current
	)

	registry.register_tool(
		_create_tool_def("node_create_script", "Creates a GDScript file and attaches it to a node", {
			"path": {"type": "string", "description": "Node path in the scene tree"},
			"content": {"type": "string", "description": "GDScript source code content"},
			"script_path": {"type": "string", "description": "Custom file path (e.g., 'res://scripts/player.gd'). Auto-generated if omitted."},
			"overwrite": {"type": "boolean", "default": false, "description": "Whether to overwrite an existing script file"}
		}, ["path", "content"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Node path that received the script"},
				"script_path": {"type": "string", "description": "File path where the script was created"},
				"previous_script": {"type": "string", "description": "Previous script path if one was attached"},
				"created": {"type": "boolean", "description": "Whether the script file was newly created"}
			}
		}),
		tools._execute_create_script
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

	return MCPToolRegistry.create_response("Opened script: %s at line %d" % [path, line], {
		"path": path,
		"line": line,
		"column": column
	})


func _execute_get_current(_args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var script: Script = _editor_interface.get_current_script()

	if script == null:
		return MCPToolRegistry.create_response("No script is currently open", {
			"path": "",
			"has_script": false
		})

	return MCPToolRegistry.create_response("Current script: %s" % script.resource_path, {
		"path": script.resource_path,
		"has_script": true,
		"language": _get_script_language(script)
	})


func _execute_create_script(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var path: String = args.get("path", "")
	var content: String = args.get("content", "")
	var script_path: String = args.get("script_path", "")
	var overwrite: bool = args.get("overwrite", false)

	# Validate content
	if content.is_empty():
		return {"content": [{"type": "text", "text": "Error: Script content cannot be empty"}], "isError": true}

	# Resolve node
	var node: Node = _resolve_node(path)
	if node == null:
		return {"content": [{"type": "text", "text": "Error: Node not found: %s" % path}], "isError": true}

	# Auto-generate script path if not provided
	if script_path.is_empty():
		var root: Node = _editor_interface.get_edited_scene_root()
		var scene_name: String = _to_snake_case(root.name) if root != null else "unknown"
		var node_name: String = _to_snake_case(node.name)
		script_path = "res://scripts/%s_%s.gd" % [scene_name, node_name]

	# Validate extension
	if not script_path.ends_with(".gd"):
		return {"content": [{"type": "text", "text": "Error: Script path must end with .gd"}], "isError": true}

	# Check file existence
	var file_exists: bool = FileAccess.file_exists(script_path)
	if file_exists and not overwrite:
		return {"content": [{"type": "text", "text": "Error: Script file already exists: %s. Set overwrite=true to replace." % script_path}], "isError": true}

	# Create parent directory if needed
	var parent_dir: String = script_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	# Write script file
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return {"content": [{"type": "text", "text": "Error: Failed to create script file: %s" % script_path}], "isError": true}
	file.store_string(content)
	file.close()

	# Load the script
	var script: Resource = ResourceLoader.load(script_path)
	if script == null:
		return {"content": [{"type": "text", "text": "Error: Failed to load created script: %s" % script_path}], "isError": true}

	# Record previous script
	var previous_script: String = ""
	var old_script: Script = node.get_script()
	if old_script != null:
		previous_script = old_script.resource_path

	# Attach script to node
	node.set("script", script)

	# Update editor filesystem
	var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
	fs.update_file(script_path)

	return MCPToolRegistry.create_response("Created and attached script %s to %s" % [script_path, path], {
		"path": path,
		"script_path": script_path,
		"previous_script": previous_script,
		"created": not file_exists
	})


func _resolve_node(path: String) -> Node:
	if _editor_interface == null:
		return null
	var root: Node = _editor_interface.get_edited_scene_root()
	if root == null:
		return null
	if path.is_empty() or path == "/":
		return root
	if path.begins_with("/"):
		path = path.substr(1)
	return root.get_node_or_null(path)


func _to_snake_case(text: String) -> String:
	var result: String = ""
	for i: int in range(text.length()):
		var c: String = text[i]
		if c == c.to_upper() and c != c.to_lower() and i > 0:
			result += "_"
		result += c.to_lower()
	return result


func _get_script_language(script: Script) -> String:
	if script is GDScript:
		return "GDScript"
	# Add more language checks as needed
	return "Unknown"


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

@tool
## MCP WebSocket Server Plugin
## Simple MCP server plugin for Godot Editor
extends EditorPlugin

const SimpleMCPServerClass = preload("res://addons/mcp_server/simple_mcp_server.gd")

var _mcp_server: SimpleMCPServer
var _port: int = 8765
var _editor_interface: EditorInterface

# Import tool classes
const SceneToolsClass = preload("res://addons/mcp_server/editor/tools/scene_tools.gd")
const NodeToolsClass = preload("res://addons/mcp_server/editor/tools/node_tools.gd")
const FileSystemToolsClass = preload("res://addons/mcp_server/editor/tools/filesystem_tools.gd")
const SelectionToolsClass = preload("res://addons/mcp_server/editor/tools/selection_tools.gd")
const ScriptToolsClass = preload("res://addons/mcp_server/editor/tools/script_tools.gd")
const UndoToolsClass = preload("res://addons/mcp_server/editor/tools/undo_tools.gd")
const EditorCaptureToolsClass = preload("res://addons/mcp_server/editor/tools/capture_tools.gd")
const EditorViewportToolsClass = preload("res://addons/mcp_server/editor/tools/viewport_tools.gd")
const EditorLogToolsClass = preload("res://addons/mcp_server/editor/tools/editor_log_tools.gd")
const EditorRestartToolClass = preload("res://addons/mcp_server/editor/tools/editor_restart_tool.gd")

# Keep references to prevent garbage collection
var _tool_objects: Array[RefCounted] = []


func _enter_tree() -> void:
	_editor_interface = get_editor_interface()
	_mcp_server = SimpleMCPServerClass.new(_port)

	if _mcp_server.start():
		print("[MCP Server] Started on port %d (ws://127.0.0.1:%d)" % [_port, _port])
		_register_tools()
	else:
		push_error("[MCP Server] Failed to start on port %d" % _port)

	# Register RuntimeMCP autoload for game runtime
	add_autoload_singleton("RuntimeMCP", "res://addons/mcp_server/runtime/runtime_mcp_autoload.gd")
	print("[MCP Server] Registered RuntimeMCP autoload singleton")


func _exit_tree() -> void:
	if _mcp_server:
		_mcp_server.stop()
	print("[MCP Server] Stopped")

	# Remove RuntimeMCP autoload
	remove_autoload_singleton("RuntimeMCP")
	print("[MCP Server] Removed RuntimeMCP autoload singleton")


func _process(_delta: float) -> void:
	if _mcp_server:
		_mcp_server.poll()


func _register_tools() -> void:
	var registry = _mcp_server.get_tool_registry()

	# Scene tools
	var scene_tools := SceneToolsClass.new(null, _editor_interface)
	_register_scene_tools(registry, scene_tools)
	_tool_objects.append(scene_tools)

	# Node tools
	var node_tools := NodeToolsClass.new(null, _editor_interface)
	_register_node_tools(registry, node_tools)
	_tool_objects.append(node_tools)

	# FileSystem tools
	var filesystem_tools := FileSystemToolsClass.new(null, _editor_interface)
	_register_filesystem_tools(registry, filesystem_tools)
	_tool_objects.append(filesystem_tools)

	# Selection tools
	var selection_tools := SelectionToolsClass.new(null, _editor_interface)
	_register_selection_tools(registry, selection_tools)
	_tool_objects.append(selection_tools)

	# Script tools
	var script_tools := ScriptToolsClass.new(null, _editor_interface)
	_register_script_tools(registry, script_tools)
	_tool_objects.append(script_tools)

	# Undo tools
	var undo_tools := UndoToolsClass.new(null, _editor_interface)
	_register_undo_tools(registry, undo_tools)
	_tool_objects.append(undo_tools)

	# Capture tools
	var capture_tools := EditorCaptureToolsClass.new(null, _editor_interface)
	_register_capture_tools(registry, capture_tools)
	_tool_objects.append(capture_tools)

	# Viewport tools
	var viewport_tools := EditorViewportToolsClass.new(null, _editor_interface)
	_register_viewport_tools(registry, viewport_tools)
	_tool_objects.append(viewport_tools)

	# Editor log tools
	var editor_log_tools := EditorLogToolsClass.new(null, _editor_interface)
	_register_editor_log_tools(registry, editor_log_tools)
	_tool_objects.append(editor_log_tools)

	# Editor restart tool
	var editor_restart_tool := EditorRestartToolClass.new(null, _editor_interface)
	_register_restart_tool(registry, editor_restart_tool)
	_tool_objects.append(editor_restart_tool)

	print("[MCP Server] Registered %d tools" % registry.size())


# --- Tool Registration Helpers ---
# These methods adapt existing tools to the new registration pattern

func _register_scene_tools(registry, tools: SceneTools) -> void:
	registry.register_tool(
		_create_tool_def("scene_open", "Opens a scene file in the editor", {
			"path": {"type": "string", "description": "Path to the scene file (e.g., 'res://scenes/main.tscn')"},
			"add_to_history": {"type": "boolean", "default": true, "description": "Add to recent scenes history"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_open", args)
	)
	registry.register_tool(
		_create_tool_def("scene_save", "Saves the currently open scene", {
			"path": {"type": "string", "description": "Save to a different path (save as)"}
		}, []),
		func(args): return _run_tool(tools, "_execute_save", args)
	)
	registry.register_tool(
		_create_tool_def("scene_run", "Runs/plays the current scene or a specified scene", {
			"path": {"type": "string", "description": "Scene to run (defaults to current scene)"},
			"arguments": {"type": "array", "items": {"type": "string"}, "default": [], "description": "Command line arguments"}
		}, []),
		func(args): return _run_tool(tools, "_execute_run", args)
	)
	registry.register_tool(
		_create_tool_def("scene_stop", "Stops the currently running scene", {}, []),
		func(args): return _run_tool(tools, "_execute_stop", args)
	)
	registry.register_tool(
		_create_tool_def("scene_get_current", "Gets information about the currently open scene", {}, []),
		func(args): return _run_tool(tools, "_execute_get_current", args)
	)
	registry.register_tool(
		_create_tool_def("scene_get_node_tree", "Returns the complete node hierarchy tree of the current scene", {}, []),
		func(args): return _run_tool(tools, "_execute_get_node_tree", args)
	)


func _register_node_tools(registry, tools: NodeTools) -> void:
	registry.register_tool(
		_create_tool_def("node_get", "Get a node's information from the scene tree", {
			"path": {"type": "string", "description": "Node path to get"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_get", args)
	)
	registry.register_tool(
		_create_tool_def("node_create", "Create a new node in the current scene", {
			"type": {"type": "string", "description": "Godot node class name (e.g., 'Node3D', 'Camera3D')"},
			"name": {"type": "string", "description": "Node name"},
			"parent_path": {"type": "string", "description": "Parent node path (empty for root)"}
		}, ["type"]),
		func(args): return _run_tool(tools, "_execute_create", args)
	)
	registry.register_tool(
		_create_tool_def("node_delete", "Delete a node from the scene", {
			"path": {"type": "string", "description": "Node path to delete"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_delete", args)
	)
	registry.register_tool(
		_create_tool_def("node_duplicate", "Duplicate a node in the scene", {
			"path": {"type": "string", "description": "Node path to duplicate"},
			"parent": {"type": "string", "description": "New parent path (defaults to same parent)"},
			"name": {"type": "string", "description": "Name for the duplicate"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_duplicate", args)
	)
	registry.register_tool(
		_create_tool_def("node_get_property", "Get a property value from a node", {
			"path": {"type": "string", "description": "Node path"},
			"property": {"type": "string", "description": "Property name"}
		}, ["path", "property"]),
		func(args): return _run_tool(tools, "_execute_get_property", args)
	)
	registry.register_tool(
		_create_tool_def("node_set_property", "Set a property value on a node", {
			"path": {"type": "string", "description": "Node path"},
			"property": {"type": "string", "description": "Property name"},
			"value": {"type": "string", "description": "Property value (JSON string for complex types)"}
		}, ["path", "property", "value"]),
		func(args): return _run_tool(tools, "_execute_set_property", args)
	)
	registry.register_tool(
		_create_tool_def("node_list_children", "List children of a node", {
			"path": {"type": "string", "description": "Node path (empty for root)"},
			"recursive": {"type": "boolean", "default": false, "description": "List all descendants recursively"}
		}, []),
		func(args): return _run_tool(tools, "_execute_list_children", args)
	)
	registry.register_tool(
		_create_tool_def("node_pack_as_scene", "Save node branch as reusable .tscn file", {
			"path": {"type": "string", "description": "Node path to pack"},
			"save_path": {"type": "string", "description": "Destination .tscn file path"}
		}, ["path", "save_path"]),
		func(args): return _run_tool(tools, "_execute_pack_as_scene", args)
	)


func _register_filesystem_tools(registry, tools: FileSystemTools) -> void:
	registry.register_tool(
		_create_tool_def("fs_list_dir", "Lists contents of a directory", {
			"path": {"type": "string", "default": "res://", "description": "Directory path"},
			"recursive": {"type": "boolean", "default": false},
			"filter": {"type": "string", "description": "File extension filter (e.g., '*.gd')"}
		}, []),
		func(args): return _run_tool(tools, "_execute_list_dir", args)
	)
	registry.register_tool(
		_create_tool_def("fs_read_file", "Reads a text file's contents", {
			"path": {"type": "string", "description": "File path"},
			"start_line": {"type": "integer", "default": 1},
			"end_line": {"type": "integer", "description": "End line (inclusive)"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_read_file", args)
	)
	registry.register_tool(
		_create_tool_def("fs_write_file", "Writes content to a file", {
			"path": {"type": "string", "description": "File path"},
			"content": {"type": "string", "description": "Content to write"},
			"mode": {"type": "string", "enum": ["write", "append"], "default": "write"}
		}, ["path", "content"]),
		func(args): return _run_tool(tools, "_execute_write_file", args)
	)
	registry.register_tool(
		_create_tool_def("fs_delete", "Deletes a file or directory", {
			"path": {"type": "string", "description": "Path to delete"},
			"recursive": {"type": "boolean", "default": false, "description": "Delete directory contents"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_delete", args)
	)
	registry.register_tool(
		_create_tool_def("fs_copy", "Copies a file", {
			"source": {"type": "string", "description": "Source file path"},
			"destination": {"type": "string", "description": "Destination file path"}
		}, ["source", "destination"]),
		func(args): return _run_tool(tools, "_execute_copy", args)
	)
	registry.register_tool(
		_create_tool_def("fs_move", "Moves/renames a file or directory", {
			"source": {"type": "string", "description": "Source path"},
			"destination": {"type": "string", "description": "Destination path"}
		}, ["source", "destination"]),
		func(args): return _run_tool(tools, "_execute_move", args)
	)


func _register_selection_tools(registry, tools: SelectionTools) -> void:
	registry.register_tool(
		_create_tool_def("selection_get", "Get the currently selected nodes", {}, []),
		func(args): return _run_tool(tools, "_execute_get", args)
	)
	registry.register_tool(
		_create_tool_def("selection_set", "Set the selected nodes", {
			"paths": {"type": "array", "items": {"type": "string"}, "description": "Node paths to select"}
		}, ["paths"]),
		func(args): return _run_tool(tools, "_execute_set", args)
	)
	registry.register_tool(
		_create_tool_def("selection_clear", "Clear the selection", {}, []),
		func(args): return _run_tool(tools, "_execute_clear", args)
	)


func _register_script_tools(registry, tools: ScriptTools) -> void:
	registry.register_tool(
		_create_tool_def("script_open", "Opens a script in the script editor", {
			"path": {"type": "string", "description": "Script file path"},
			"line": {"type": "integer", "default": 1, "description": "Line to scroll to"},
			"column": {"type": "integer", "default": 0, "description": "Column position"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_open", args)
	)
	registry.register_tool(
		_create_tool_def("script_get_current", "Gets the currently edited script", {}, []),
		func(args): return _run_tool(tools, "_execute_get_current", args)
	)


func _register_undo_tools(registry, tools: UndoTools) -> void:
	registry.register_tool(
		_create_tool_def("editor_undo", "Undo the last action", {}, []),
		func(args): return _run_tool(tools, "_execute_undo", args)
	)
	registry.register_tool(
		_create_tool_def("editor_redo", "Redo the last undone action", {}, []),
		func(args): return _run_tool(tools, "_execute_redo", args)
	)


func _register_capture_tools(registry, tools) -> void:
	registry.register_tool(
		_create_tool_def("screenshot_capture_editor", "Captures a screenshot of the Godot editor viewport (3D or 2D) and saves it to disk", {
			"filename": {"type": "string", "description": "Custom filename (without extension)"},
			"format": {"type": "string", "enum": ["png", "jpg"], "default": "png", "description": "Image format"},
			"quality": {"type": "integer", "minimum": 1, "maximum": 100, "default": 90, "description": "JPG quality (1-100)"}
		}, []),
		func(args): return _run_tool(tools, "_execute_capture_editor", args)
	)
	registry.register_tool(
		_create_tool_def("screenshot_list", "Lists all captured screenshots in the MCP screenshots directory with metadata", {}, []),
		func(args): return _run_tool(tools, "_execute_list", args)
	)


func _register_viewport_tools(registry, tools) -> void:
	registry.register_tool(
		_create_tool_def("viewport_focus_on_node", "Focus the editor viewport camera on a specific scene node, centering it in the view", {
			"path": {"type": "string", "description": "Node path to focus on (e.g., 'Main/Player' or '/root/Main/Player')"}
		}, ["path"]),
		func(args): return _run_tool(tools, "_execute_focus", args)
	)
	registry.register_tool(
		_create_tool_def("viewport_set_camera", "Position the editor viewport camera at a specific location and set its look-at target", {
			"position": {"type": "object", "description": "Camera position in world coordinates", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}},
			"look_at": {"type": "object", "description": "Point the camera should look at", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}}
		}, ["position", "look_at"]),
		func(args): return _run_tool(tools, "_execute_set_camera", args)
	)
	registry.register_tool(
		_create_tool_def("viewport_orbit", "Orbit the camera around the current focus point by specified rotation angles", {
			"delta_rotation": {"type": "object", "description": "Rotation deltas in degrees", "properties": {"x": {"type": "number", "default": 0, "description": "Pitch rotation"}, "y": {"type": "number", "default": 0, "description": "Yaw rotation"}, "z": {"type": "number", "default": 0, "description": "Roll rotation"}}}
		}, ["delta_rotation"]),
		func(args): return _run_tool(tools, "_execute_orbit", args)
	)
	registry.register_tool(
		_create_tool_def("viewport_zoom", "Zoom the camera in or out relative to the current focus point", {
			"factor": {"type": "number", "description": "Zoom factor relative to current distance", "minimum": 0.01, "maximum": 100.0}
		}, ["factor"]),
		func(args): return _run_tool(tools, "_execute_zoom", args)
	)


func _register_editor_log_tools(registry, tools) -> void:
	registry.register_tool(
		_create_tool_def("editor_get_output_log", "Get the editor output panel log content", {}, []),
		func(args): return _run_tool(tools, "_execute_get_output_log", args)
	)


func _register_restart_tool(registry, tools) -> void:
	registry.register_tool(
		_create_tool_def("editor_restart", "Restart the Godot editor", {}, []),
		func(args): return _run_tool(tools, "_execute_restart", args)
	)


# --- Helper Functions ---

func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}


func _run_tool(tool_obj, method_name: String, args: Dictionary) -> Dictionary:
	var result = tool_obj.call(method_name, args)
	if result is MCPToolResult:
		return result.to_response_dict()
	return result

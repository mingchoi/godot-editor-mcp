@tool
## MCP WebSocket Server Plugin
## Simple MCP server plugin for Godot Editor
extends EditorPlugin

const MCPServerClass = preload("res://addons/mcp_server/mcp_server.gd")

# Import tool classes - each has a static register() function
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
const WarningCheckerToolsClass = preload("res://addons/mcp_server/editor/tools/warning_checker_tools.gd")

var _mcp_server: MCPServer
var _port: int = 8765
var _editor_interface: EditorInterface

# Keep references to tool objects to prevent garbage collection
var _tool_objects: Array[RefCounted] = []


func _enter_tree() -> void:
	_editor_interface = get_editor_interface()
	_mcp_server = MCPServerClass.new(_port)

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

	# Register all tool categories using static register() functions
	# Store returned instances to prevent garbage collection
	_tool_objects.append(SceneToolsClass.register(registry, _editor_interface))
	_tool_objects.append(NodeToolsClass.register(registry, _editor_interface))
	_tool_objects.append(FileSystemToolsClass.register(registry, _editor_interface))
	_tool_objects.append(SelectionToolsClass.register(registry, _editor_interface))
	_tool_objects.append(ScriptToolsClass.register(registry, _editor_interface))
	_tool_objects.append(UndoToolsClass.register(registry, _editor_interface))
	_tool_objects.append(EditorCaptureToolsClass.register(registry, _editor_interface))
	_tool_objects.append(EditorViewportToolsClass.register(registry, _editor_interface))
	_tool_objects.append(EditorLogToolsClass.register(registry, _editor_interface))
	_tool_objects.append(EditorRestartToolClass.register(registry, _editor_interface))
	_tool_objects.append(WarningCheckerToolsClass.register(registry, _editor_interface))

	print("[MCP Server] Registered %d tools" % registry.size())

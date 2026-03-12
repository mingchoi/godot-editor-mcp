## Editor Tool Registry
## Registers and manages all editor-related MCP tools.
extends RefCounted
class_name EditorToolRegistry

var _registry: ToolRegistry
var _logger: MCPLogger
var _editor_interface: EditorInterface


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_registry = ToolRegistry.new()
	_logger = logger.child("EditorRegistry") if logger else MCPLogger.new("[EditorRegistry]")
	_editor_interface = editor_interface


## Gets the underlying tool registry
func get_registry() -> ToolRegistry:
	return _registry


## Registers all editor tools
func register_all() -> void:
	_register_scene_tools()
	_register_node_tools()
	_register_filesystem_tools()
	_register_selection_tools()
	_register_script_tools()
	_register_undo_tools()

	_logger.info("All editor tools registered", {"count": _registry.size()})


func _register_scene_tools() -> void:
	var tools := SceneTools.new(_logger, _editor_interface)
	tools.register_all(_registry)


func _register_node_tools() -> void:
	var tools := NodeTools.new(_logger, _editor_interface)
	tools.register_all(_registry)


func _register_filesystem_tools() -> void:
	var tools := FileSystemTools.new(_logger, _editor_interface)
	tools.register_all(_registry)


func _register_selection_tools() -> void:
	var tools := SelectionTools.new(_logger, _editor_interface)
	tools.register_all(_registry)


func _register_script_tools() -> void:
	var tools := ScriptTools.new(_logger, _editor_interface)
	tools.register_all(_registry)


func _register_undo_tools() -> void:
	var tools := UndoTools.new(_logger, _editor_interface)
	tools.register_all(_registry)

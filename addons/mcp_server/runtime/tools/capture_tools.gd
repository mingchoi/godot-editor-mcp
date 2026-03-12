## Viewport Capture Tools
## MCP tools for capturing game viewport screenshots.
extends RefCounted
class_name CaptureTools

var _logger: MCPLogger
var _editor_interface: EditorInterface


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("CaptureTools") if logger else MCPLogger.new("[CaptureTools]")
	_editor_interface = editor_interface


## Registers all capture tools
func register_all(_registry: ToolRegistry) -> void:
	pass

## Undo/Redo Tools
## MCP tools for editor undo/redo operations.
extends RefCounted
class_name UndoTools

const TOOL_UNDO := "editor_undo"
const TOOL_REDO := "editor_redo"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("UndoTools") if logger else MCPLogger.new("[UndoTools]")
	_editor_interface = editor_interface


## Registers all undo tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_undo_tool())
	registry.register(_create_redo_tool())


func _create_undo_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_UNDO,
			"Undoes the last action",
			{
				"steps": {"type": "integer", "default": 1, "minimum": 1, "description": "Number of steps to undo"}
			},
			[]
		)
	return MCPToolHandler.new(definition, _execute_undo)


func _create_redo_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_REDO,
			"Redoes the last undone action",
			{
				"steps": {"type": "integer", "default": 1, "minimum": 1, "description": "Number of steps to redo"}
			},
			[]
		)
	return MCPToolHandler.new(definition, _execute_redo)


# --- Tool Implementations ---

func _execute_undo(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)
	var steps: int = params.get("steps", 1)
	steps = maxi(1, steps)  # Ensure at least 1

	var undo_redo: EditorUndoRedoManager = _editor_interface.get_undo_redo()
	if undo_redo == null:
		return MCPToolResult.error("Undo/Redo manager not available", MCPError.Code.TOOL_EXECUTION_ERROR)

	var actual_steps: int = 0
	for i: int in range(steps):
		if not undo_redo.has_undo():
			break
		undo_redo.undo()
		actual_steps += 1

	_logger.info("Undo performed", {"requested": steps, "actual": actual_steps})
	return MCPToolResult.text("Undid %d action(s)" % actual_steps, {
		"steps": actual_steps,
		"has_more": undo_redo.has_undo()
	})


func _execute_redo(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)
	var steps: int = params.get("steps", 1)
	steps = maxi(1, steps)  # Ensure at least 1

	var undo_redo: EditorUndoRedoManager = _editor_interface.get_undo_redo()
	if undo_redo == null:
		return MCPToolResult.error("Undo/Redo manager not available", MCPError.Code.TOOL_EXECUTION_ERROR)

	var actual_steps: int = 0
	for i: int in range(steps):
		if not undo_redo.has_redo():
			break
		undo_redo.redo()
		actual_steps += 1

	_logger.info("Redo performed", {"requested": steps, "actual": actual_steps})
	return MCPToolResult.text("Redid %d action(s)" % actual_steps, {
		"steps": actual_steps,
		"has_more": undo_redo.has_redo()
	})

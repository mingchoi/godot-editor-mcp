## Undo/Redo Tools
## MCP tools for editor undo/redo operations.
extends RefCounted
class_name UndoTools

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all undo tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := UndoTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("editor_undo", "Undoes the last action", {
			"steps": {"type": "integer", "default": 1, "minimum": 1, "description": "Number of steps to undo"}
		}, [], {
			"type": "object",
			"properties": {
				"steps": {"type": "integer", "description": "Number of actions undone"},
				"has_more": {"type": "boolean", "description": "Whether more undo actions are available"}
			}
		}),
		tools._execute_undo
	)

	registry.register_tool(
		_create_tool_def("editor_redo", "Redoes the last undone action", {
			"steps": {"type": "integer", "default": 1, "minimum": 1, "description": "Number of steps to redo"}
		}, [], {
			"type": "object",
			"properties": {
				"steps": {"type": "integer", "description": "Number of actions redone"},
				"has_more": {"type": "boolean", "description": "Whether more redo actions are available"}
			}
		}),
		tools._execute_redo
	)

	return tools


# --- Tool Implementations ---

func _execute_undo(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var steps: int = args.get("steps", 1)
	steps = maxi(1, steps)  # Ensure at least 1

	var undo_redo: EditorUndoRedoManager = _editor_interface.get_undo_redo()
	if undo_redo == null:
		return {"content": [{"type": "text", "text": "Error: Undo/Redo manager not available"}], "isError": true}

	var actual_steps: int = 0
	for i: int in range(steps):
		if not undo_redo.has_undo():
			break
		undo_redo.undo()
		actual_steps += 1

	return MCPToolRegistry.create_response("Undid %d action(s)" % actual_steps, {
		"steps": actual_steps,
		"has_more": undo_redo.has_undo()
	})


func _execute_redo(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var steps: int = args.get("steps", 1)
	steps = maxi(1, steps)  # Ensure at least 1

	var undo_redo: EditorUndoRedoManager = _editor_interface.get_undo_redo()
	if undo_redo == null:
		return {"content": [{"type": "text", "text": "Error: Undo/Redo manager not available"}], "isError": true}

	var actual_steps: int = 0
	for i: int in range(steps):
		if not undo_redo.has_redo():
			break
		undo_redo.redo()
		actual_steps += 1

	return MCPToolRegistry.create_response("Redid %d action(s)" % actual_steps, {
		"steps": actual_steps,
		"has_more": undo_redo.has_redo()
	})


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

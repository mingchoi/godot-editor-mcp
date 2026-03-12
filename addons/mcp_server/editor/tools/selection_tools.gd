## Selection Tools
## MCP tools for editor selection management.
extends RefCounted
class_name SelectionTools

const TOOL_GET := "selection_get"
const TOOL_SET := "selection_set"
const TOOL_CLEAR := "selection_clear"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("SelectionTools") if logger else MCPLogger.new("[SelectionTools]")
	_editor_interface = editor_interface


## Registers all selection tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_get_tool())
	registry.register(_create_set_tool())
	registry.register(_create_clear_tool())


func _create_get_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_GET,
			"Gets currently selected nodes in the editor",
			{},
			[]
		)
	return MCPToolHandler.new(definition, _execute_get)


func _create_set_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_SET,
			"Sets the editor selection",
			{
				"paths": {
					"type": "array",
					"items": {"type": "string"},
					"description": "Node paths to select"
				},
				"additive": {
					"type": "boolean",
					"default": false,
					"description": "Add to current selection"
				}
			},
			["paths"]
		)
	return MCPToolHandler.new(definition, _execute_set)


func _create_clear_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_CLEAR,
			"Clears the editor selection",
			{},
			[]
		)
	return MCPToolHandler.new(definition, _execute_clear)


# --- Tool Implementations ---

func _get_selection() -> EditorSelection:
	return _editor_interface.get_selection()


func _execute_get(_params: Dictionary = {}) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)
	var selection: EditorSelection = _get_selection()
	if selection == null:
		return MCPToolResult.text("No selection available", {"count": 0, "nodes": []})

	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	var nodes_info: Array[Dictionary] = []

	for node: Node in selected_nodes:
		nodes_info.append({
			"path": str(node.get_path()),
			"name": node.name,
			"type": node.get_class()
		})

	return MCPToolResult.text(
		"%d node(s) selected" % nodes_info.size(),
		{
			"count": nodes_info.size(),
			"nodes": nodes_info
		}
	)


func _execute_set(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)
	var paths: Array = params.get("paths", [])
	var additive: bool = params.get("additive", false)

	var selection: EditorSelection = _get_selection()
	if selection == null:
		return MCPToolResult.error("Selection not available", MCPError.Code.TOOL_EXECUTION_ERROR)

	# Clear current selection if not additive
	if not additive:
		selection.clear()

	var root: Node = _editor_interface.get_edited_scene_root()
	if root == null:
		return MCPToolResult.error("No scene is open", MCPError.Code.NOT_FOUND)

	var selected_count: int = 0
	var errors: Array[String] = []

	for path: Variant in paths:
		if not path is String:
			errors.append("Invalid path type: expected string")
			continue

		var node: Node = root.get_node_or_null(path)
		if node == null:
			errors.append("Node not found: %s" % path)
			continue

		selection.add_node(node)
		selected_count += 1

	var data: Dictionary = {
		"count": selected_count,
		"requested": paths.size()
	}

	if not errors.is_empty():
		data["errors"] = errors

	_logger.info("Selection set", {"count": selected_count, "additive": additive})
	return MCPToolResult.text("Selected %d node(s)" % selected_count, data)


func _execute_clear(_params: Dictionary = {}) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)
	var selection: EditorSelection = _get_selection()
	if selection == null:
		return MCPToolResult.text("No selection to clear")

	var count: int = selection.get_selected_nodes().size()
	selection.clear()

	_logger.info("Selection cleared", {"previous_count": count})
	return MCPToolResult.text("Cleared selection (%d nodes)" % count, {"cleared_count": count})

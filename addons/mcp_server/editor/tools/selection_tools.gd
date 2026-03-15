## Selection Tools
## MCP tools for editor selection management.
extends RefCounted
class_name SelectionTools

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all selection tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := SelectionTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("selection_get", "Gets currently selected nodes in the editor", {}, []),
		tools._execute_get
	)

	registry.register_tool(
		_create_tool_def("selection_set", "Sets the editor selection", {
			"paths": {"type": "array", "items": {"type": "string"}, "description": "Node paths to select"},
			"additive": {"type": "boolean", "default": false, "description": "Add to current selection"}
		}, ["paths"]),
		tools._execute_set
	)

	registry.register_tool(
		_create_tool_def("selection_clear", "Clears the editor selection", {}, []),
		tools._execute_clear
	)

	return tools


# --- Tool Implementations ---

func _get_selection() -> EditorSelection:
	return _editor_interface.get_selection()


func _execute_get(_args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var selection: EditorSelection = _get_selection()
	if selection == null:
		return {
			"content": [{"type": "text", "text": "No selection available"}],
			"isError": false,
			"data": {"count": 0, "nodes": []}
		}

	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	var nodes_info: Array[Dictionary] = []

	for node: Node in selected_nodes:
		nodes_info.append({
			"path": str(node.get_path()),
			"name": node.name,
			"type": node.get_class()
		})

	return {
		"content": [{"type": "text", "text": "%d node(s) selected" % nodes_info.size()}],
		"isError": false,
		"data": {"count": nodes_info.size(), "nodes": nodes_info}
	}


func _execute_set(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var paths: Array = args.get("paths", [])
	var additive: bool = args.get("additive", false)

	var selection: EditorSelection = _get_selection()
	if selection == null:
		return {"content": [{"type": "text", "text": "Error: Selection not available"}], "isError": true}

	# Clear current selection if not additive
	if not additive:
		selection.clear()

	var root: Node = _editor_interface.get_edited_scene_root()
	if root == null:
		return {"content": [{"type": "text", "text": "Error: No scene is open"}], "isError": true}

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

	var data: Dictionary = {"count": selected_count, "requested": paths.size()}

	if not errors.is_empty():
		data["errors"] = errors

	return {
		"content": [{"type": "text", "text": "Selected %d node(s)" % selected_count}],
		"isError": false,
		"data": data
	}


func _execute_clear(_args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	var selection: EditorSelection = _get_selection()
	if selection == null:
		return {"content": [{"type": "text", "text": "No selection to clear"}], "isError": false}

	var count: int = selection.get_selected_nodes().size()
	selection.clear()

	return {
		"content": [{"type": "text", "text": "Cleared selection (%d nodes)" % count}],
		"isError": false,
		"data": {"cleared_count": count}
	}


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}

## Editor Log Tools
##
## MCP tools for retrieving editor output panel content.
##
## Tools:
## - editor_get_output_log: Retrieves the current content of the Godot editor's
##   output panel log. Returns the full text content along with metadata including
##   character count and is_empty flag.
##
## Node Traversal:
## The tool navigates the editor's internal node hierarchy to access the output panel:
## @EditorBottomPanel → Output → HBoxContainer → VBoxContainer → RichTextLabel
##
## Error Handling:
## - Returns error if EditorInterface is not available
## - Returns error if output panel or RichTextLabel cannot be found
## - Returns empty result (not error) if output panel has no content
extends RefCounted
class_name EditorLogTools

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all editor log tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := EditorLogTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("editor_get_output_log", "Retrieves the current content of the Godot editor's output panel log. Returns the full text content along with metadata including character count.", {}, []),
		tools._execute_get_output_log
	)

	return tools


# --- Tool Implementations ---

func _execute_get_output_log(_args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	# Navigate to output panel RichTextLabel
	var rich_text_label := _find_output_rich_text_label()
	if rich_text_label == null:
		return {"content": [{"type": "text", "text": "Error: Log output control not accessible"}], "isError": true}

	# Get the log text
	var log_text := rich_text_label.get_parsed_text()
	var char_count := log_text.length()

	if char_count == 0:
		return {
			"content": [{"type": "text", "text": "Editor output panel is empty"}],
			"isError": false,
			"data": {"content": "", "character_count": 0, "is_empty": true}
		}

	return {
		"content": [{"type": "text", "text": log_text}],
		"isError": false,
		"data": {"character_count": char_count, "is_empty": false}
	}


# --- Helper Functions ---

func _find_output_rich_text_label() -> RichTextLabel:
	var base_control := _editor_interface.get_base_control()
	if base_control == null:
		return null

	# Navigate: @EditorBottomPanel → Output → HBoxContainer → VBoxContainer → RichTextLabel
	var bottom_panel := _find_node_by_name(base_control, "@EditorBottomPanel")
	if bottom_panel == null:
		return null

	var output_node := _find_child_by_name(bottom_panel, "Output")
	if output_node == null:
		return null

	var hbox := _find_child_by_class(output_node, "HBoxContainer")
	if hbox == null:
		return null

	var vbox := _find_child_by_class(hbox, "VBoxContainer")
	if vbox == null:
		return null

	var rich_text_label := _find_child_by_class(vbox, "RichTextLabel")
	if rich_text_label == null:
		return null

	return rich_text_label as RichTextLabel


func _find_child_by_name(parent: Node, target_name: String) -> Node:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child.name == target_name or str(child).contains(target_name):
			return child
	return null


func _find_child_by_class(parent: Node, target_class: String) -> Node:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child.get_class() == target_class:
			return child
	return null


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name or str(root).contains(target_name):
		return root
	for child: Node in root.get_children():
		var result := _find_node_by_name(child, target_name)
		if result != null:
			return result
	return null


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}

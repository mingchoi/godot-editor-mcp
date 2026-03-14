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

const TOOL_GET_OUTPUT_LOG := "editor_get_output_log"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("EditorLogTools") if logger else MCPLogger.new("[EditorLogTools]")
	_editor_interface = editor_interface


## Registers all editor log tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_get_output_log_tool())


func _create_get_output_log_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_GET_OUTPUT_LOG,
		"Retrieves the current content of the Godot editor's output panel log. Returns the full text content along with metadata including character count.",
		{},
		[]
	)
	return MCPToolHandler.new(definition, _execute_get_output_log)


# --- Tool Implementations ---

func _execute_get_output_log(_params: Dictionary = {}) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	# Navigate to output panel RichTextLabel
	var rich_text_label := _find_output_rich_text_label()
	if rich_text_label == null:
		return MCPToolResult.error("Log output control not accessible", MCPError.Code.TOOL_EXECUTION_ERROR)

	# Get the log text
	var log_text := rich_text_label.get_parsed_text()
	var char_count := log_text.length()

	if char_count == 0:
		_logger.debug("Output panel is empty")
		return MCPToolResult.text("Editor output panel is empty", {
			"content": "",
			"character_count": 0,
			"is_empty": true
		})

	_logger.info("Retrieved editor output log", {"character_count": char_count})
	return MCPToolResult.text(log_text, {
		"character_count": char_count,
		"is_empty": false
	})


# --- Helper Functions ---

func _find_output_rich_text_label() -> RichTextLabel:
	var base_control := _editor_interface.get_base_control()
	if base_control == null:
		_logger.warning("Editor base control not available")
		return null

	# Navigate: @EditorBottomPanel → Output → HBoxContainer → VBoxContainer → RichTextLabel
	var bottom_panel := _find_node_by_name(base_control, "@EditorBottomPanel")
	if bottom_panel == null:
		_logger.warning("Could not find @EditorBottomPanel")
		return null

	var output_node := _find_child_by_name(bottom_panel, "Output")
	if output_node == null:
		_logger.warning("Could not find Output node")
		return null

	var hbox := _find_child_by_class(output_node, "HBoxContainer")
	if hbox == null:
		_logger.warning("Could not find HBoxContainer in Output")
		return null

	var vbox := _find_child_by_class(hbox, "VBoxContainer")
	if vbox == null:
		_logger.warning("Could not find VBoxContainer in Output")
		return null

	var rich_text_label := _find_child_by_class(vbox, "RichTextLabel")
	if rich_text_label == null:
		_logger.warning("Could not find RichTextLabel in Output")
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

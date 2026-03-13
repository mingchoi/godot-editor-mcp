## Scene Management Tools
## MCP tools for scene management operations.
extends RefCounted
class_name SceneTools

const TOOL_OPEN := "scene_open"
const TOOL_SAVE := "scene_save"
const TOOL_RUN := "scene_run"
const TOOL_STOP := "scene_stop"
const TOOL_GET_CURRENT := "scene_get_current"
const TOOL_GET_NODE_TREE := "scene_get_node_tree"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("SceneTools") if logger else MCPLogger.new("[SceneTools]")
	_editor_interface = editor_interface


## Registers all scene tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_open_tool())
	registry.register(_create_save_tool())
	registry.register(_create_run_tool())
	registry.register(_create_stop_tool())
	registry.register(_create_get_current_tool())
	registry.register(_create_get_node_tree_tool())


func _create_open_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_OPEN,
			"Opens a scene file in the editor",
			{
				"path": {
					"type": "string",
					"description": "Path to the scene file (e.g., 'res://scenes/main.tscn')"
				},
				"add_to_history": {
					"type": "boolean",
					"default": true,
					"description": "Add to recent scenes history"
				}
			},
			["path"]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_open(params)
	)


func _create_save_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_SAVE,
			"Saves the currently open scene",
			{
				"path": {
					"type": "string",
					"description": "Save to a different path (save as)"
				}
			},
			[]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_save(params)
	)


func _create_run_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_RUN,
			"Runs/plays the current scene or a specified scene",
			{
				"path": {
					"type": "string",
					"description": "Scene to run (defaults to current scene)"
				},
				"arguments": {
					"type": "array",
					"items": {"type": "string"},
					"default": [],
					"description": "Command line arguments to pass"
				}
			},
			[]
		),
		func(params: Dictionary) -> MCPToolResult: return _execute_run(params)
	)


func _create_stop_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_STOP,
			"Stops the currently running scene",
			{},
			[]
		),
		func(_params: Dictionary) -> MCPToolResult: return _execute_stop()
	)


func _create_get_current_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_GET_CURRENT,
			"Gets information about the currently open scene",
			{},
			[]
		),
		func(_params: Dictionary) -> MCPToolResult: return _execute_get_current()
	)


func _create_get_node_tree_tool() -> MCPToolHandler:
	return MCPToolHandler.new(
		MCPToolDefinition.create(
			TOOL_GET_NODE_TREE,
			"Returns the complete node hierarchy tree of the current scene",
			{},
			[]
		),
		func(_params: Dictionary) -> MCPToolResult: return _execute_get_node_tree()
	)


# --- Tool Implementations ---

func _execute_open(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")

	# Validate path
	if not path.begins_with("res://"):
		return MCPToolResult.error("Invalid path: must start with res://")

	if not FileAccess.file_exists(path):
		return MCPToolResult.error("Scene file not found: %s" % path, MCPError.Code.NOT_FOUND)

	# Check file extension
	if not path.ends_with(".tscn") and not path.ends_with(".scn"):
		return MCPToolResult.error("Invalid scene file: must be .tscn or .scn", MCPError.Code.INVALID_PARAMS)

	# Open the scene
	_editor_interface.open_scene_from_path(path)

	# Get scene info
	var root: Node = _editor_interface.get_edited_scene_root()
	var node_count: int = _count_nodes(root) if root != null else 0
	var root_name: String = root.name if root != null else ""

	var data: Dictionary = {
		"path": path,
		"root_node": root_name,
		"node_count": node_count
	}

	_logger.info("Scene opened", data)
	return MCPToolResult.text("Opened scene: %s" % path, data)


func _execute_save(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var save_path: String = params.get("path", "")

	# Check if there's a scene to save
	var root: Node = _editor_interface.get_edited_scene_root()
	if root == null:
		return MCPToolResult.error("No scene is currently open", MCPError.Code.NOT_FOUND)

	if save_path.is_empty():
		# Save current scene
		_editor_interface.save_scene()
		save_path = root.scene_file_path
	else:
		# Save as
		_editor_interface.save_scene_as(save_path)

	var data: Dictionary = {
		"path": save_path,
		"saved_at": Time.get_datetime_string_from_system(true)
	}

	_logger.info("Scene saved", data)
	return MCPToolResult.text("Scene saved successfully", data)


func _execute_run(params: Dictionary) -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var path: String = params.get("path", "")

	# Check if already playing
	if _editor_interface.is_playing_scene():
		return MCPToolResult.error("A scene is already running. Stop it first.", MCPError.Code.TOOL_EXECUTION_ERROR)

	if path.is_empty():
		# Run current scene
		var root: Node = _editor_interface.get_edited_scene_root()
		if root == null:
			return MCPToolResult.error("No scene is currently open to run", MCPError.Code.NOT_FOUND)

		_editor_interface.play_main_scene()
		path = root.scene_file_path
	else:
		# Run specific scene
		if not FileAccess.file_exists(path):
			return MCPToolResult.error("Scene file not found: %s" % path, MCPError.Code.NOT_FOUND)

		_editor_interface.play_custom_scene(path)

	_logger.info("Scene running", {"path": path})
	return MCPToolResult.text("Running scene: %s" % path, {"path": path})


func _execute_stop() -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	if not _editor_interface.is_playing_scene():
		return MCPToolResult.text("No scene is currently running")

	_editor_interface.stop_playing_scene()

	_logger.info("Scene stopped")
	return MCPToolResult.text("Scene stopped")


func _execute_get_current() -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var root: Node = _editor_interface.get_edited_scene_root()

	if root == null:
		return MCPToolResult.text("No scene is currently open", {
			"path": "",
			"root_name": "",
			"root_type": "",
			"node_count": 0,
			"modified": false,
			"is_running": _editor_interface.is_playing_scene()
		})

	var node_count: int = _count_nodes(root)
	var path: String = root.scene_file_path
	var root_type: String = root.get_class()

	# Check if modified (we can't directly check this, but we can approximate)
	var modified: bool = root.is_inside_tree()

	var data: Dictionary = {
		"path": path,
		"root_name": root.name,
		"root_type": root_type,
		"node_count": node_count,
		"modified": modified,
		"is_running": _editor_interface.is_playing_scene()
	}

	var text: String = "Current scene: %s (%s)" % [root.name, path if not path.is_empty() else "unsaved"]
	return MCPToolResult.text(text, data)


func _count_nodes(node: Node) -> int:
	if node == null:
		return 0

	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)

	return count


func _execute_get_node_tree() -> MCPToolResult:
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	var root: Node = _editor_interface.get_edited_scene_root()

	if root == null:
		return MCPToolResult.text("No scene is currently open", {
			"root": null,
			"path": ""
		})

	var tree: Dictionary = _build_node_tree(root)
	var path: String = root.scene_file_path

	var data: Dictionary = {
		"root": tree,
		"path": path
	}

	# Format tree as readable text
	var tree_text: String = _format_tree_text(tree, "")
	var text: String = "Scene tree for: %s\n%s" % [root.name, tree_text]

	_logger.info("Scene tree retrieved", {"path": path, "root_name": root.name})
	return MCPToolResult.text(text, data)


func _build_node_tree(node: Node) -> Dictionary:
	var result: Dictionary = {
		"name": node.name,
		"type": node.get_class()
	}

	var children: Array = []
	for child: Node in node.get_children():
		children.append(_build_node_tree(child))

	if not children.is_empty():
		result["children"] = children

	return result


func _format_tree_text(node: Dictionary, indent: String) -> String:
	var line: String = "%s├── %s (%s)\n" % [indent, node.name, node.type]
	var child_indent: String = indent + "│   "

	if node.has("children"):
		for child: Dictionary in node.children:
			line += _format_tree_text(child, child_indent)

	return line

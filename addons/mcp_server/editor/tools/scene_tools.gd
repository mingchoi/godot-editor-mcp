## Scene Management Tools
## MCP tools for scene management operations.
extends RefCounted
class_name SceneTools

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all scene tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := SceneTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("scene_open", "Opens a scene file in the editor", {
			"path": {"type": "string", "description": "Path to the scene file (e.g., 'res://scenes/main.tscn')"},
			"add_to_history": {"type": "boolean", "default": true, "description": "Add to recent scenes history"}
		}, ["path"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Scene file path that was opened"},
				"root_node": {"type": "string", "description": "Name of the root node"},
				"node_count": {"type": "integer", "description": "Total number of nodes in the scene"}
			}
		}),
		tools._execute_open
	)

	registry.register_tool(
		_create_tool_def("scene_save", "Saves the currently open scene", {
			"path": {"type": "string", "description": "Save to a different path (save as)"}
		}, [], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Path where scene was saved"},
				"saved_at": {"type": "string", "description": "ISO 8601 timestamp of save"}
			}
		}),
		tools._execute_save
	)

	registry.register_tool(
		_create_tool_def("scene_run", "Runs/plays the current scene or a specified scene", {
			"path": {"type": "string", "description": "Scene to run (defaults to current scene)"},
			"arguments": {"type": "array", "items": {"type": "string"}, "default": [], "description": "Command line arguments"}
		}, [], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Scene file path that is running"}
			}
		}),
		tools._execute_run
	)

	registry.register_tool(
		_create_tool_def("scene_stop", "Stops the currently running scene", {}, []),
		tools._execute_stop
	)

	registry.register_tool(
		_create_tool_def("scene_get_current", "Gets information about the currently open scene", {}, [], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Scene file path (empty if unsaved)"},
				"root_name": {"type": "string", "description": "Name of the root node"},
				"root_type": {"type": "string", "description": "Godot class of the root node"},
				"node_count": {"type": "integer", "description": "Total number of nodes in the scene"},
				"modified": {"type": "boolean", "description": "Whether the scene has unsaved changes"},
				"is_running": {"type": "boolean", "description": "Whether the scene is currently running"}
			}
		}),
		tools._execute_get_current
	)

	registry.register_tool(
		_create_tool_def("scene_get_node_tree", "Returns the complete node hierarchy tree of the current scene", {}, [], {
			"type": "object",
			"properties": {
				"root": {"type": "object", "description": "Root node with nested children hierarchy"},
				"path": {"type": "string", "description": "Scene file path"}
			}
		}),
		tools._execute_get_node_tree
	)

	return tools


# --- Tool Implementations ---

func _execute_open(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")

	# Validate path
	if not path.begins_with("res://"):
		return {"content": [{"type": "text", "text": "Error: Invalid path: must start with res://"}], "isError": true}

	if not FileAccess.file_exists(path):
		return {"content": [{"type": "text", "text": "Error: Scene file not found: %s" % path}], "isError": true}

	# Check file extension
	if not path.ends_with(".tscn") and not path.ends_with(".scn"):
		return {"content": [{"type": "text", "text": "Error: Invalid scene file: must be .tscn or .scn"}], "isError": true}

	# Open the scene
	_editor_interface.open_scene_from_path(path)

	# Get scene info
	var root: Node = _editor_interface.get_edited_scene_root()
	var node_count: int = _count_nodes(root) if root != null else 0
	var root_name: String = root.name if root != null else ""

	return MCPToolRegistry.create_response("Opened scene: %s" % path, {
		"path": path,
		"root_node": root_name,
		"node_count": node_count
	})


func _execute_save(args: Dictionary) -> Dictionary:
	var save_path: String = args.get("path", "")

	# Check if there's a scene to save
	var root: Node = _editor_interface.get_edited_scene_root()
	if root == null:
		return {"content": [{"type": "text", "text": "Error: No scene is currently open"}], "isError": true}

	if save_path.is_empty():
		# Save current scene
		_editor_interface.save_scene()
		save_path = root.scene_file_path
	else:
		# Save as
		_editor_interface.save_scene_as(save_path)

	return MCPToolRegistry.create_response("Scene saved successfully", {
		"path": save_path,
		"saved_at": Time.get_datetime_string_from_system(true)
	})


func _execute_run(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")

	# Check if already playing
	if _editor_interface.is_playing_scene():
		return {"content": [{"type": "text", "text": "Error: A scene is already running. Stop it first."}], "isError": true}

	if path.is_empty():
		# Run current scene
		var root: Node = _editor_interface.get_edited_scene_root()
		if root == null:
			return {"content": [{"type": "text", "text": "Error: No scene is currently open to run"}], "isError": true}

		_editor_interface.play_main_scene()
		path = root.scene_file_path
	else:
		# Run specific scene
		if not FileAccess.file_exists(path):
			return {"content": [{"type": "text", "text": "Error: Scene file not found: %s" % path}], "isError": true}

		_editor_interface.play_custom_scene(path)

	return MCPToolRegistry.create_response("Running scene: %s" % path, {
		"path": path
	})


func _execute_stop(_args: Dictionary) -> Dictionary:
	if not _editor_interface.is_playing_scene():
		return {"content": [{"type": "text", "text": "No scene is currently running"}], "isError": false}

	_editor_interface.stop_playing_scene()

	return {
		"content": [{"type": "text", "text": "Scene stopped"}]
	}


func _execute_get_current(_args: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()

	if root == null:
		return MCPToolRegistry.create_response("No scene is currently open", {
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

	return MCPToolRegistry.create_response("Current scene: %s (%s)" % [root.name, path if not path.is_empty() else "unsaved"], {
		"path": path,
		"root_name": root.name,
		"root_type": root_type,
		"node_count": node_count,
		"modified": root.is_inside_tree(),
		"is_running": _editor_interface.is_playing_scene()
	})


func _execute_get_node_tree(_args: Dictionary) -> Dictionary:
	var root: Node = _editor_interface.get_edited_scene_root()

	if root == null:
		return MCPToolRegistry.create_response("No scene is currently open", {
			"root": null,
			"path": ""
		})

	var tree: Dictionary = _build_node_tree(root)
	var path: String = root.scene_file_path

	return MCPToolRegistry.create_response("Scene tree retrieved for: %s" % root.name, {
		"root": tree,
		"path": path
	})


# --- Helpers ---

func _count_nodes(node: Node) -> int:
	if node == null:
		return 0

	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)

	return count


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

## FileSystem Tools
## MCP tools for file system operations.
extends RefCounted
class_name FileSystemTools

const TOOL_LIST_DIR := "fs_list_dir"
const TOOL_READ_FILE := "fs_read_file"
const TOOL_WRITE_FILE := "fs_write_file"
const TOOL_DELETE := "fs_delete"
const TOOL_COPY := "fs_copy"
const TOOL_MOVE := "fs_move"

var _logger: MCPLogger
var _editor_interface: EditorInterface


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("FileSystemTools") if logger else MCPLogger.new("[FileSystemTools]")
	_editor_interface = editor_interface


## Registers all filesystem tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_list_dir_tool())
	registry.register(_create_read_file_tool())
	registry.register(_create_write_file_tool())
	registry.register(_create_delete_tool())
	registry.register(_create_copy_tool())
	registry.register(_create_move_tool())


func _create_list_dir_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_LIST_DIR,
			"Lists contents of a directory",
			{
				"path": {"type": "string", "default": "res://", "description": "Directory path"},
				"recursive": {"type": "boolean", "default": false},
				"filter": {"type": "string", "description": "File extension filter (e.g., '*.gd')"}
			},
			[]
		)
	return MCPToolHandler.new(definition, _execute_list_dir)


func _create_read_file_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_READ_FILE,
			"Reads a text file's contents",
			{
				"path": {"type": "string", "description": "File path"},
				"start_line": {"type": "integer", "default": 1},
				"end_line": {"type": "integer", "description": "End line (inclusive)"}
			},
			["path"]
		)
	return MCPToolHandler.new(definition, _execute_read_file)


func _create_write_file_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_WRITE_FILE,
			"Writes content to a file",
			{
				"path": {"type": "string", "description": "File path"},
				"content": {"type": "string", "description": "Content to write"},
				"mode": {"type": "string", "enum": ["write", "append"], "default": "write"}
			},
			["path", "content"]
		)
	return MCPToolHandler.new(definition, _execute_write_file)


func _create_delete_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_DELETE,
			"Deletes a file or directory",
			{
				"path": {"type": "string", "description": "Path to delete"},
				"recursive": {"type": "boolean", "default": false, "description": "Delete directory contents"}
			},
			["path"]
		)
	return MCPToolHandler.new(definition, _execute_delete)


func _create_copy_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_COPY,
			"Copies a file",
			{
				"source": {"type": "string", "description": "Source file path"},
				"destination": {"type": "string", "description": "Destination file path"}
			},
			["source", "destination"]
		)
	return MCPToolHandler.new(definition, _execute_copy)


func _create_move_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_MOVE,
			"Moves or renames a file",
			{
				"source": {"type": "string", "description": "Source file path"},
				"destination": {"type": "string", "description": "Destination file path"}
			},
			["source", "destination"]
		)
	return MCPToolHandler.new(definition, _execute_move)


# --- Tool Implementations ---

func _execute_list_dir(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "res://")
	var recursive: bool = params.get("recursive", false)
	var filter_pattern: String = params.get("filter", "")

	# Validate path
	if not DirAccess.dir_exists_absolute(path):
		return MCPToolResult.error("Directory not found: %s" % path, MCPError.Code.NOT_FOUND)

	var directories: Array[String] = []
	var files: Array[Dictionary] = []

	_list_dir_recursive(path, recursive, filter_pattern, directories, files)

	return MCPToolResult.text(
		"Found %d files and %d directories in %s" % [files.size(), directories.size(), path],
		{
			"path": path,
			"directories": directories,
			"files": files
		}
	)


func _list_dir_recursive(
	path: String,
	recursive: bool,
	filter_pattern: String,
	directories: Array[String],
	files: Array[Dictionary]
) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path: String = path.path_join(file_name)

		if dir.current_is_dir():
			directories.append(file_name)
			if recursive:
				_list_dir_recursive(full_path, recursive, filter_pattern, directories, files)
		else:
			if filter_pattern.is_empty() or file_name.match(filter_pattern):
				files.append({
					"name": file_name,
					"path": full_path,
					"type": _get_file_type(file_name),
					"size": _get_file_size(full_path)
				})

		file_name = dir.get_next()

	dir.list_dir_end()


func _execute_read_file(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "")
	var start_line: int = params.get("start_line", 1)
	var end_line: int = params.get("end_line", -1)

	# Validate path
	if not FileAccess.file_exists(path):
		return MCPToolResult.error("File not found: %s" % path, MCPError.Code.NOT_FOUND)

	# Read file
	var content: String = FileAccess.get_file_as_string(path)
	if content.is_empty() and FileAccess.get_open_error() != OK:
		return MCPToolResult.error("Failed to read file: %s" % path, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Handle line range
	if start_line > 1 or end_line > 0:
		var lines: PackedStringArray = content.split("\n")
		var total_lines: int = lines.size()

		if start_line < 1:
			start_line = 1
		if end_line < 0 or end_line > total_lines:
			end_line = total_lines

		start_line -= 1  # Convert to 0-indexed

		var selected_lines: Array[String] = []
		for i: int in range(start_line, end_line):
			selected_lines.append(lines[i])
		content = "\n".join(selected_lines)

	return MCPToolResult.text("Read file: %s" % path, {
		"path": path,
		"content": content,
		"line_count": content.split("\n").size()
	})


func _execute_write_file(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")
	var mode: String = params.get("mode", "write")

	# Validate path
	if not path.begins_with("res://"):
		return MCPToolResult.error("Invalid path: must start with res://", MCPError.Code.INVALID_PARAMS)

	# Open file
	var file_mode: FileAccess.ModeFlags = FileAccess.WRITE if mode == "write" else FileAccess.READ_WRITE
	var file: FileAccess = FileAccess.open(path, file_mode)

	if file == null:
		# Try to create parent directory
		var parent_dir: String = path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(parent_dir)
		file = FileAccess.open(path, FileAccess.WRITE)

		if file == null:
			return MCPToolResult.error("Failed to create file: %s" % path, MCPError.Code.TOOL_EXECUTION_ERROR)

	# Write content
	if mode == "append":
		file.seek_end()
	file.store_string(content)
	file.close()

	_logger.info("File written", {"path": path, "mode": mode, "bytes": content.length()})

	return MCPToolResult.text("File written: %s" % path, {
		"path": path,
		"mode": mode,
		"bytes_written": content.length()
	})


func _execute_delete(params: Dictionary) -> MCPToolResult:
	var path: String = params.get("path", "")
	var recursive: bool = params.get("recursive", false)

	# Validate path
	if not path.begins_with("res://"):
		return MCPToolResult.error("Invalid path: must start with res://", MCPError.Code.INVALID_PARAMS)

	var err: Error
	if DirAccess.dir_exists_absolute(path):
		if recursive:
			err = DirAccess.make_dir_recursive_absolute(path)  # This won't work, need different approach
			# Actually delete recursively
			err = _delete_directory_recursive(path)
		else:
			err = DirAccess.remove_absolute(path)
	else:
		err = DirAccess.remove_absolute(path)

	if err != OK:
		return MCPToolResult.error("Failed to delete: %s (error: %d)" % [path, err], MCPError.Code.TOOL_EXECUTION_ERROR)

	_logger.info("Deleted", {"path": path, "recursive": recursive})
	return MCPToolResult.text("Deleted: %s" % path, {"path": path})


func _delete_directory_recursive(path: String) -> Error:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return ERR_UNCONFIGURED

	# Delete contents first
	dir.list_dir_begin()
	var item: String = dir.get_next()

	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue

		var full_path: String = path.path_join(item)
		if dir.current_is_dir():
			_delete_directory_recursive(full_path)
		else:
			DirAccess.remove_absolute(full_path)

		item = dir.get_next()

	dir.list_dir_end()

	return DirAccess.remove_absolute(path)


func _execute_copy(params: Dictionary) -> MCPToolResult:
	var source: String = params.get("source", "")
	var destination: String = params.get("destination", "")

	# Validate paths
	if not source.begins_with("res://") or not destination.begins_with("res://"):
		return MCPToolResult.error("Invalid path: must start with res://", MCPError.Code.INVALID_PARAMS)

	if not FileAccess.file_exists(source):
		return MCPToolResult.error("Source file not found: %s" % source, MCPError.Code.NOT_FOUND)

	var err: Error = DirAccess.copy_absolute(source, destination)
	if err != OK:
		return MCPToolResult.error("Failed to copy file (error: %d)" % err, MCPError.Code.TOOL_EXECUTION_ERROR)

	_logger.info("File copied", {"source": source, "destination": destination})
	return MCPToolResult.text("Copied: %s -> %s" % [source, destination], {
		"source": source,
		"destination": destination
	})


func _execute_move(params: Dictionary) -> MCPToolResult:
	var source: String = params.get("source", "")
	var destination: String = params.get("destination", "")

	# Validate paths
	if not source.begins_with("res://") or not destination.begins_with("res://"):
		return MCPToolResult.error("Invalid path: must start with res://", MCPError.Code.INVALID_PARAMS)

	if not FileAccess.file_exists(source) and not DirAccess.dir_exists_absolute(source):
		return MCPToolResult.error("Source not found: %s" % source, MCPError.Code.NOT_FOUND)

	var err: Error

	# Ensure destination directory exists
	var dest_dir: String = destination.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dest_dir)

	if FileAccess.file_exists(source):
		err = DirAccess.copy_absolute(source, destination)
		if err == OK:
			DirAccess.remove_absolute(source)
	else:
		err = DirAccess.rename_absolute(source, destination)

	if err != OK:
		return MCPToolResult.error("Failed to move (error: %d)" % err, MCPError.Code.TOOL_EXECUTION_ERROR)

	_logger.info("File moved", {"source": source, "destination": destination})
	return MCPToolResult.text("Moved: %s -> %s" % [source, destination], {
		"source": source,
		"destination": destination
	})


func _get_file_type(file_name: String) -> String:
	var ext: String = file_name.get_extension().to_lower()
	match ext:
		"gd":
			return "GDScript"
		"tscn":
			return "Scene"
		"tres":
			return "Resource"
		"png", "jpg", "jpeg", "webp":
			return "Image"
		"wav", "ogg", "mp3":
			return "Audio"
		"json":
			return "JSON"
		_:
			return ext.to_upper()


func _get_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = file.get_length()
	file.close()
	return size

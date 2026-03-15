## FileSystem Tools
## MCP tools for file system operations.
extends RefCounted
class_name FileSystemTools

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all filesystem tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := FileSystemTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("fs_list_dir", "Lists contents of a directory", {
			"path": {"type": "string", "default": "res://", "description": "Directory path"},
			"recursive": {"type": "boolean", "default": false},
			"filter": {"type": "string", "description": "File extension filter (e.g., '*.gd')"}
		}, [], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Directory path that was listed"},
				"directories": {"type": "array", "items": {"type": "string"}, "description": "Directory names"},
				"files": {"type": "array", "items": {"type": "object"}, "description": "File info with name, path, type, size"}
			}
		}),
		tools._execute_list_dir
	)

	registry.register_tool(
		_create_tool_def("fs_read_file", "Reads a text file's contents", {
			"path": {"type": "string", "description": "File path"},
			"start_line": {"type": "integer", "default": 1},
			"end_line": {"type": "integer", "description": "End line (inclusive)"}
		}, ["path"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "File path that was read"},
				"content": {"type": "string", "description": "File content"},
				"line_count": {"type": "integer", "description": "Number of lines in content"}
			}
		}),
		tools._execute_read_file
	)

	registry.register_tool(
		_create_tool_def("fs_write_file", "Writes content to a file", {
			"path": {"type": "string", "description": "File path"},
			"content": {"type": "string", "description": "Content to write"},
			"mode": {"type": "string", "enum": ["write", "append"], "default": "write"}
		}, ["path", "content"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "File path that was written"},
				"mode": {"type": "string", "description": "Write mode used"},
				"bytes_written": {"type": "integer", "description": "Number of bytes written"}
			}
		}),
		tools._execute_write_file
	)

	registry.register_tool(
		_create_tool_def("fs_delete", "Deletes a file or directory", {
			"path": {"type": "string", "description": "Path to delete"},
			"recursive": {"type": "boolean", "default": false, "description": "Delete directory contents"}
		}, ["path"], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Path that was deleted"}
			}
		}),
		tools._execute_delete
	)

	registry.register_tool(
		_create_tool_def("fs_copy", "Copies a file", {
			"source": {"type": "string", "description": "Source file path"},
			"destination": {"type": "string", "description": "Destination file path"}
		}, ["source", "destination"], {
			"type": "object",
			"properties": {
				"source": {"type": "string", "description": "Source file path"},
				"destination": {"type": "string", "description": "Destination file path"}
			}
		}),
		tools._execute_copy
	)

	registry.register_tool(
		_create_tool_def("fs_move", "Moves or renames a file", {
			"source": {"type": "string", "description": "Source file path"},
			"destination": {"type": "string", "description": "Destination file path"}
		}, ["source", "destination"], {
			"type": "object",
			"properties": {
				"source": {"type": "string", "description": "Source file path"},
				"destination": {"type": "string", "description": "Destination file path"}
			}
		}),
		tools._execute_move
	)

	return tools


# --- Tool Implementations ---

func _execute_list_dir(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "res://")
	var recursive: bool = args.get("recursive", false)
	var filter_pattern: String = args.get("filter", "")

	# Validate path
	if not DirAccess.dir_exists_absolute(path):
		return {"content": [{"type": "text", "text": "Error: Directory not found: %s" % path}], "isError": true}

	var directories: Array[String] = []
	var files: Array[Dictionary] = []

	_list_dir_recursive(path, recursive, filter_pattern, directories, files)

	return MCPToolRegistry.create_response("Found %d files and %d directories in %s" % [files.size(), directories.size(), path], {
		"path": path,
		"directories": directories,
		"files": files
	})


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


func _execute_read_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var start_line: int = args.get("start_line", 1)
	var end_line: int = args.get("end_line", -1)

	# Validate path
	if not FileAccess.file_exists(path):
		return {"content": [{"type": "text", "text": "Error: File not found: %s" % path}], "isError": true}

	# Read file
	var content: String = FileAccess.get_file_as_string(path)
	if content.is_empty() and FileAccess.get_open_error() != OK:
		return {"content": [{"type": "text", "text": "Error: Failed to read file: %s" % path}], "isError": true}

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

	return MCPToolRegistry.create_response("Read file: %s" % path, {
		"path": path,
		"content": content,
		"line_count": content.split("\n").size()
	})


func _execute_write_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var content: String = args.get("content", "")
	var mode: String = args.get("mode", "write")

	# Validate path
	if not path.begins_with("res://"):
		return {"content": [{"type": "text", "text": "Error: Invalid path: must start with res://"}], "isError": true}

	# Open file
	var file_mode: FileAccess.ModeFlags = FileAccess.WRITE if mode == "write" else FileAccess.READ_WRITE
	var file: FileAccess = FileAccess.open(path, file_mode)

	if file == null:
		# Try to create parent directory
		var parent_dir: String = path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(parent_dir)
		file = FileAccess.open(path, FileAccess.WRITE)

		if file == null:
			return {"content": [{"type": "text", "text": "Error: Failed to create file: %s" % path}], "isError": true}

	# Write content
	if mode == "append":
		file.seek_end()
	file.store_string(content)
	file.close()

	return MCPToolRegistry.create_response("File written: %s" % path, {
		"path": path,
		"mode": mode,
		"bytes_written": content.length()
	})


func _execute_delete(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var recursive: bool = args.get("recursive", false)

	# Validate path
	if not path.begins_with("res://"):
		return {"content": [{"type": "text", "text": "Error: Invalid path: must start with res://"}], "isError": true}

	var err: Error
	if DirAccess.dir_exists_absolute(path):
		if recursive:
			err = _delete_directory_recursive(path)
		else:
			err = DirAccess.remove_absolute(path)
	else:
		err = DirAccess.remove_absolute(path)

	if err != OK:
		return {"content": [{"type": "text", "text": "Error: Failed to delete: %s (error: %d)" % [path, err]}], "isError": true}

	return MCPToolRegistry.create_response("Deleted: %s" % path, {
		"path": path
	})


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


func _execute_copy(args: Dictionary) -> Dictionary:
	var source: String = args.get("source", "")
	var destination: String = args.get("destination", "")

	# Validate paths
	if not source.begins_with("res://") or not destination.begins_with("res://"):
		return {"content": [{"type": "text", "text": "Error: Invalid path: must start with res://"}], "isError": true}

	if not FileAccess.file_exists(source):
		return {"content": [{"type": "text", "text": "Error: Source file not found: %s" % source}], "isError": true}

	var err: Error = DirAccess.copy_absolute(source, destination)
	if err != OK:
		return {"content": [{"type": "text", "text": "Error: Failed to copy file (error: %d)" % err}], "isError": true}

	return MCPToolRegistry.create_response("Copied: %s -> %s" % [source, destination], {
		"source": source,
		"destination": destination
	})


func _execute_move(args: Dictionary) -> Dictionary:
	var source: String = args.get("source", "")
	var destination: String = args.get("destination", "")

	# Validate paths
	if not source.begins_with("res://") or not destination.begins_with("res://"):
		return {"content": [{"type": "text", "text": "Error: Invalid path: must start with res://"}], "isError": true}

	if not FileAccess.file_exists(source) and not DirAccess.dir_exists_absolute(source):
		return {"content": [{"type": "text", "text": "Error: Source not found: %s" % source}], "isError": true}

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
		return {"content": [{"type": "text", "text": "Error: Failed to move (error: %d)" % err}], "isError": true}

	return MCPToolRegistry.create_response("Moved: %s -> %s" % [source, destination], {
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

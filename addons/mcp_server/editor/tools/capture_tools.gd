## Editor Capture Tools
## MCP tools for capturing editor viewport screenshots.
extends RefCounted
class_name EditorCaptureTools

var _editor_interface: EditorInterface


func _init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


## Registers all capture tools with the registry
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted, editor_interface: EditorInterface) -> RefCounted:
	var tools := EditorCaptureTools.new(editor_interface)

	registry.register_tool(
		_create_tool_def("screenshot_capture_editor", "Captures a screenshot of the Godot editor viewport (3D or 2D) and saves it to disk", {
			"filename": {"type": "string", "description": "Custom filename (without extension). If not provided, auto-generates timestamp-based name"},
			"format": {"type": "string", "enum": ["png", "jpg"], "default": "png", "description": "Image format. PNG for lossless, JPG for smaller files"},
			"quality": {"type": "integer", "minimum": 1, "maximum": 100, "default": 90, "description": "JPG quality (1-100). Only used when format is jpg"}
		}, []),
		tools._execute_capture_editor
	)

	registry.register_tool(
		_create_tool_def("screenshot_list", "Lists all captured screenshots in the MCP screenshots directory with metadata", {}, []),
		tools._execute_list
	)

	return tools


# --- Tool Implementations ---

func _execute_capture_editor(args: Dictionary) -> Dictionary:
	if _editor_interface == null:
		return {"content": [{"type": "text", "text": "Error: Editor interface not available"}], "isError": true}

	# Try to get editor viewport (3D first, then 2D fallback)
	var editor_viewport: Node = _editor_interface.get_editor_viewport_3d()
	var viewport_type: String = "3D"

	if editor_viewport == null:
		editor_viewport = _editor_interface.get_editor_viewport_2d()
		viewport_type = "2D"

	if editor_viewport == null:
		return {"content": [{"type": "text", "text": "Error: Cannot capture screenshot: No editor viewport is currently open. Open a 3D or 2D viewport first."}], "isError": true}

	var viewport: Viewport = editor_viewport.get_viewport()
	if viewport == null:
		return {"content": [{"type": "text", "text": "Error: Cannot capture screenshot: Viewport is not available."}], "isError": true}

	var format: String = args.get("format", ScreenshotUtils.DEFAULT_FORMAT)
	var custom_filename: String = args.get("filename", "")
	var quality: int = args.get("quality", ScreenshotUtils.DEFAULT_QUALITY)

	# Validate format
	if format != "png" and format != "jpg":
		return {"content": [{"type": "text", "text": "Error: Invalid format '%s'. Must be 'png' or 'jpg'." % format}], "isError": true}

	# Validate quality
	if quality < 1 or quality > 100:
		return {"content": [{"type": "text", "text": "Error: Quality must be between 1 and 100, got %d." % quality}], "isError": true}

	# Capture the viewport
	var result: Dictionary = ScreenshotUtils.capture_viewport(
		viewport,
		format,
		"editor_" + custom_filename if not custom_filename.is_empty() else "",
		quality
	)

	if not result.get("success", false):
		return {"content": [{"type": "text", "text": "Error: %s" % result.get("error", "Failed to capture screenshot")}], "isError": true}

	return {
		"content": [{"type": "text", "text": "Editor screenshot saved (%s viewport): %s" % [viewport_type, result.absolute_path]}],
		"isError": false,
		"data": {
			"path": result.path,
			"absolute_path": result.absolute_path,
			"filename": result.filename,
			"format": result.format,
			"size_bytes": result.size_bytes,
			"width": result.width,
			"height": result.height,
			"captured_at": result.captured_at,
			"source": "editor",
			"viewport_type": viewport_type
		}
	}


func _execute_list(_args: Dictionary) -> Dictionary:
	var screenshots: Array[Dictionary] = ScreenshotUtils.list_screenshots()

	var total_size: int = 0
	for info: Dictionary in screenshots:
		total_size += info.get("size_bytes", 0)

	# Build text with paths for easy access
	var lines: Array[String] = ["Found %d screenshot%s:" % [screenshots.size(), "s" if screenshots.size() != 1 else ""]]
	for info: Dictionary in screenshots:
		lines.append("  - %s" % info.get("absolute_path", info.get("filename", "unknown")))

	return {
		"content": [{"type": "text", "text": "\n".join(lines)}],
		"isError": false,
		"data": {"count": screenshots.size(), "total_size_bytes": total_size, "screenshots": screenshots}
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

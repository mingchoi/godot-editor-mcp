## Editor Capture Tools
## MCP tools for capturing editor viewport screenshots.
extends RefCounted
class_name EditorCaptureTools

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

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
		}, [], {
			"type": "object",
			"properties": {
				"path": {"type": "string", "description": "Relative path in user:// directory"},
				"absolute_path": {"type": "string", "description": "Absolute file system path"},
				"filename": {"type": "string", "description": "Filename with extension"},
				"format": {"type": "string", "description": "Image format (png or jpg)"},
				"size_bytes": {"type": "integer", "description": "File size in bytes"},
				"width": {"type": "integer", "description": "Image width in pixels"},
				"height": {"type": "integer", "description": "Image height in pixels"},
				"captured_at": {"type": "string", "description": "ISO 8601 timestamp"},
				"source": {"type": "string", "description": "Screenshot source (editor)"},
				"viewport_type": {"type": "string", "description": "Viewport type (3D or 2D)"}
			}
		}),
		tools._execute_capture_editor
	)

	registry.register_tool(
		_create_tool_def("screenshot_list", "Lists all captured screenshots in the MCP screenshots directory with metadata", {}, [], {
			"type": "object",
			"properties": {
				"count": {"type": "integer", "description": "Number of screenshots"},
				"total_size_bytes": {"type": "integer", "description": "Total size in bytes"},
				"screenshots": {"type": "array", "items": {"type": "object"}, "description": "Array of screenshot info"}
			}
		}),
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

	return MCPToolRegistry.create_response("Editor screenshot saved (%s viewport): %s" % [viewport_type, result.absolute_path], {
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
	})


func _execute_list(_args: Dictionary) -> Dictionary:
	var screenshots: Array[Dictionary] = ScreenshotUtils.list_screenshots()

	var total_size: int = 0
	for info: Dictionary in screenshots:
		total_size += info.get("size_bytes", 0)

	# Build text with paths for easy access
	var lines: Array[String] = ["Found %d screenshot%s:" % [screenshots.size(), "s" if screenshots.size() != 1 else ""]]
	for info: Dictionary in screenshots:
		lines.append("  - %s" % info.get("absolute_path", info.get("filename", "unknown")))

	return MCPToolRegistry.create_response("\n".join(lines), {
		"count": screenshots.size(),
		"total_size_bytes": total_size,
		"screenshots": screenshots
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

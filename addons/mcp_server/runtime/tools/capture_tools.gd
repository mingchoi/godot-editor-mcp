## Viewport Capture Tools
## MCP tools for capturing game viewport screenshots.
extends RefCounted
class_name CaptureTools

const TOOL_CAPTURE_RUNTIME := "screenshot_capture_runtime"
const TOOL_LIST := "screenshot_list"

var _logger: MCPLogger
var _editor_interface: EditorInterface


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("CaptureTools") if logger else MCPLogger.new("[CaptureTools]")
	_editor_interface = editor_interface


## Registers all capture tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_capture_runtime_tool())
	registry.register(_create_list_tool())


func _create_capture_runtime_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_CAPTURE_RUNTIME,
		"Captures a screenshot of the running game viewport and saves it to disk",
		{
			"filename": {
				"type": "string",
				"description": "Custom filename (without extension). If not provided, auto-generates timestamp-based name"
			},
			"format": {
				"type": "string",
				"enum": ["png", "jpg"],
				"default": "png",
				"description": "Image format. PNG for lossless, JPG for smaller files"
			},
			"quality": {
				"type": "integer",
				"minimum": 1,
				"maximum": 100,
				"default": 90,
				"description": "JPG quality (1-100). Only used when format is jpg"
			}
		},
		[]
	)
	return MCPToolHandler.new(definition, _execute_capture_runtime)


func _create_list_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_LIST,
		"Lists all captured screenshots in the MCP screenshots directory with metadata",
		{},
		[]
	)
	return MCPToolHandler.new(definition, _execute_list)


# --- Tool Implementations ---

func _execute_capture_runtime(params: Dictionary) -> MCPToolResult:
	var viewport: Viewport = _get_viewport()
	if viewport == null:
		return MCPToolResult.error(
			"Cannot capture screenshot: No viewport available. Ensure a scene is running.",
			MCPError.Code.TOOL_EXECUTION_ERROR
		)

	var format: String = params.get("format", ScreenshotUtils.DEFAULT_FORMAT)
	var custom_filename: String = params.get("filename", "")
	var quality: int = params.get("quality", ScreenshotUtils.DEFAULT_QUALITY)

	# Validate format
	if format != "png" and format != "jpg":
		return MCPToolResult.error(
			"Invalid format '%s'. Must be 'png' or 'jpg'." % format,
			MCPError.Code.INVALID_PARAMS
		)

	# Validate quality
	if quality < 1 or quality > 100:
		return MCPToolResult.error(
			"Quality must be between 1 and 100, got %d." % quality,
			MCPError.Code.INVALID_PARAMS
		)

	# Capture the viewport
	var result: Dictionary = ScreenshotUtils.capture_viewport(
		viewport,
		format,
		custom_filename,
		quality
	)

	if not result.get("success", false):
		return MCPToolResult.error(
			result.get("error", "Failed to capture screenshot"),
			result.get("error_code", MCPError.Code.TOOL_EXECUTION_ERROR)
		)

	_logger.info("Screenshot captured", {
		"path": result.path,
		"format": format,
		"size": result.size_bytes
	})

	return MCPToolResult.text(
		"Screenshot saved: %s" % result.absolute_path,
		{
			"path": result.path,
			"absolute_path": result.absolute_path,
			"filename": result.filename,
			"format": result.format,
			"size_bytes": result.size_bytes,
			"width": result.width,
			"height": result.height,
			"captured_at": result.captured_at,
			"source": "runtime"
		}
	)


func _execute_list(_params: Dictionary) -> MCPToolResult:
	var screenshots: Array[Dictionary] = ScreenshotUtils.list_screenshots()

	var total_size: int = 0
	for info: Dictionary in screenshots:
		total_size += info.get("size_bytes", 0)

	_logger.info("Listed screenshots", {"count": screenshots.size()})

	# Build text with paths for easy access
	var lines: Array[String] = ["Found %d screenshot%s:" % [screenshots.size(), "s" if screenshots.size() != 1 else ""]]
	for info: Dictionary in screenshots:
		lines.append("  - %s" % info.get("absolute_path", info.get("filename", "unknown")))

	return MCPToolResult.text(
		"\n".join(lines),
		{
			"count": screenshots.size(),
			"total_size_bytes": total_size,
			"screenshots": screenshots
		}
	)


# --- Helper Methods ---

func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _get_viewport() -> Viewport:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return null
	return tree.root

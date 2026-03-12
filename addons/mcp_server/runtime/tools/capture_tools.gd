## Viewport Capture Tools
## MCP tools for capturing game viewport screenshots.
extends RefCounted
class_name CaptureTools

const TOOL_CAPTURE_VIEWPORT := "capture_viewport"
const TOOL_CAPTURE_COMPARE := "capture_compare"

var _logger: MCPLogger
var _editor_interface: EditorInterface
var _captures: Dictionary = {}  # capture_id -> Dictionary with image data
var _next_capture_id: int = 1


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("CaptureTools") if logger else MCPLogger.new("[CaptureTools]")
	_editor_interface = editor_interface


## Registers all capture tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_capture_viewport_tool())
	registry.register(_create_capture_compare_tool())


func _create_capture_viewport_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_CAPTURE_VIEWPORT,
			"Captures the game viewport as an image",
			{
				"viewport": {"type": "string", "default": "main", "description": "Viewport to capture"},
				"region": {
					"type": "object",
					"properties": {
						"x": {"type": "integer"},
						"y": {"type": "integer"},
						"width": {"type": "integer"},
						"height": {"type": "integer"}
					},
					"description": "Region to capture"
				},
				"format": {"type": "string", "enum": ["png", "jpg", "webp"], "default": "png"},
				"quality": {"type": "integer", "default": 85, "minimum": 1, "maximum": 100},
				"max_width": {"type": "integer", "default": 1920, "description": "Resize if wider"}
			},
			[]
		)
	return MCPToolHandler.new(definition, _execute_capture_viewport)


func _create_capture_compare_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_CAPTURE_COMPARE,
			"Captures and compares with a previous capture",
			{
				"previous_capture_id": {"type": "string", "description": "ID of previous capture"},
				"threshold": {"type": "number", "default": 0.01, "description": "Difference threshold (0-1)"}
			},
			["previous_capture_id"]
		)
	return MCPToolHandler.new(definition, _execute_capture_compare)


# --- Tool Implementations ---

func _get_viewport(viewport_name: String) -> Viewport:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null

	if viewport_name == "main" or viewport_name.is_empty():
		return tree.root

	# Try to find viewport by path
	var node: Node = tree.root.get_node_or_null(viewport_name)
	if node is Viewport:
		return node as Viewport
	if node is SubViewportContainer:
		for child: Node in node.get_children():
			if child is SubViewport:
				return child as SubViewport

	return tree.root


func _execute_capture_viewport(params: Dictionary) -> MCPToolResult:
	var viewport_name: String = params.get("viewport", "main")
	var region: Dictionary = params.get("region", {})
	var format: String = params.get("format", "png")
	var quality: int = params.get("quality", 85)
	var max_width: int = params.get("max_width", 1920)

	var viewport: Viewport = _get_viewport(viewport_name)
	if viewport == null:
		return MCPToolResult.error("Viewport not found: %s" % viewport_name, MCPError.Code.NOT_FOUND)

	# Wait for next frame to ensure viewport is rendered
	await _get_tree().process_frame

	# Get viewport texture
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return MCPToolResult.error("Failed to get viewport texture", MCPError.Code.TOOL_EXECUTION_ERROR)

	# Get image
	var image: Image = texture.get_image()
	if image == null:
		return MCPToolResult.error("Failed to get image from viewport", MCPError.Code.TOOL_EXECUTION_ERROR)

	# Apply region if specified
	if not region.is_empty():
		var x: int = region.get("x", 0)
		var y: int = region.get("y", 0)
		var w: int = region.get("width", image.get_width())
		var h: int = region.get("height", image.get_height())
		image = image.get_region(Rect2i(x, y, w, h))

	# Resize if needed
	if image.get_width() > max_width:
		var scale: float = float(max_width) / float(image.get_width())
		var new_height: int = int(image.get_height() * scale)
		image.resize(max_width, new_height, Image.INTERPOLATE_LANCZOS)

	# Encode image
	var encoded: PackedByteArray
	match format.to_lower():
		"png":
			encoded = image.save_png_to_buffer()
		"jpg", "jpeg":
			encoded = image.save_jpg_to_buffer(quality / 100.0)
		"webp":
			encoded = image.save_webp_to_buffer(quality / 100.0)
		_:
			encoded = image.save_png_to_buffer()
			format = "png"

	# Base64 encode
	var base64_data: String = Marshalls.raw_to_base64(encoded)

	# Store capture for comparison
	var capture_id: String = "cap_%d" % _next_capture_id
	_next_capture_id += 1
	_captures[capture_id] = {
		"image": image,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": format,
		"captured_at": Time.get_datetime_string_from_system(true)
	}

	_logger.info("Viewport captured", {
		"capture_id": capture_id,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": format
	})

	var result_data: Dictionary = {
		"capture_id": capture_id,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": format,
		"captured_at": _captures[capture_id]["captured_at"],
		"image_data": base64_data
	}

	var result := MCPToolResult.image(base64_data, "image/%s" % format)
	result.data = result_data
	return result


func _execute_capture_compare(params: Dictionary) -> MCPToolResult:
	var previous_id: String = params.get("previous_capture_id", "")
	var threshold: float = params.get("threshold", 0.01)

	# Check if previous capture exists
	if not _captures.has(previous_id):
		return MCPToolResult.error("Previous capture not found: %s" % previous_id, MCPError.Code.NOT_FOUND)

	var previous: Dictionary = _captures[previous_id]
	var previous_image: Image = previous["image"]

	# Get viewport
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return MCPToolResult.error("Scene tree not available", MCPError.Code.TOOL_EXECUTION_ERROR)

	var viewport: Viewport = tree.root
	if viewport == null:
		return MCPToolResult.error("Viewport not available", MCPError.Code.TOOL_EXECUTION_ERROR)

	# Wait for frame
	await tree.process_frame

	# Capture current
	var texture: ViewportTexture = viewport.get_texture()
	var current_image: Image = texture.get_image()

	# Resize current to match previous if needed
	if current_image.get_width() != previous_image.get_width() or current_image.get_height() != previous_image.get_height():
		current_image.resize(previous_image.get_width(), previous_image.get_height())

	# Compare images
	var similarity: float = _calculate_image_similarity(previous_image, current_image)
	var is_different: bool = (1.0 - similarity) > threshold

	# Find changed regions (simplified)
	var changed_regions: Array[Dictionary] = []
	if is_different:
		changed_regions = _find_changed_regions(previous_image, current_image, threshold)

	# Store new capture
	var capture_id: String = "cap_%d" % _next_capture_id
	_next_capture_id += 1
	_captures[capture_id] = {
		"image": current_image,
		"width": current_image.get_width(),
		"height": current_image.get_height(),
		"format": "png",
		"captured_at": Time.get_datetime_string_from_system(true)
	}

	# Encode current for response
	var encoded: PackedByteArray = current_image.save_png_to_buffer()
	var base64_data: String = Marshalls.raw_to_base64(encoded)

	_logger.info("Capture compared", {
		"previous_id": previous_id,
		"new_id": capture_id,
		"similarity": similarity,
		"is_different": is_different
	})

	var result := MCPToolResult.image(base64_data, "image/png")
	result.data = {
		"capture_id": capture_id,
		"similarity": similarity,
		"is_different": is_different,
		"changed_regions": changed_regions
	}
	return result


func _calculate_image_similarity(img1: Image, img2: Image) -> float:
	var width: int = img1.get_width()
	var height: int = img1.get_height()
	var total_pixels: int = width * height

	if total_pixels == 0:
		return 1.0

	# Convert to same format
	img1.convert(Image.FORMAT_RGBA8)
	img2.convert(Image.FORMAT_RGBA8)

	var data1: PackedByteArray = img1.get_data()
	var data2: PackedByteArray = img2.get_data()

	var total_diff: float = 0.0
	var bytes_per_pixel: int = 4

	for y: int in range(height):
		for x: int in range(width):
			var idx: int = (y * width + x) * bytes_per_pixel

			var r_diff: float = absf(data1[idx] - data2[idx]) / 255.0
			var g_diff: float = absf(data1[idx + 1] - data2[idx + 1]) / 255.0
			var b_diff: float = absf(data1[idx + 2] - data2[idx + 2]) / 255.0

			var pixel_diff: float = (r_diff + g_diff + b_diff) / 3.0
			total_diff += pixel_diff

	return 1.0 - (total_diff / float(total_pixels))


func _find_changed_regions(img1: Image, img2: Image, _threshold: float) -> Array[Dictionary]:
	# Simplified: just find bounding box of changes
	# In production, would use proper region detection

	var width: int = img1.get_width()
	var height: int = img1.get_height()

	var min_x: int = width
	var min_y: int = height
	var max_x: int = 0
	var max_y: int = 0

	img1.convert(Image.FORMAT_RGBA8)
	img2.convert(Image.FORMAT_RGBA8)

	var data1: PackedByteArray = img1.get_data()
	var data2: PackedByteArray = img2.get_data()

	var bytes_per_pixel: int = 4
	var has_changes: bool = false

	for y: int in range(height):
		for x: int in range(width):
			var idx: int = (y * width + x) * bytes_per_pixel

			var r_diff: int = absi(data1[idx] - data2[idx])
			var g_diff: int = absi(data1[idx + 1] - data2[idx + 1])
			var b_diff: int = absi(data1[idx + 2] - data2[idx + 2])

			if r_diff > 10 or g_diff > 10 or b_diff > 10:
				has_changes = true
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	if not has_changes:
		return []

	return [{
		"x": min_x,
		"y": min_y,
		"width": max_x - min_x + 1,
		"height": max_y - min_y + 1
	}]


func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Clears all stored captures
func clear_captures() -> void:
	_captures.clear()


## Gets a capture by ID
func get_capture(capture_id: String) -> Dictionary:
	return _captures.get(capture_id, {})

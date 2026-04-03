## Cursor Overlay Node
## CanvasLayer-based overlay that draws a mouse cursor arrow and tracks position.
## Parented to root viewport, uses MOUSE_FILTER_IGNORE to not block input.
extends CanvasLayer

var _cursor_control: Control


func _ready() -> void:
	layer = 100
	name = "CursorOverlayDebug"

	# Create control for drawing the cursor
	_cursor_control = Control.new()
	_cursor_control.name = "CursorSprite"
	_cursor_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cursor_control.draw.connect(_on_cursor_draw)
	add_child(_cursor_control)


func _process(_delta: float) -> void:
	# Trigger redraw every frame to track mouse position
	_cursor_control.queue_redraw()


func _on_cursor_draw() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return

	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var polygon: PackedVector2Array = _get_cursor_polygon()

	# Offset polygon to mouse position
	var offset_polygon: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon:
		offset_polygon.append(point + mouse_pos)

	# White fill with slight transparency
	_cursor_control.draw_colored_polygon(offset_polygon, Color(1, 1, 1, 0.9))
	# Dark outline for visibility on any background
	for i: int in range(offset_polygon.size()):
		var from: Vector2 = offset_polygon[i]
		var to: Vector2 = offset_polygon[(i + 1) % offset_polygon.size()]
		_cursor_control.draw_line(from, to, Color(0, 0, 0, 0.8), 1.5)


## Standard arrow cursor polygon points (~14x24px)
static func _get_cursor_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0),       # Tip
		Vector2(0, 20),      # Left bottom
		Vector2(5, 16),      # Inner notch
		Vector2(9, 24),      # Tail right
		Vector2(12, 23),     # Tail top
		Vector2(8, 15),      # Inner notch top
		Vector2(14, 15),     # Right point
	])

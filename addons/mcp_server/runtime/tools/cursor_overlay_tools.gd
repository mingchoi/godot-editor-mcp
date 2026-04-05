## Cursor Overlay Tools
## MCP tools for toggling a visual mouse pointer overlay in running games.
## The overlay is non-blocking (MOUSE_FILTER_IGNORE) and drawn programmatically.
extends RefCounted
class_name CursorOverlayTools

const CursorOverlayScene = preload("res://addons/mcp_server/runtime/tools/cursor_overlay.gd")

var _overlay: CanvasLayer = null


## Registers the cursor overlay tool
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted) -> RefCounted:
	var tools := CursorOverlayTools.new()

	registry.register_tool(
		_create_tool_def("runtime_toggle_mouse_pointer", "Toggles a visual mouse pointer overlay in the running game for debugging. The overlay shows the current mouse position without blocking any mouse interaction.", {
			"enabled": {"type": "boolean", "default": true, "description": "Toggle the pointer overlay on or off"}
		}, []),
		tools._execute_toggle_pointer
	)

	return tools


# --- Tool Implementation ---

func _execute_toggle_pointer(args: Dictionary) -> Dictionary:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return {"content": [{"type": "text", "text": "Error: Game not running"}], "isError": true}

	var enabled: bool = args.get("enabled", true)

	if enabled:
		# Idempotent: if overlay already exists, return current state
		if _overlay != null and is_instance_valid(_overlay):
			var viewport: Viewport = _get_viewport()
			var pos: Vector2 = Vector2.ZERO
			if viewport != null:
				pos = viewport.get_mouse_position()
			return {
				"content": [{"type": "text", "text": "Mouse pointer overlay already enabled"}],
				"isError": false,
				"structuredContent": {
					"enabled": true,
					"position": {"x": pos.x, "y": pos.y}
				}
			}

		# Create overlay node with script
		_overlay = CanvasLayer.new()
		_overlay.set_script(CursorOverlayScene)
		tree.root.add_child(_overlay)

		var viewport: Viewport = _get_viewport()
		var pos: Vector2 = Vector2.ZERO
		if viewport != null:
			pos = viewport.get_mouse_position()
		return {
			"content": [{"type": "text", "text": "Mouse pointer overlay enabled"}],
			"isError": false,
			"structuredContent": {
				"enabled": true,
				"position": {"x": pos.x, "y": pos.y}
			}
		}
	else:
		_remove_overlay()
		return {
			"content": [{"type": "text", "text": "Mouse pointer overlay disabled"}],
			"isError": false,
			"structuredContent": {
				"enabled": false
			}
		}


# --- Overlay Lifecycle ---

func _remove_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


# --- Helpers ---

func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _get_viewport() -> Viewport:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return null
	return tree.root


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

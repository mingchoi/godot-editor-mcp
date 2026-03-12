## Integration Tests for Editor Capture Tool
## Tests for screenshot_capture_editor MCP tool.
## Run with GdUnit4 or manually verify in Godot editor.
class_name TestEditorCapture
extends RefCounted

# Note: These tests require a running Godot editor with MCP connection.
# They document expected behavior and can be run with GdUnit4.

## Test: screenshot_capture_editor tool with 3D viewport
func test_capture_3d_viewport() -> void:
	# This test requires MCP connection and open 3D viewport
	# Documenting expected behavior:
	# 1. Open a 3D scene in the editor
	# 2. Invoke screenshot_capture_editor with no params
	# 3. Expect success response with viewport_type=3D
	# 4. Verify file exists and contains editor viewport content
	pass

## Test: screenshot_capture_editor with 2D viewport fallback
func test_capture_2d_viewport_fallback() -> void:
	# This test requires MCP connection with only 2D viewport open
	# Documenting expected behavior:
	# 1. Close all 3D viewports, open 2D viewport
	# 2. Invoke screenshot_capture_editor
	# 3. Expect success response with viewport_type=2D
	# 4. Verify file exists and contains 2D editor content
	pass

## Test: screenshot_capture_editor with custom filename
func test_capture_custom_filename() -> void:
	# This test requires MCP connection
	# Documenting expected behavior:
	# 1. Invoke screenshot_capture_editor with filename="my_editor_shot"
	# 2. Expect success response with filename="editor_my_editor_shot.png"
	# 3. Verify file exists at returned path
	pass

## Test: screenshot_capture_editor error when no viewport available
func test_capture_no_viewport() -> void:
	# This test requires MCP connection with no open viewports
	# Documenting expected behavior:
	# 1. Close all editor viewports
	# 2. Invoke screenshot_capture_editor
	# 3. Expect error response: "No editor viewport is currently open"
	# 4. Verify isError=true in response
	pass

## Test: Response includes correct metadata
func test_response_metadata() -> void:
	# This test requires MCP connection and open viewport
	# Documenting expected response structure:
	# {
	#   "content": [{"type": "text", "text": "Editor screenshot saved (3D viewport): ..."}],
	#   "isError": false,
	#   "data": {
	#     "path": "user://mcp/screenshots/...",
	#     "absolute_path": "/home/.../...",
	#     "format": "png",
	#     "size_bytes": 123456,
	#     "width": 1920,
	#     "height": 1080,
	#     "captured_at": "2026-03-12T15:30:00",
	#     "source": "editor",
	#     "viewport_type": "3D"  // or "2D"
	#   }
	# }
	pass

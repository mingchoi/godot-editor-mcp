## Integration Tests for Runtime Capture Tool
## Tests for screenshot_capture_runtime MCP tool.
## Run with GdUnit4 or manually verify in Godot editor.
class_name TestRuntimeCapture
extends RefCounted

# Note: These tests require a running Godot scene to execute properly.
# They document expected behavior and can be run with GdUnit4.

## Test: screenshot_capture_runtime tool with default settings (PNG, auto filename)
func test_capture_default_settings() -> void:
	# This test requires MCP connection and running scene
	# Documenting expected behavior:
	# 1. Invoke screenshot_capture_runtime with no params
	# 2. Expect success response with path, format=png, and auto-generated filename
	# 3. Verify file exists at returned path
	# 4. Verify file is valid PNG image
	pass

## Test: screenshot_capture_runtime with custom filename
func test_capture_custom_filename() -> void:
	# This test requires MCP connection and running scene
	# Documenting expected behavior:
	# 1. Invoke screenshot_capture_runtime with filename="test_custom"
	# 2. Expect success response with filename="test_custom.png"
	# 3. Verify file exists at returned path
	pass

## Test: screenshot_capture_runtime with JPG format
func test_capture_jpg_format() -> void:
	# This test requires MCP connection and running scene
	# Documenting expected behavior:
	# 1. Invoke screenshot_capture_runtime with format="jpg", quality=85
	# 2. Expect success response with format=jpg
	# 3. Verify file exists and is valid JPG
	# 4. Verify file size is smaller than equivalent PNG would be
	pass

## Test: screenshot_capture_runtime error when no viewport available
func test_capture_no_viewport() -> void:
	# This test requires MCP connection with no running scene
	# Documenting expected behavior:
	# 1. Stop any running scene
	# 2. Invoke screenshot_capture_runtime
	# 3. Expect error response: "No viewport available"
	# 4. Verify isError=true in response
	pass

## Test: screenshot_capture_runtime validates format parameter
func test_capture_invalid_format() -> void:
	# This test requires MCP connection
	# Documenting expected behavior:
	# 1. Invoke screenshot_capture_runtime with format="invalid"
	# 2. Expect error response: "Invalid format"
	# 3. Verify isError=true in response
	pass

## Test: screenshot_capture_runtime validates quality parameter
func test_capture_invalid_quality() -> void:
	# This test requires MCP connection
	# Documenting expected behavior:
	# 1. Invoke screenshot_capture_runtime with quality=150
	# 2. Expect error response: "Quality must be between 1 and 100"
	# 3. Verify isError=true in response
	pass

## Test: Response includes correct metadata
func test_response_metadata() -> void:
	# This test requires MCP connection and running scene
	# Documenting expected response structure:
	# {
	#   "content": [{"type": "text", "text": "Screenshot saved: ..."}],
	#   "isError": false,
	#   "data": {
	#     "path": "user://mcp/screenshots/...",
	#     "absolute_path": "/home/.../...",
	#     "format": "png",
	#     "size_bytes": 12345,
	#     "width": 1920,
	#     "height": 1080,
	#     "captured_at": "2026-03-12T15:30:00",
	#     "source": "runtime"
	#   }
	# }
	pass

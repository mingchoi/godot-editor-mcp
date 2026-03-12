## Integration Tests for List Screenshots Tool
## Tests for screenshot_list MCP tool.
## Run with GdUnit4 or manually verify in Godot editor.
class_name TestListScreenshots
extends RefCounted

# Note: These tests require MCP connection.
# They document expected behavior and can be run with GdUnit4.

## Test: list returns empty array when no screenshots
func test_list_empty_directory() -> void:
	# This test requires MCP connection and empty screenshots directory
	# Setup: Remove all files from user://mcp/screenshots/
	# Documenting expected behavior:
	# 1. Invoke screenshot_list
	# 2. Expect success response with count=0, screenshots=[]
	# 3. Verify text says "Found 0 screenshots"
	pass

## Test: list returns all screenshots with metadata
func test_list_with_screenshots() -> void:
	# This test requires MCP connection and some captured screenshots
	# Setup: Capture a few screenshots first
	# Documenting expected behavior:
	# 1. Capture 3 screenshots with different names
	# 2. Invoke screenshot_list
	# 3. Expect success response with count=3
	# 4. Verify each screenshot in array has:
	#    - filename: string
	#    - path: string
	#    - size_bytes: integer > 0
	#    - captured_at: ISO 8601 timestamp
	# 5. Verify total_size_bytes is sum of all sizes
	pass

## Test: list handles missing directory gracefully
func test_list_missing_directory() -> void:
	# This test requires MCP connection and no screenshots directory
	# Setup: Remove user://mcp/screenshots/ directory entirely
	# Documenting expected behavior:
	# 1. Invoke screenshot_list
	# 2. Expect success response with count=0, screenshots=[]
	# 3. No error should be returned
	pass

## Test: list returns screenshots sorted by timestamp (newest first)
func test_list_sorted_by_timestamp() -> void:
	# This test requires MCP connection
	# Setup: Capture screenshots at different times
	# Documenting expected behavior:
	# 1. Capture screenshot A (wait 1 second) Capture screenshot B
	# 2. Invoke screenshot_list
	# 3. Verify screenshots[0].captured_at > screenshots[1].captured_at
	# 4. Screenshots should be sorted newest first
	pass

## Test: Response includes correct metadata
func test_response_structure() -> void:
	# Documenting expected response structure:
	# {
	#   "content": [{"type": "text", "text": "Found N screenshot(s)"}],
	#   "isError": false,
	#   "data": {
	#     "count": 3,
	#     "total_size_bytes": 123456,
	#     "screenshots": [
	#       {
	#         "filename": "screenshot_2026-03-12T15-30-00.png",
	#         "path": "user://mcp/screenshots/screenshot_2026-03-12T15-30-00.png",
	#         "size_bytes": 50000,
	#         "captured_at": "2026-03-12T15:30:00"
	#       },
	#       ...
	#     ]
	#   }
	# }
	pass

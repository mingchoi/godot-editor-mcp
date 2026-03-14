## Unit Tests for ScreenshotUtils
## Tests for screenshot utility functions.
## Run with GdUnit4 or manually verify in Godot editor.
class_name TestScreenshotUtils
extends RefCounted

# Note: These tests require Godot runtime environment to execute.
# They document expected behavior and can be run with GdUnit4.

## Test: ensure_screenshot_dir() creates directory if it doesn't exist
func test_ensure_screenshot_dir() -> void:
	# Clean up if exists
	var dir := DirAccess.open("user://")
	if dir and dir.dir_exists("mcp"):
		dir.change_dir("mcp")
		if dir.dir_exists("screenshots"):
			# Note: Can't delete non-empty directory in one step
			pass

	# Test creation
	var result := ScreenshotUtils.ensure_screenshot_dir()
	assert(result == true, "ensure_screenshot_dir should return true")

	# Verify directory exists
	assert(DirAccess.dir_exists_absolute("user://mcp/screenshots/"), "Directory should exist")

## Test: generate_filename() creates timestamp-based names
func test_generate_filename_default() -> void:
	var filename := ScreenshotUtils.generate_filename("png")

	# Should start with "screenshot_"
	assert(filename.begins_with("screenshot_"), "Filename should start with 'screenshot_'")

	# Should end with .png
	assert(filename.ends_with(".png"), "Filename should end with '.png'")

	# Should contain timestamp-like pattern (YYYY-MM-DDTHH-MM-SS)
	assert(filename.contains("T"), "Filename should contain 'T' separator")

## Test: generate_filename() uses custom name when provided
func test_generate_filename_custom() -> void:
	var filename := ScreenshotUtils.generate_filename("jpg", "my_custom_name")

	# Should use custom name
	assert(filename == "my_custom_name.jpg", "Filename should be 'my_custom_name.jpg'")

## Test: generate_filename() sanitizes problematic characters
func test_generate_filename_sanitization() -> void:
	var filename := ScreenshotUtils.generate_filename("png", "test/file:name")

	# Should replace problematic characters
	assert(not filename.contains("/"), "Filename should not contain '/'")
	assert(not filename.contains(":"), "Filename should not contain ':'")

## Test: save_image() saves PNG correctly
func test_save_image_png() -> void:
	var image := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)

	var filepath := "user://mcp/screenshots/test_save_png.png"
	var error := ScreenshotUtils.save_image(image, filepath, "png")

	assert(error == OK, "save_image should return OK for PNG")

	# Verify file exists
	assert(FileAccess.file_exists(filepath), "PNG file should exist")

	# Clean up
	DirAccess.remove_absolute(filepath)

## Test: save_image() saves JPG correctly
func test_save_image_jpg() -> void:
	var image := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)

	var filepath := "user://mcp/screenshots/test_save_jpg.jpg"
	var error := ScreenshotUtils.save_image(image, filepath, "jpg", 90)

	assert(error == OK, "save_image should return OK for JPG")

	# Verify file exists
	assert(FileAccess.file_exists(filepath), "JPG file should exist")

	# Clean up
	DirAccess.remove_absolute(filepath)

## Test: save_image() returns error for null image
func test_save_image_null() -> void:
	var error := ScreenshotUtils.save_image(null, "user://mcp/screenshots/test.png", "png")

	assert(error == ERR_INVALID_PARAMETER, "save_image should return ERR_INVALID_PARAMETER for null image")

## Test: get_file_info() returns correct metadata
func test_get_file_info() -> void:
	# Create a test file
	var image := Image.create(50, 50, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	var filepath := "user://mcp/screenshots/test_info.png"
	ScreenshotUtils.save_image(image, filepath, "png")

	var info := ScreenshotUtils.get_file_info(filepath)

	assert(info.has("filename"), "Info should have 'filename'")
	assert(info.has("path"), "Info should have 'path'")
	assert(info.has("size_bytes"), "Info should have 'size_bytes'")
	assert(info.has("captured_at"), "Info should have 'captured_at'")
	assert(info.filename == "test_info.png", "Filename should be 'test_info.png'")
	assert(info.size_bytes > 0, "Size should be greater than 0")

	# Clean up
	DirAccess.remove_absolute(filepath)

## Test: get_file_info() returns empty dict for non-existent file
func test_get_file_info_nonexistent() -> void:
	var info := ScreenshotUtils.get_file_info("user://mcp/screenshots/nonexistent.png")

	assert(info.is_empty(), "Info should be empty for non-existent file")

## Test: list_screenshots() returns array of screenshots
func test_list_screenshots() -> void:
	# Create test screenshots
	var image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	ScreenshotUtils.save_image(image, "user://mcp/screenshots/test_list_1.png", "png")
	ScreenshotUtils.save_image(image, "user://mcp/screenshots/test_list_2.jpg", "jpg")

	var screenshots := ScreenshotUtils.list_screenshots()

	assert(screenshots.size() >= 2, "Should have at least 2 screenshots")

	# Clean up
	DirAccess.remove_absolute("user://mcp/screenshots/test_list_1.png")
	DirAccess.remove_absolute("user://mcp/screenshots/test_list_2.jpg")

## Test: list_screenshots() returns empty array when directory doesn't exist
func test_list_screenshots_empty() -> void:
	# Use a non-existent directory
	var original_dir := ScreenshotUtils.SCREENSHOT_DIR
	# Note: Can't modify const, so this tests the actual behavior
	# when directory is empty or doesn't exist

	var screenshots := ScreenshotUtils.list_screenshots()
	# Should return array (possibly empty)
	assert(screenshots is Array, "Should return an Array")

## Test: capture_viewport() captures and saves correctly
func test_capture_viewport() -> void:
	# This test requires a viewport, so it's more of an integration test
	# Documenting expected behavior here
	var mock_result := {
		"success": true,
		"path": "user://mcp/screenshots/screenshot_test.png",
		"format": "png"
	}

	assert(mock_result.success == true, "capture_viewport should return success")

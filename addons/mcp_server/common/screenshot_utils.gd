## ScreenshotUtils - Shared Screenshot Utilities
## Provides common functionality for capturing and managing screenshots
## across both editor and runtime MCP servers.
class_name ScreenshotUtils
extends RefCounted

## Directory where screenshots are stored (relative to user://)
const SCREENSHOT_DIR := "user://mcp/screenshots/"

## Default image format for screenshots
const DEFAULT_FORMAT := "png"

## Default JPG quality (1-100)
const DEFAULT_QUALITY := 90

## Supported image formats
const FORMAT_PNG := "png"
const FORMAT_JPG := "jpg"


## Ensures the screenshot directory exists.
## Returns true if directory exists or was created successfully.
static func ensure_screenshot_dir() -> bool:
	return DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR) == OK


## Generates a unique filename for a screenshot.
## If custom_name is provided, uses that; otherwise generates timestamp-based name.
static func generate_filename(format: String, custom_name: String = "") -> String:
	var filename: String
	if custom_name.is_empty():
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
		filename = "screenshot_%s.%s" % [timestamp, format]
	else:
		# Sanitize custom name - remove potentially problematic characters
		var safe_name := custom_name.replace("/", "_").replace("\\", "_").replace(":", "_")
		safe_name = safe_name.replace("*", "_").replace("?", "_").replace("\"", "_")
		safe_name = safe_name.replace("<", "_").replace(">", "_").replace("|", "_")
		filename = "%s.%s" % [safe_name, format]
	return filename


## Saves an image to disk in the specified format.
## Returns OK on success, or an error code on failure.
static func save_image(image: Image, filepath: String, format: String, quality: int = DEFAULT_QUALITY) -> int:
	if image == null:
		return ERR_INVALID_PARAMETER

	var error: int
	if format == FORMAT_JPG:
		error = image.save_jpg(filepath, quality / 100.0)
	else:
		error = image.save_png(filepath)

	return error


## Gets file information for a screenshot.
## Returns a dictionary with filename, path, size, and timestamp.
static func get_file_info(filepath: String) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {}

	var file := FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {}

	var size: int = file.get_length()
	file.close()

	var filename: String = filepath.get_file()
	var modified_time: int = FileAccess.get_modified_time(filepath)
	var timestamp: String = ""
	if modified_time > 0:
		var datetime := Time.get_datetime_dict_from_unix_time(modified_time)
		timestamp = "%04d-%02d-%02dT%02d:%02d:%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		]

	return {
		"filename": filename,
		"path": filepath,
		"size_bytes": size,
		"captured_at": timestamp
	}


## Lists all screenshots in the screenshot directory.
## Returns an array of dictionaries with file info.
static func list_screenshots() -> Array[Dictionary]:
	var screenshots: Array[Dictionary] = []

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(SCREENSHOT_DIR):
		return screenshots

	var dir := DirAccess.open(SCREENSHOT_DIR)
	if dir == null:
		return screenshots

	# List all image files
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir():
			var ext := filename.get_extension().to_lower()
			if ext == "png" or ext == "jpg" or ext == "jpeg":
				var filepath := SCREENSHOT_DIR.path_join(filename)
				var info := get_file_info(filepath)
				if not info.is_empty():
					screenshots.append(info)
		filename = dir.get_next()
	dir.list_dir_end()

	# Sort by timestamp (newest first)
	screenshots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("captured_at", "") > b.get("captured_at", "")
	)

	return screenshots


## Captures a viewport and saves it as a screenshot.
## Returns a dictionary with the result (success/error).
static func capture_viewport(
	viewport: Viewport,
	format: String = DEFAULT_FORMAT,
	custom_filename: String = "",
	quality: int = DEFAULT_QUALITY
) -> Dictionary:
	if viewport == null:
		return {
			"success": false,
			"error": "No viewport provided",
			"error_code": ERR_INVALID_PARAMETER
		}

	# Ensure directory exists
	if not ensure_screenshot_dir():
		return {
			"success": false,
			"error": "Failed to create screenshot directory",
			"error_code": ERR_CANT_CREATE
		}

	# Capture viewport
	var image := viewport.get_texture().get_image()
	if image == null:
		return {
			"success": false,
			"error": "Failed to capture viewport texture",
			"error_code": ERR_CANT_ACQUIRE_RESOURCE
		}

	# Generate filename
	var filename := generate_filename(format, custom_filename)
	var filepath := SCREENSHOT_DIR.path_join(filename)

	# Save image
	var error := save_image(image, filepath, format, quality)
	if error != OK:
		return {
			"success": false,
			"error": "Failed to save screenshot (error code: %d)" % error,
			"error_code": error
		}

	# Get absolute path for user reference
	var absolute_path := ProjectSettings.globalize_path(filepath)

	# Return success with metadata
	return {
		"success": true,
		"path": filepath,
		"absolute_path": absolute_path,
		"filename": filename,
		"format": format,
		"width": image.get_width(),
		"height": image.get_height(),
		"size_bytes": FileAccess.open(filepath, FileAccess.READ).get_length() if FileAccess.open(filepath, FileAccess.READ) else 0,
		"captured_at": Time.get_datetime_string_from_system()
	}

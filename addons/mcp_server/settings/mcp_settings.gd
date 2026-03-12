## MCP Settings
## Global plugin settings resource.
class_name MCPSettings
extends Resource

@export var editor_mcp: MCPServerConfig
@export var runtime_mcp: MCPServerConfig
@export var log_level: String = "info"  # debug, info, warning, error
@export var allow_delete_operations: bool = true
@export var confirm_destructive_ops: bool = true
@export var rate_limit_per_minute: int = 100
@export var screenshot_max_width: int = 1920
@export var screenshot_quality: int = 85


func _init() -> void:
	if editor_mcp == null:
		editor_mcp = MCPServerConfig.default_editor_config()
	if runtime_mcp == null:
		runtime_mcp = MCPServerConfig.default_runtime_config()


## Creates default settings
static func create_default() -> MCPSettings:
	var settings := MCPSettings.new()
	settings.editor_mcp = MCPServerConfig.default_editor_config()
	settings.runtime_mcp = MCPServerConfig.default_runtime_config()
	return settings


## Loads settings from file or creates defaults
static func load_or_create(path: String = "res://addons/mcp_server/settings/mcp_settings.tres") -> MCPSettings:
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is MCPSettings:
			return loaded as MCPSettings

	var settings := MCPSettings.new()
	# Don't save automatically - let user configure first
	return settings


## Saves settings to file
func save_to_file(path: String = "res://addons/mcp_server/settings/mcp_settings.tres") -> Error:
	return ResourceSaver.save(self, path)


## Gets the log level as MCPLogger.Level enum value
func get_log_level_enum() -> MCPLogger.Level:
	match log_level.to_lower():
		"debug":
			return MCPLogger.Level.DEBUG
		"info":
			return MCPLogger.Level.INFO
		"warning", "warn":
			return MCPLogger.Level.WARNING
		"error":
			return MCPLogger.Level.ERROR
		_:
			return MCPLogger.Level.INFO


## Validates all settings
func validate() -> Array[String]:
	var errors: Array[String] = []

	if editor_mcp != null:
		errors.append_array(editor_mcp.validate())

	if runtime_mcp != null:
		errors.append_array(runtime_mcp.validate())

	if rate_limit_per_minute < 1 or rate_limit_per_minute > 1000:
		errors.append("Rate limit must be between 1 and 1000")

	if screenshot_max_width < 100 or screenshot_max_width > 4096:
		errors.append("Screenshot max width must be between 100 and 4096")

	if screenshot_quality < 1 or screenshot_quality > 100:
		errors.append("Screenshot quality must be between 1 and 100")

	return errors

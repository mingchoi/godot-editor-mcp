## MCP Server Logger
## Provides structured logging with levels and formatting.
class_name MCPLogger
extends RefCounted

## Log level enum
enum Level {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3
}

var _min_level: Level = Level.INFO
var _prefix: String = "[MCP]"


func _init(prefix: String = "[MCP]", min_level: Level = Level.INFO) -> void:
	_prefix = prefix
	_min_level = min_level


## Sets the minimum log level
func set_level(level: Level) -> void:
	_min_level = level


## Gets the current minimum log level
func get_level() -> Level:
	return _min_level


## Logs a debug message
func debug(message: String, context: Dictionary = {}) -> void:
	if _min_level <= Level.DEBUG:
		_log("DEBUG", message, context)


## Logs an info message
func info(message: String, context: Dictionary = {}) -> void:
	if _min_level <= Level.INFO:
		_log("INFO", message, context)


## Logs a warning message
func warning(message: String, context: Dictionary = {}) -> void:
	if _min_level <= Level.WARNING:
		_log("WARNING", message, context)


## Logs an error message
func error(message: String, context: Dictionary = {}) -> void:
	if _min_level <= Level.ERROR:
		_log("ERROR", message, context)


## Internal logging method
func _log(level_name: String, message: String, context: Dictionary) -> void:
	var timestamp: String = Time.get_datetime_string_from_system(true)
	var log_line: String = "%s %s [%s] %s" % [timestamp, _prefix, level_name, message]

	if not context.is_empty():
		log_line += " | " + JSON.stringify(context)

	match level_name:
		"DEBUG":
			print(log_line)
		"INFO":
			print(log_line)
		"WARNING":
			push_warning(log_line)
		"ERROR":
			push_error(log_line)


## Creates a child logger with additional prefix
func child(child_prefix: String) -> MCPLogger:
	return MCPLogger.new(_prefix + "/" + child_prefix, _min_level)


## Creates a logger from string level
static func from_string_level(level_string: String, prefix: String = "[MCP]") -> MCPLogger:
	var level: Level = Level.INFO
	match level_string.to_lower():
		"debug":
			level = Level.DEBUG
		"info":
			level = Level.INFO
		"warning", "warn":
			level = Level.WARNING
		"error":
			level = Level.ERROR
	return MCPLogger.new(prefix, level)

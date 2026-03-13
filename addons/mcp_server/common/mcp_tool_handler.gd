## MCPToolHandler - Base Class for Tool Implementations
## Base class for tool implementations using callback pattern.
class_name MCPToolHandler
extends RefCounted

var definition: MCPToolDefinition
var _execute_callback: Callable


func _init(tool_definition: MCPToolDefinition, execute_callback: Callable = Callable()) -> void:
	definition = tool_definition
	_execute_callback = execute_callback


## Executes the tool with given parameters.
## Uses the callback if set, otherwise must be overridden in subclass.
## Always uses await to support both sync and async callbacks.
func execute(params: Dictionary) -> MCPToolResult:
	if _execute_callback.is_valid():
		# Always await - works for both sync and async callbacks
		var result = await _execute_callback.call(params)
		return result
	push_error("execute() must have a valid callback or be overridden in subclass")
	return MCPToolResult.error("Tool not implemented", MCPError.Code.INTERNAL_ERROR)


## Validates parameters against the schema
func validate_params(params: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var required: Array = definition.input_schema.get("required", [])
	for field in required:
		if not params.has(field):
			errors.append("Missing required field: %s" % field)
	return errors


## Helper to create a text result
func text_result(message: String, data: Dictionary = {}) -> MCPToolResult:
	return MCPToolResult.text(message, data)


## Helper to create an error result
func error_result(message: String, code: int = -32000) -> MCPToolResult:
	return MCPToolResult.error(message, code)

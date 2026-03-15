class_name MCPToolRegistry
extends RefCounted

## Central registry for MCP tools
## Tool categories register their tools here

var _tools: Array[Dictionary] = []
var _handlers: Dictionary = {}  # tool_name -> callable


func register_tool(tool_def: Dictionary, handler: Callable) -> void:
	_tools.append(tool_def)
	_handlers[tool_def.name] = handler


func get_tools() -> Array[Dictionary]:
	return _tools


func call_tool(tool_name: String, arguments: Dictionary) -> Dictionary:
	if not _handlers.has(tool_name):
		return {
			"content": [{"type": "text", "text": "Unknown tool: %s" % tool_name}],
			"isError": true
		}

	var handler: Callable = _handlers[tool_name]
	return await handler.call(arguments)


func has_tool(tool_name: String) -> bool:
	return _handlers.has(tool_name)


## Get the number of registered tools
func size() -> int:
	return _tools.size()


## Create an MCP-compliant response with optional structured content
## Per MCP spec, structuredContent is a separate field from content array
static func create_response(message: String, data: Dictionary = {}, is_error: bool = false) -> Dictionary:
	var response: Dictionary = {
		"content": [{"type": "text", "text": message}],
		"isError": is_error
	}
	if not data.is_empty():
		response["structuredContent"] = data
	return response

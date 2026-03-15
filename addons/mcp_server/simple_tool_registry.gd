## Simple Tool Registry for MCP
## Central registry for MCP tools with simple registration pattern
class_name SimpleToolRegistry
extends RefCounted

var _tools: Array[Dictionary] = []
var _handlers: Dictionary = {}  # tool_name -> callable


## Register a tool with its handler
func register_tool(tool_def: Dictionary, handler: Callable) -> void:
	_tools.append(tool_def)
	_handlers[tool_def.name] = handler


## Get all tool definitions for tools/list
func get_tools() -> Array[Dictionary]:
	return _tools


## Call a tool by name with arguments
func call_tool(tool_name: String, arguments: Dictionary) -> Dictionary:
	if not _handlers.has(tool_name):
		return {
			"content": [{"type": "text", "text": "Unknown tool: %s" % tool_name}],
			"isError": true
		}

	var handler: Callable = _handlers[tool_name]
	var result = handler.call(arguments)

	# Handle both MCPToolResult and plain dict returns
	if result is MCPToolResult:
		return result.to_response_dict()
	return result


## Check if a tool exists
func has_tool(tool_name: String) -> bool:
	return _handlers.has(tool_name)


## Get the number of registered tools
func size() -> int:
	return _tools.size()

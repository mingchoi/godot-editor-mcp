## ToolRegistry - Tool Management
## Manages available tools.
class_name ToolRegistry
extends RefCounted

var _tools: Dictionary = {}  # String -> MCPToolHandler


## Registers a tool handler
func register(handler: MCPToolHandler) -> void:
	_tools[handler.definition.name] = handler


## Unregisters a tool by name
func unregister(tool_name: String) -> bool:
	return _tools.erase(tool_name)


## Gets a tool handler by name
func get_tool(tool_name: String) -> MCPToolHandler:
	return _tools.get(tool_name)


## Checks if a tool exists
func has_tool(tool_name: String) -> bool:
	return _tools.has(tool_name)


## Lists all tool definitions
func list_tools() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for handler: MCPToolHandler in _tools.values():
		result.append(handler.definition.to_dict())
	return result


## Gets all tool names
func get_tool_names() -> Array[String]:
	var names: Array[String] = []
	for name: String in _tools.keys():
		names.append(name)
	return names


## Gets the number of registered tools
func size() -> int:
	return _tools.size()


## Clears all registered tools
func clear() -> void:
	_tools.clear()

## MCPToolDefinition - Tool Interface Definition
## Defines a tool's interface for MCP discovery.
class_name MCPToolDefinition
extends RefCounted

var name: String
var description: String
var input_schema: Dictionary  # JSON Schema


func _init(tool_name: String = "", tool_description: String = "", schema: Dictionary = {}) -> void:
	name = tool_name
	description = tool_description
	input_schema = schema


## Creates a tool definition with common schema structure
static func create(
	tool_name: String,
	tool_description: String,
	properties: Dictionary,
	required: Array[String] = []
) -> MCPToolDefinition:
	var schema: Dictionary = {
		"type": "object",
		"properties": properties
	}
	if not required.is_empty():
		schema["required"] = required
	return MCPToolDefinition.new(tool_name, tool_description, schema)


## Converts to dictionary for tools/list response
func to_dict() -> Dictionary:
	return {
		"name": name,
		"description": description,
		"inputSchema": input_schema
	}

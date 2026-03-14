## MCPToolResult - Tool Execution Result
## Represents the result content from a tool execution.
class_name MCPToolResult
extends RefCounted

var content: Array[Dictionary] = []
var is_error: bool = false
var data: Dictionary = {}  # Optional structured data


func _init() -> void:
	pass


## Creates a text result
static func text(message: String, result_data: Dictionary = {}) -> MCPToolResult:
	var result := MCPToolResult.new()
	result.content.append(MCPContent.text_content(message).to_dict())
	result.data = result_data
	return result


## Creates an image result
static func image(base64_data: String, mime_type: String = "image/png") -> MCPToolResult:
	var result := MCPToolResult.new()
	result.content.append(MCPContent.image_content(base64_data, mime_type).to_dict())
	return result


## Creates an error result
static func error(message: String, error_code: int = -32000) -> MCPToolResult:
	var result := MCPToolResult.new()
	result.content.append(MCPContent.text_content(message).to_dict())
	result.is_error = true
	result.data = {"code": error_code}
	return result


## Converts to MCP response format
func to_response_dict() -> Dictionary:
	var response: Dictionary = {
		"content": content,
		"isError": is_error
	}
	if not data.is_empty():
		response["data"] = data
	return response

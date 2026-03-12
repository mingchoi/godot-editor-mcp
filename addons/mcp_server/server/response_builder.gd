## MCP Response Builder
## Helper class for constructing MCP protocol responses.
class_name ResponseBuilder
extends RefCounted

## Builds a tools/list response
static func tools_list_response(tools: Array[Dictionary]) -> Dictionary:
	return {
		"tools": tools
	}


## Builds a tools/call success response
static func tool_success_result(content: Array[Dictionary], is_error: bool = false) -> Dictionary:
	return {
		"content": content,
		"isError": is_error
	}


## Builds a tools/call text response
static func tool_text_result(message: String, data: Dictionary = {}) -> Dictionary:
	var content: Array[Dictionary] = [MCPContent.text_content(message).to_dict()]
	var result := {
		"content": content,
		"isError": false
	}
	if not data.is_empty():
		result["data"] = data
	return result


## Builds a tools/call image response
static func tool_image_result(base64_data: String, mime_type: String = "image/png") -> Dictionary:
	var content: Array[Dictionary] = [MCPContent.image_content(base64_data, mime_type).to_dict()]
	return {
		"content": content,
		"isError": false
	}


## Builds a tools/call error response
static func tool_error_result(message: String, code: int = -32000) -> Dictionary:
	var content: Array[Dictionary] = [MCPContent.text_content(message).to_dict()]
	return {
		"content": content,
		"isError": true,
		"data": {"code": code}
	}


## Builds a ping response
static func ping_response() -> Dictionary:
	return {}


## Converts an MCPToolResult to a response dictionary
static func from_tool_result(result: MCPToolResult) -> Dictionary:
	return result.to_response_dict()


## Builds a complete JSON-RPC success response
static func jsonrpc_success(id: Variant, result: Dictionary) -> String:
	var response := MCPResponse.success(id, result)
	return response.to_json()


## Builds a complete JSON-RPC error response
static func jsonrpc_error(id: Variant, code: int, message: String, data: Dictionary = {}) -> String:
	var error := MCPError.new(code, message, data)
	var response := MCPResponse.create_error(id, error)
	return response.to_json()

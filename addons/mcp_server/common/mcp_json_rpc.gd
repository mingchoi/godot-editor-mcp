## MCP JSON-RPC 2.0 Handler
## Handles parsing and formatting of JSON-RPC messages.
## Named MCPJSONRPC to avoid conflict with Godot's built-in JSONRPC class.
class_name MCPJSONRPC
extends RefCounted

## Parses a JSON-RPC request from a string
static func parse_request(json_string: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_string)

	if parsed == null:
		return {
			"valid": false,
			"error": MCPError.create(MCPError.Code.PARSE_ERROR, "Parse error: Invalid JSON")
		}

	if not parsed is Dictionary:
		return {
			"valid": false,
			"error": MCPError.create(MCPError.Code.INVALID_REQUEST, "Invalid request: Expected object")
		}

	var data: Dictionary = parsed as Dictionary

	# Validate jsonrpc version
	if data.get("jsonrpc") != "2.0":
		return {
			"valid": false,
			"error": MCPError.create(MCPError.Code.INVALID_REQUEST, "Invalid request: jsonrpc must be '2.0'")
		}

	# Validate method
	var method: Variant = data.get("method")
	if method == null or not method is String or (method as String).is_empty():
		return {
			"valid": false,
			"error": MCPError.create(MCPError.Code.INVALID_REQUEST, "Invalid request: method is required")
		}

	# Validate id (can be int, string, or null for notifications)
	var id: Variant = data.get("id")
	if id != null and not (id is int or id is String or id is float):
		return {
			"valid": false,
			"error": MCPError.create(MCPError.Code.INVALID_REQUEST, "Invalid request: id must be int, string, or null")
		}

	return {
		"valid": true,
		"request": MCPRequest.from_dict(data)
	}


## Creates a success response
static func create_response(id: Variant, result: Variant) -> String:
	var response := MCPResponse.success(id, result)
	return response.to_json()


## Creates an error response
static func create_error(id: Variant, code: int, message: String, data: Dictionary = {}) -> String:
	var error := MCPError.new(code, message, data)
	var response := MCPResponse.create_error(id, error)
	return response.to_json()


## Creates a response from an MCPResponse object
static func format_response(response: MCPResponse) -> String:
	return response.to_json()


## Creates a batch response
static func create_batch_response(responses: Array[MCPResponse]) -> String:
	var batch: Array[Dictionary] = []
	for response in responses:
		batch.append(response.to_dict())
	return JSON.stringify(batch)


## Validates if a string is valid JSON
static func is_valid_json(json_string: String) -> bool:
	return JSON.parse_string(json_string) != null


## Parses JSON safely, returning null on error
static func parse_json_safe(json_string: String) -> Variant:
	return JSON.parse_string(json_string)


## Converts a variant to JSON string
static func to_json(data: Variant) -> String:
	return JSON.stringify(data)

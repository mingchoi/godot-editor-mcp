## MCPError - JSON-RPC 2.0 Error Object
## Represents a JSON-RPC 2.0 error object.
class_name MCPError
extends RefCounted

## Standard JSON-RPC error codes
enum Code {
	PARSE_ERROR = -32700,
	INVALID_REQUEST = -32600,
	METHOD_NOT_FOUND = -32601,
	INVALID_PARAMS = -32602,
	INTERNAL_ERROR = -32603,
	# Custom codes (server-defined, -32000 to -32099)
	TOOL_EXECUTION_ERROR = -32000,
	NOT_FOUND = -32001,
	PERMISSION_DENIED = -32002,
	RATE_LIMITED = -32003,
	CONNECTION_REJECTED = -32004
}

var code: int
var message: String
var data: Dictionary = {}


func _init(error_code: int, error_message: String, error_data: Dictionary = {}) -> void:
	code = error_code
	message = error_message
	data = error_data


## Creates an MCPError from standard error codes
static func create(error_code: Code, error_message: String, error_data: Dictionary = {}) -> MCPError:
	return MCPError.new(error_code, error_message, error_data)


## Converts to dictionary for JSON serialization
func to_dict() -> Dictionary:
	var result: Dictionary = {
		"code": code,
		"message": message
	}
	if not data.is_empty():
		result["data"] = data
	return result

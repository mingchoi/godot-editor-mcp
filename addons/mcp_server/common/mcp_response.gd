## MCPResponse - JSON-RPC 2.0 Response
## Represents a JSON-RPC 2.0 response.
class_name MCPResponse
extends RefCounted

var jsonrpc: String = "2.0"
var id: Variant
var result: Variant  # Present on success
var error_obj: MCPError  # Present on failure


func _init(response_id: Variant = null) -> void:
	id = response_id


## Creates a success response
static func success(response_id: Variant, response_result: Variant) -> MCPResponse:
	var response := MCPResponse.new(response_id)
	response.result = response_result
	return response


## Creates an error response
static func create_error(response_id: Variant, response_error: MCPError) -> MCPResponse:
	var response := MCPResponse.new(response_id)
	response.error_obj = response_error
	return response


## Converts to dictionary for JSON serialization
func to_dict() -> Dictionary:
	var result_dict: Dictionary = {
		"jsonrpc": jsonrpc,
		"id": id
	}
	if error_obj != null:
		result_dict["error"] = error_obj.to_dict()
	else:
		result_dict["result"] = result if result != null else {}
	return result_dict


## Converts to JSON string
func to_json() -> String:
	return JSON.stringify(to_dict())

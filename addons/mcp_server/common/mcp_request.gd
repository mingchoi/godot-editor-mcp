## MCPRequest - JSON-RPC 2.0 Request
## Represents an incoming JSON-RPC 2.0 request.
class_name MCPRequest
extends RefCounted

var jsonrpc: String = "2.0"
var id: Variant  # int, String, or null for notifications
var method: String
var params: Dictionary = {}


func _init(request_id: Variant = null, request_method: String = "", request_params: Dictionary = {}) -> void:
	id = request_id
	method = request_method
	params = request_params


## Parses a JSON string into an MCPRequest
static func from_json(json_string: String) -> MCPRequest:
	var parsed: Variant = JSON.parse_string(json_string)
	if parsed == null or not parsed is Dictionary:
		return null
	return from_dict(parsed as Dictionary)


## Creates an MCPRequest from a dictionary
static func from_dict(data: Dictionary) -> MCPRequest:
	if not data.has("jsonrpc") or data["jsonrpc"] != "2.0":
		return null
	if not data.has("method") or not data["method"] is String:
		return null

	var request := MCPRequest.new()
	request.jsonrpc = data.get("jsonrpc", "2.0")
	request.id = data.get("id")
	request.method = data["method"]
	request.params = data.get("params", {})
	return request


## Validates the request structure
func is_valid() -> bool:
	return jsonrpc == "2.0" and method is String and not method.is_empty()

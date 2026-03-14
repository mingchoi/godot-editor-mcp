## HTTP Response Builder
## Builds HTTP response strings for sending over TCP.
class_name HTTPResponseBuilder
extends RefCounted

## Build a JSON response
static func json(status_code: int, body: Dictionary) -> String:
	var body_str := JSON.stringify(body)
	var status_text := _get_status_text(status_code)

	var response := "HTTP/1.1 %d %s\r\n" % [status_code, status_text]
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: %d\r\n" % body_str.length()
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "X-API-Version: %s\r\n" % MCPConstants.HTTP_API_VERSION
	response += "Connection: close\r\n"
	response += "\r\n"
	response += body_str

	return response


## Build a success response with result
static func success(result: Dictionary, execution_time_ms: int = -1) -> String:
	var body: Dictionary = {
		"success": true,
		"result": result
	}
	if execution_time_ms >= 0:
		body["execution_time_ms"] = execution_time_ms
	return json(200, body)


## Build an error response
static func error(status_code: int, error_code: String, message: String, details: Dictionary = {}) -> String:
	var body: Dictionary = {
		"success": false,
		"error": {
			"code": error_code,
			"message": message
		}
	}
	if not details.is_empty():
		body["error"]["details"] = details
	return json(status_code, body)


## Build a 200 OK response
static func ok(body: Dictionary = {}) -> String:
	return json(200, body)


## Build a 400 Bad Request response
static func bad_request(message: String, details: Dictionary = {}) -> String:
	return error(400, MCPConstants.HTTP_ERROR_INVALID_REQUEST, message, details)


## Build a 404 Not Found response
static func not_found(message: String, details: Dictionary = {}) -> String:
	return error(404, MCPConstants.HTTP_ERROR_TOOL_NOT_FOUND, message, details)


## Build a 500 Internal Server Error response
static func internal_error(message: String, details: Dictionary = {}) -> String:
	return error(500, MCPConstants.HTTP_ERROR_EXECUTION_ERROR, message, details)


## Build a 503 Service Unavailable response
static func service_unavailable(message: String, details: Dictionary = {}) -> String:
	return error(503, MCPConstants.HTTP_ERROR_GAME_NOT_RUNNING, message, details)


## Build a 504 Gateway Timeout response
static func timeout(message: String, details: Dictionary = {}) -> String:
	return error(504, MCPConstants.HTTP_ERROR_TIMEOUT, message, details)


## Get HTTP status text for status code
static func _get_status_text(status_code: int) -> String:
	match status_code:
		200: return "OK"
		201: return "Created"
		204: return "No Content"
		400: return "Bad Request"
		401: return "Unauthorized"
		403: return "Forbidden"
		404: return "Not Found"
		405: return "Method Not Allowed"
		408: return "Request Timeout"
		413: return "Payload Too Large"
		415: return "Unsupported Media Type"
		422: return "Unprocessable Entity"
		429: return "Too Many Requests"
		500: return "Internal Server Error"
		501: return "Not Implemented"
		502: return "Bad Gateway"
		503: return "Service Unavailable"
		504: return "Gateway Timeout"
		_: return "Unknown"


## Build CORS preflight response
static func cors_preflight() -> String:
	var response := "HTTP/1.1 204 No Content\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
	response += "Access-Control-Max-Age: 86400\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	return response

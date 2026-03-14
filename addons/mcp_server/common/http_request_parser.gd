## HTTP Request Parser
## Parses HTTP requests from raw TCP stream data.
class_name HTTPRequestParser
extends RefCounted

## HTTP method enum
enum Method {
	GET,
	POST,
	PUT,
	DELETE,
	HEAD,
	OPTIONS,
	PATCH,
	UNKNOWN
}

## Parsed HTTP request structure
class ParsedRequest extends RefCounted:
	var method: Method = Method.UNKNOWN
	var path: String = ""
	var http_version: String = "HTTP/1.1"
	var headers: Dictionary = {}
	var body: String = ""
	var raw_request: String = ""

	func _to_string() -> String:
		return "HTTPRequest[%s %s %s]" % [_method_to_string(method), path, http_version]

	static func _method_to_string(m: Method) -> String:
		match m:
			Method.GET: return "GET"
			Method.POST: return "POST"
			Method.PUT: return "PUT"
			Method.DELETE: return "DELETE"
			Method.HEAD: return "HEAD"
			Method.OPTIONS: return "OPTIONS"
			Method.PATCH: return "PATCH"
			_: return "UNKNOWN"


## Parse raw HTTP request string into structured data
static func parse(raw_data: String) -> ParsedRequest:
	var request := ParsedRequest.new()
	request.raw_request = raw_data

	if raw_data.is_empty():
		return request

	var lines := raw_data.split("\r\n")
	if lines.is_empty():
		return request

	# Parse request line (e.g., "POST /execute HTTP/1.1")
	var request_line := lines[0]
	var parts := request_line.split(" ")
	if parts.size() >= 3:
		request.method = _parse_method(parts[0])
		request.path = parts[1]
		request.http_version = parts[2]

	# Parse headers
	var header_end_idx := -1
	for i in range(1, lines.size()):
		var line := lines[i]
		if line.is_empty():
			header_end_idx = i
			break
		var colon_idx := line.find(":")
		if colon_idx > 0:
			var header_name := line.substr(0, colon_idx).strip_edges().to_lower()
			var header_value := line.substr(colon_idx + 1).strip_edges()
			request.headers[header_name] = header_value

	# Parse body (after empty line)
	if header_end_idx >= 0 and header_end_idx + 1 < lines.size():
		var body_lines := lines.slice(header_end_idx + 1)
		request.body = "\r\n".join(body_lines)

	return request


## Parse HTTP method string to enum
static func _parse_method(method_str: String) -> Method:
	match method_str.to_upper():
		"GET": return Method.GET
		"POST": return Method.POST
		"PUT": return Method.PUT
		"DELETE": return Method.DELETE
		"HEAD": return Method.HEAD
		"OPTIONS": return Method.OPTIONS
		"PATCH": return Method.PATCH
		_: return Method.UNKNOWN


## Check if raw data contains a complete HTTP request
static func is_complete_request(raw_data: String) -> bool:
	# Check for header/body separator
	if not "\r\n\r\n" in raw_data:
		return false

	# Check for Content-Length header to verify body is complete
	var header_end := raw_data.find("\r\n\r\n")
	var header_section := raw_data.substr(0, header_end)

	var content_length := _get_content_length(header_section)
	if content_length < 0:
		# No Content-Length header, assume complete (no body or chunked)
		return true

	var body_start := header_end + 4
	var actual_body_length := raw_data.length() - body_start
	return actual_body_length >= content_length


## Extract Content-Length from header section
static func _get_content_length(header_section: String) -> int:
	var lines := header_section.split("\r\n")
	for line in lines:
		if line.to_lower().begins_with("content-length:"):
			var value := line.substr(line.find(":") + 1).strip_edges()
			return value.to_int()
	return -1


## Parse JSON body from request
static func parse_json_body(request: ParsedRequest) -> Dictionary:
	if request.body.is_empty():
		return {}

	var json := JSON.new()
	var parse_result := json.parse(request.body)
	if parse_result == OK:
		return json.data
	return {}

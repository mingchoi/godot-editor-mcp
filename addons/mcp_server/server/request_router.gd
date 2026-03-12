## MCP Request Router
## Routes incoming JSON-RPC requests to appropriate handlers.
class_name RequestRouter
extends RefCounted

## Signal emitted for unhandled methods (for extensibility)
signal unhandled_method(method: String, params: Dictionary)

var _tool_registry: ToolRegistry
var _logger: MCPLogger


func _init(registry: ToolRegistry, logger: MCPLogger = null) -> void:
	_tool_registry = registry
	_logger = logger


## Routes a request and returns the response
func route(request: MCPRequest) -> String:
	# Validate request
	if not request.is_valid():
		return MCPJSONRPC.create_error(
			request.id,
			MCPError.Code.INVALID_REQUEST,
			"Invalid request structure"
		)

	# Route by method
	match request.method:
		MCPConstants.METHOD_INITIALIZE:
			return _handle_initialize(request)
		MCPConstants.METHOD_INITIALIZED:
			return ""  # Notification, no response
		MCPConstants.METHOD_PING:
			return _handle_ping(request)
		MCPConstants.METHOD_TOOLS_LIST:
			return _handle_tools_list(request)
		MCPConstants.METHOD_TOOLS_CALL:
			return _handle_tools_call(request)
		MCPConstants.METHOD_PROMPTS_LIST:
			return _handle_prompts_list(request)
		MCPConstants.METHOD_RESOURCES_LIST:
			return _handle_resources_list(request)
		_:
			if _logger:
				_logger.warning("Method not found", {"method": request.method})
			return MCPJSONRPC.create_error(
				request.id,
				MCPError.Code.METHOD_NOT_FOUND,
				"Method not found: %s" % request.method
			)


## Handles ping requests
func _handle_ping(request: MCPRequest) -> String:
	return ResponseBuilder.jsonrpc_success(request.id, ResponseBuilder.ping_response())


## Handles initialize requests (MCP handshake)
func _handle_initialize(request: MCPRequest) -> String:
	var result := {
		"protocolVersion": MCPConstants.MCP_VERSION,
		"capabilities": {
			"tools": {
				"listChanged": false
			}
		},
		"serverInfo": {
			"name": MCPConstants.SERVER_NAME,
			"version": MCPConstants.SERVER_VERSION
		}
	}
	return ResponseBuilder.jsonrpc_success(request.id, result)


## Handles prompts/list requests (not supported)
func _handle_prompts_list(request: MCPRequest) -> String:
	return ResponseBuilder.jsonrpc_success(request.id, {"prompts": []})


## Handles resources/list requests (not supported)
func _handle_resources_list(request: MCPRequest) -> String:
	return ResponseBuilder.jsonrpc_success(request.id, {"resources": []})


## Handles tools/list requests
func _handle_tools_list(request: MCPRequest) -> String:
	var tools: Array[Dictionary] = _tool_registry.list_tools()
	var result := ResponseBuilder.tools_list_response(tools)
	return ResponseBuilder.jsonrpc_success(request.id, result)


## Handles tools/call requests
func _handle_tools_call(request: MCPRequest) -> String:
	var params: Dictionary = request.params

	# Get tool name
	var tool_name: Variant = params.get("name")
	if tool_name == null or not tool_name is String:
		return MCPJSONRPC.create_error(
			request.id,
			MCPError.Code.INVALID_PARAMS,
			"Missing required parameter: name"
		)

	var name: String = tool_name as String

	# Check if tool exists
	if not _tool_registry.has_tool(name):
		return MCPJSONRPC.create_error(
			request.id,
			MCPError.Code.METHOD_NOT_FOUND,
			"Tool not found: %s" % name
		)

	# Get tool handler
	var handler: MCPToolHandler = _tool_registry.get_tool(name)

	# Get tool arguments
	var arguments: Dictionary = params.get("arguments", {})

	# Validate parameters
	var validation_errors: Array[String] = handler.validate_params(arguments)
	if not validation_errors.is_empty():
		return MCPJSONRPC.create_error(
			request.id,
			MCPError.Code.INVALID_PARAMS,
			"Invalid parameters",
			{"errors": validation_errors}
		)

	# Execute the tool
	var result: MCPToolResult = handler.execute(arguments)

	# Build and return response
	return ResponseBuilder.jsonrpc_success(request.id, result.to_response_dict())


## Sets the logger
func set_logger(logger: MCPLogger) -> void:
	_logger = logger

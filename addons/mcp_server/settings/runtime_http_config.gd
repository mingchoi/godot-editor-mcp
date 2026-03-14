## Runtime HTTP Configuration
## Configuration resource for the HTTP server in game runtime.
class_name RuntimeHTTPConfig
extends Resource

## Whether the HTTP server is enabled
@export var enabled: bool = true

## Port for HTTP server (default: 8767, different from editor MCP 8765)
@export var port: int = MCPConstants.DEFAULT_RUNTIME_HTTP_PORT

## Host binding (localhost only for security)
@export var host: String = MCPConstants.DEFAULT_HOST

## Connection timeout in milliseconds (quick fail when game not running)
@export var connection_timeout_ms: int = MCPConstants.HTTP_CONNECTION_TIMEOUT_MS

## Request timeout in milliseconds
@export var request_timeout_ms: int = MCPConstants.HTTP_REQUEST_TIMEOUT_MS

## Screenshot timeout in milliseconds (larger payload)
@export var screenshot_timeout_ms: int = MCPConstants.HTTP_SCREENSHOT_TIMEOUT_MS

## Maximum concurrent HTTP connections
@export var max_connections: int = 5


## Creates default config for runtime HTTP server
static func create_default() -> RuntimeHTTPConfig:
	var config := RuntimeHTTPConfig.new()
	config.port = MCPConstants.DEFAULT_RUNTIME_HTTP_PORT
	config.host = MCPConstants.DEFAULT_HOST
	config.connection_timeout_ms = MCPConstants.HTTP_CONNECTION_TIMEOUT_MS
	config.request_timeout_ms = MCPConstants.HTTP_REQUEST_TIMEOUT_MS
	config.screenshot_timeout_ms = MCPConstants.HTTP_SCREENSHOT_TIMEOUT_MS
	return config


## Validates the configuration
func validate() -> Array[String]:
	var errors: Array[String] = []

	if port < 1024 or port > 65535:
		errors.append("Port must be between 1024 and 65535")

	if host.is_empty():
		errors.append("Host cannot be empty")

	if connection_timeout_ms < 100 or connection_timeout_ms > 10000:
		errors.append("Connection timeout must be between 100 and 10000 ms")

	if request_timeout_ms < 1000 or request_timeout_ms > 60000:
		errors.append("Request timeout must be between 1000 and 60000 ms")

	if screenshot_timeout_ms < 1000 or screenshot_timeout_ms > 60000:
		errors.append("Screenshot timeout must be between 1000 and 60000 ms")

	if max_connections < 1 or max_connections > 20:
		errors.append("Max connections must be between 1 and 20")

	return errors


## Gets timeout for a specific tool type
func get_timeout_for_tool(tool_name: String) -> int:
	# Screenshot tools need more time
	if tool_name.begins_with("screenshot_") or tool_name.begins_with("capture_"):
		return screenshot_timeout_ms
	return request_timeout_ms

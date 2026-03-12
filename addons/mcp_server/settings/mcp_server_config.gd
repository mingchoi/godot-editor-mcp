## MCP Server Configuration
## Configuration resource for a single MCP server instance.
class_name MCPServerConfig
extends Resource

@export var enabled: bool = true
@export var port: int = 8765
@export var host: String = "127.0.0.1"
@export var token: String = ""  # Optional auth token
@export var max_connections: int = 5
@export var heartbeat_interval: float = 30.0  # seconds


## Creates default config for editor MCP server
static func default_editor_config() -> MCPServerConfig:
	var config := MCPServerConfig.new()
	config.port = MCPConstants.DEFAULT_EDITOR_PORT
	config.host = MCPConstants.DEFAULT_HOST
	return config


## Creates default config for runtime MCP server
static func default_runtime_config() -> MCPServerConfig:
	var config := MCPServerConfig.new()
	config.port = MCPConstants.DEFAULT_RUNTIME_PORT
	config.host = MCPConstants.DEFAULT_HOST
	return config


## Validates the configuration
func validate() -> Array[String]:
	var errors: Array[String] = []

	if port < 1024 or port > 65535:
		errors.append("Port must be between 1024 and 65535")

	if host.is_empty():
		errors.append("Host cannot be empty")

	if max_connections < 1 or max_connections > 100:
		errors.append("Max connections must be between 1 and 100")

	if heartbeat_interval < 1.0 or heartbeat_interval > 300.0:
		errors.append("Heartbeat interval must be between 1 and 300 seconds")

	return errors


## Checks if authentication is required
func requires_auth() -> bool:
	return not token.is_empty()

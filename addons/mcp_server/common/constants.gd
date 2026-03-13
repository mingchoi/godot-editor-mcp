## MCP Server Constants
## Shared configuration values for the MCP server implementation.
class_name MCPConstants
extends RefCounted

## Protocol version for JSON-RPC
const PROTOCOL_VERSION: String = "2.0"

## Default port for Editor MCP server
const DEFAULT_EDITOR_PORT: int = 8765

## Default port for Runtime MCP server
const DEFAULT_RUNTIME_PORT: int = 8766

## Default host binding (localhost only for security)
const DEFAULT_HOST: String = "127.0.0.1"

## Maximum concurrent connections per server
const MAX_CONNECTIONS: int = 5

## Heartbeat interval in seconds
const HEARTBEAT_INTERVAL: float = 30.0

## Request timeout in milliseconds
const REQUEST_TIMEOUT_MS: int = 30000

## Maximum screenshot width for capture tools
const SCREENSHOT_MAX_WIDTH: int = 1920

## Default screenshot quality (for lossy formats)
const SCREENSHOT_QUALITY: int = 85

## Rate limit: requests per minute per connection
const RATE_LIMIT_PER_MINUTE: int = 100

## MCP protocol version
const MCP_VERSION: String = "2024-11-05"

## MCP method names
const METHOD_INITIALIZE: String = "initialize"
const METHOD_INITIALIZED: String = "notifications/initialized"
const METHOD_TOOLS_LIST: String = "tools/list"
const METHOD_TOOLS_CALL: String = "tools/call"
const METHOD_PROMPTS_LIST: String = "prompts/list"
const METHOD_RESOURCES_LIST: String = "resources/list"
const METHOD_PING: String = "ping"

## Server info
const SERVER_NAME: String = "godot-editor-mcp"
const SERVER_VERSION: String = "1.0.0"

## HTTP Relay Constants (Feature 005)
## Default port for Runtime HTTP server (game side)
const DEFAULT_RUNTIME_HTTP_PORT: int = 8767

## HTTP connection timeout in milliseconds
const HTTP_CONNECTION_TIMEOUT_MS: int = 500

## HTTP request timeout in milliseconds
const HTTP_REQUEST_TIMEOUT_MS: int = 5000

## HTTP screenshot timeout in milliseconds (larger payload)
const HTTP_SCREENSHOT_TIMEOUT_MS: int = 10000

## HTTP error codes
const HTTP_ERROR_GAME_NOT_RUNNING: String = "GAME_NOT_RUNNING"
const HTTP_ERROR_TOOL_NOT_FOUND: String = "TOOL_NOT_FOUND"
const HTTP_ERROR_INVALID_PARAMS: String = "INVALID_PARAMS"
const HTTP_ERROR_EXECUTION_ERROR: String = "EXECUTION_ERROR"
const HTTP_ERROR_TIMEOUT: String = "TIMEOUT"
const HTTP_ERROR_INVALID_REQUEST: String = "INVALID_REQUEST"

## HTTP API version
const HTTP_API_VERSION: String = "1.0.0"


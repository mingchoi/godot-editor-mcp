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

## MCP method names
const METHOD_TOOLS_LIST: String = "tools/list"
const METHOD_TOOLS_CALL: String = "tools/call"
const METHOD_PING: String = "ping"


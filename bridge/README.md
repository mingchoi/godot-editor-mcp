# Godot MCP Stdio-to-WebSocket Bridge

A simple Node.js bridge that forwards stdio (MCP protocol) to WebSocket for connecting Claude Desktop to the Godot MCP Server.

## Installation

```bash
cd mcp-stdio-websocket-bridge
npm install
```

## Usage

### Direct usage
```bash
node index.js ws://127.0.0.1:8765
```

### Claude Desktop Configuration

Add to your Claude Desktop config (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": [
        "/path/to/godot-editor-mcp/mcp-stdio-websocket-bridge/index.js",
        "ws://127.0.0.1:8765"
      ]
    }
  }
}
```

### Using npm script (after npm link)

```bash
npm install -g .
```

Then in config:
```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "godot-mcp-bridge",
      "args": ["ws://127.0.0.1:8765"]
    }
  }
}
```

## Architecture

```
Claude Desktop <--(stdio)--> Bridge <--(WebSocket)--> Godot MCP Server (port 8765)
```

The bridge acts as a transparent proxy, converting between:
- **stdio**: Line-delimited JSON-RPC messages (MCP protocol over stdio)
- **WebSocket**: Binary WebSocket frames with JSON-RPC messages (MCP protocol over WebSocket)

## Features

- Auto-reconnect with 2-second backoff
- Message queuing while WebSocket is connecting
- Graceful shutdown on SIGINT/SIGTERM
- Transparent message forwarding (no protocol modification)

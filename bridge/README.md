# MCP stdio-to-WebSocket Bridge

Connects MCP clients (Claude Code, etc.) to the Godot Editor WebSocket MCP server.

## Usage

### Claude Code Configuration

Add to `~/.claude/mcp_servers.json`:

```json
{
  "mcpServers": {
    "godot-editor": {
      "command": "node",
      "args": ["/path/to/godot-editor-mcp/bridge/index.mjs"]
    }
  }
}
```

### Options

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `MCP_WS_PORT` | 8765 | WebSocket port |
| `MCP_WS_HOST` | localhost | WebSocket host |

Example with custom port:
```json
{
  "mcpServers": {
    "godot-editor": {
      "command": "node",
      "args": ["/path/to/godot-editor-mcp/bridge/index.mjs"],
      "env": {
        "MCP_WS_PORT": "9000"
      }
    }
  }
}
```

### Testing

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node index.mjs
```

## Architecture

```
Claude Code <--stdio--> Bridge <--WebSocket:8765--> Godot Editor
```

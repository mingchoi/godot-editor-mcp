#!/usr/bin/env node

/**
 * MCP Stdio-to-WebSocket Bridge
 *
 * Transparent proxy for MCP protocol: forwards stdio (Claude Desktop) to WebSocket (Godot).
 *
 * Architecture:
 *   Claude Desktop <--(stdio)--> Bridge <--(WebSocket)--> Godot MCP Server
 *
 * Usage:
 *   node index.js [port]
 *
 * Or add to Claude Desktop config:
 *   "mcpServers": {
 *     "godot-mcp": {
 *       "command": "node",
 *       "args": ["/path/to/godot-editor-mcp/bridge/index.js", "8765"]
 *     }
 *   }
 */

import { createInterface } from 'readline';
import { WebSocket } from 'ws';

// Default port (can be overridden by argument)
const DEFAULT_PORT = 8765;
const DEFAULT_HOST = '127.0.0.1';

// Parse port from command line argument
const arg = process.argv[2];
let port, wsUrl;

if (arg) {
  // Check if it's a full URL or just a port number
  if (arg.startsWith('ws://') || arg.startsWith('wss://')) {
    wsUrl = arg;
    // Extract port from URL if possible
    const urlMatch = arg.match(/ws:\/\/[^:]+:(\d+)/);
    port = urlMatch ? parseInt(urlMatch[1]) : DEFAULT_PORT;
  } else {
    // Assume it's a port number
    port = parseInt(arg);
    if (isNaN(port)) {
      console.error('Invalid port number:', arg);
      process.exit(1);
    }
    wsUrl = `ws://${DEFAULT_HOST}:${port}`;
  }
} else {
  port = DEFAULT_PORT;
  wsUrl = `ws://${DEFAULT_HOST}:${port}`;
}

// Bridge state
let ws = null;
let reconnectTimer = null;
let isWsReady = false;
let pendingStdinMessages = []; // Queue messages until WebSocket is ready

/**
 * Initialize WebSocket connection
 */
function connect() {
  ws = new WebSocket(wsUrl);

  ws.on('open', () => {
    isWsReady = true;
    // Send any queued stdin messages
    while (pendingStdinMessages.length > 0) {
      const msg = pendingStdinMessages.shift();
      ws.send(msg);
    }
  });

  ws.on('message', (data) => {
    console.log(data.toString());
  });

  ws.on('error', () => {
    // Silent - will trigger reconnect via close
  });

  ws.on('close', () => {
    isWsReady = false;
    scheduleReconnect();
  });
}

/**
 * Schedule reconnection attempt
 */
function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connect();
  }, 2000);
}

/**
 * Handle message from stdin (from Claude Desktop)
 */
function handleStdinRequest(line) {
  if (isWsReady && ws && ws.readyState === WebSocket.OPEN) {
    ws.send(line);
  } else {
    pendingStdinMessages.push(line);
  }
}

/**
 * Main entry point
 */
async function main() {
  connect();

  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  for await (const line of rl) {
    handleStdinRequest(line);
  }
}

// Handle shutdown
process.on('SIGINT', () => {
  if (ws) ws.close();
  process.exit(0);
});

process.on('SIGTERM', () => {
  if (ws) ws.close();
  process.exit(0);
});

main().catch(() => {});

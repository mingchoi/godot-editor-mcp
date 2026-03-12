#!/usr/bin/env node
/**
 * MCP stdio-to-WebSocket Bridge
 *
 * Bridges MCP stdio transport (used by Claude Code) to WebSocket transport
 * (used by Godot Editor MCP plugin).
 *
 * Usage:
 *   node mcp-stdio-ws-bridge.mjs [--port 8765] [--host localhost]
 *
 * Environment variables:
 *   MCP_WS_PORT - WebSocket port (default: 8765)
 *   MCP_WS_HOST - WebSocket host (default: localhost)
 */

import WebSocket from 'ws';
import { createInterface } from 'readline';

const DEFAULT_PORT = 8765;
const DEFAULT_HOST = 'localhost';

// Parse arguments
const args = process.argv.slice(2);
let port = parseInt(process.env.MCP_WS_PORT || DEFAULT_PORT);
let host = process.env.MCP_WS_HOST || DEFAULT_HOST;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--port' && args[i + 1]) {
    port = parseInt(args[i + 1]);
    i++;
  } else if (args[i] === '--host' && args[i + 1]) {
    host = args[i + 1];
    i++;
  }
}

const wsUrl = `ws://${host}:${port}`;

// Track pending requests
const pendingRequests = new Map();
let requestId = 0;

// WebSocket connection
let ws = null;
let isConnecting = false;
let messageQueue = [];

function connect() {
  if (isConnecting || (ws && ws.readyState === WebSocket.OPEN)) {
    return;
  }

  isConnecting = true;

  ws = new WebSocket(wsUrl);

  ws.on('open', () => {
    isConnecting = false;
    console.error(`[Bridge] Connected to ${wsUrl}`);

    // Send queued messages
    while (messageQueue.length > 0) {
      const msg = messageQueue.shift();
      ws.send(msg);
    }
  });

  ws.on('message', (data) => {
    try {
      const response = data.toString();
      const parsed = JSON.parse(response);

      // Forward to stdout
      console.log(response);

      // Resolve pending request if applicable
      if (parsed.id !== undefined) {
        pendingRequests.delete(parsed.id);
      }
    } catch (err) {
      console.error(`[Bridge] Error parsing response: ${err.message}`);
    }
  });

  ws.on('close', () => {
    console.error(`[Bridge] Disconnected from ${wsUrl}`);
    ws = null;

    // Attempt reconnect after 1 second
    setTimeout(connect, 1000);
  });

  ws.on('error', (err) => {
    console.error(`[Bridge] WebSocket error: ${err.message}`);
    isConnecting = false;
  });
}

// Connect immediately
connect();

// Read from stdin
const rl = createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', (line) => {
  if (!line.trim()) return;

  try {
    const request = JSON.parse(line);

    // Validate it's a valid JSON-RPC message
    if (request.jsonrpc !== '2.0') {
      console.error('[Bridge] Invalid JSON-RPC message');
      return;
    }

    const messageStr = JSON.stringify(request);

    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(messageStr);
    } else {
      // Queue message for when connection is ready
      messageQueue.push(messageStr);
      console.error(`[Bridge] Queued message (connection not ready)`);
    }
  } catch (err) {
    console.error(`[Bridge] Error parsing stdin: ${err.message}`);
  }
});

rl.on('close', () => {
  console.error('[Bridge] stdin closed, exiting');
  if (ws) {
    ws.close();
  }
  process.exit(0);
});

// Handle shutdown
process.on('SIGINT', () => {
  console.error('[Bridge] Received SIGINT, shutting down');
  if (ws) {
    ws.close();
  }
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.error('[Bridge] Received SIGTERM, shutting down');
  if (ws) {
    ws.close();
  }
  process.exit(0);
});

console.error(`[Bridge] MCP stdio-to-WebSocket bridge started`);
console.error(`[Bridge] Target: ${wsUrl}`);

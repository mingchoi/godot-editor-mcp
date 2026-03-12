#!/usr/bin/env node
/**
 * MCP WebSocket Client Test Script
 * Run this while Godot Editor is open with the MCP plugin enabled.
 *
 * Usage:
 *   npm install ws
 *   node test_mcp_client.mjs
 */

import WebSocket from "ws";

const URI = "ws://localhost:8765";

async function sendMessage(ws, id, method, params = null) {
  return new Promise((resolve, reject) => {
    const message = { jsonrpc: "2.0", id, method };
    if (params) message.params = params;

    const handler = (data) => {
      ws.off("message", handler);
      resolve(JSON.parse(data.toString()));
    };
    ws.on("message", handler);
    ws.send(JSON.stringify(message));
  });
}

async function main() {
  console.log(`Connecting to ${URI}...`);

  const ws = new WebSocket(URI);

  ws.on("error", (err) => {
    console.log("❌ Connection failed. Make sure:");
    console.log("   1. Godot Editor is running");
    console.log("   2. MCP plugin is enabled");
    console.log("   3. Check Godot Output for 'Server started' message");
    process.exit(1);
  });

  ws.on("open", async () => {
    console.log("✅ Connected!\n");

    try {
      // 1. List available tools
      console.log("📋 Requesting tools list...");
      let response = await sendMessage(ws, 1, "tools/list");
      console.log(`Response: ${JSON.stringify(response, null, 2)}\n`);

      // 2. Ping test
      console.log("🏓 Sending ping...");
      response = await sendMessage(ws, 2, "ping");
      console.log(`Response: ${JSON.stringify(response, null, 2)}\n`);

      // 3. Call a tool - get current scene
      console.log("🔧 Calling tool: scene_get_current...");
      response = await sendMessage(ws, 3, "tools/call", {
        name: "scene_get_current",
        arguments: {},
      });
      console.log(`Response: ${JSON.stringify(response, null, 2)}\n`);

      console.log("✅ All tests completed!");
      ws.close();
      process.exit(0);
    } catch (err) {
      console.error("❌ Error:", err);
      ws.close();
      process.exit(1);
    }
  });
}

main();

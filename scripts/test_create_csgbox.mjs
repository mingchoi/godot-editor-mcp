#!/usr/bin/env node
/**
 * Test script: Create a CSGBox3D in the current scene
 *
 * Usage:
 *   node test_create_csgbox.mjs
 */

import WebSocket from "ws";

const URI = "ws://localhost:8765";

let messageId = 1;

async function send(ws, method, params = null) {
  return new Promise((resolve, reject) => {
    const message = { jsonrpc: "2.0", id: messageId++, method };
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
    console.log("❌ Connection failed. Make sure Godot is running with MCP plugin enabled.");
    process.exit(1);
  });

  ws.on("open", async () => {
    console.log("✅ Connected!\n");

    try {
      // 1. Get current scene
      console.log("📋 Getting current scene...");
      let response = await send(ws, "tools/call", {
        name: "scene_get_current",
        arguments: {},
      });

      if (response.error) {
        console.log("❌ No scene open. Please open a scene in Godot first.");
        ws.close();
        process.exit(1);
      }

      const sceneData = response.result?.content?.[0]?.data || {};
      const scenePath = sceneData.path || ".";
      console.log(`   Scene: ${sceneData.name || "unknown"}`);
      console.log(`   Path: ${scenePath}\n`);

      // 2. Create CSGBox3D (with default size since Vector3 can't be set via JSON)
      console.log("📦 Creating CSGBox3D...");
      response = await send(ws, "tools/call", {
        name: "node_create",
        arguments: {
          type: "CSGBox3D",
          name: "TestBox",
          parent: ".", // Scene root
        },
      });

      if (response.error) {
        console.log("❌ Failed to create CSGBox3D:");
        console.log(`   ${JSON.stringify(response.error, null, 2)}`);
      } else {
        console.log("✅ CSGBox3D created!");
        console.log(`   ${JSON.stringify(response.result, null, 2)}`);
      }

      // 3. List children to verify
      console.log("\n📋 Verifying scene children...");
      response = await send(ws, "tools/call", {
        name: "node_list_children",
        arguments: {
          path: ".",
          recursive: false,
        },
      });

      const children = response.result?.content?.[0]?.data?.children || [];
      console.log(`   Found ${children.length} children:`);
      for (const child of children) {
        console.log(`   - ${child.name} (${child.type})`);
      }

      console.log("\n✅ Done! Check Godot Editor to see the CSGBox3D.");
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

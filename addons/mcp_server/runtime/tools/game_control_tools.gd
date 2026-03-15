## Game Control Tools
## MCP tools for controlling game state (pause, resume, time scale).
extends RefCounted
class_name GameControlTools

const MCPToolRegistry = preload("res://addons/mcp_server/tool_registry.gd")

## Registers all game control tools
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted) -> RefCounted:
	var tools := GameControlTools.new()

	registry.register_tool(
		_create_tool_def("runtime_game_pause", "Pauses the game", {}, [], {
			"type": "object",
			"properties": {
				"paused": {"type": "boolean", "description": "Whether the game is paused"}
			}
		}),
		tools._execute_pause
	)

	registry.register_tool(
		_create_tool_def("runtime_game_resume", "Resumes the game", {}, [], {
			"type": "object",
			"properties": {
				"paused": {"type": "boolean", "description": "Whether the game is paused"}
			}
		}),
		tools._execute_resume
	)

	registry.register_tool(
		_create_tool_def("runtime_game_set_time_scale", "Sets the game time scale", {
			"scale": {
				"type": "number",
				"minimum": 0.0,
				"maximum": 10.0,
				"description": "Time scale (1.0 = normal, 0.5 = half speed, 2.0 = double speed)"
			}
		}, ["scale"], {
			"type": "object",
			"properties": {
				"scale": {"type": "number", "description": "New time scale"},
				"previous_scale": {"type": "number", "description": "Previous time scale"}
			}
		}),
		tools._execute_set_time_scale
	)

	registry.register_tool(
		_create_tool_def("runtime_game_is_running", "Checks if the game is currently running and returns state", {}, [], {
			"type": "object",
			"properties": {
				"running": {"type": "boolean", "description": "Whether the game is running"},
				"paused": {"type": "boolean", "description": "Whether the game is paused"},
				"time_scale": {"type": "number", "description": "Current time scale"},
				"current_scene": {"type": "string", "description": "Current scene path"},
				"fps": {"type": "number", "description": "Current FPS"}
			}
		}),
		tools._execute_is_running
	)

	return tools


# --- Helper Methods ---

func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


# --- Tool Implementations ---

func _execute_pause(_args: Dictionary = {}) -> Dictionary:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return {"content": [{"type": "text", "text": "Error: Scene tree not available"}], "isError": true}

	if tree.paused:
		return MCPToolRegistry.create_response("Game is already paused", {
			"was_paused": true
		})

	tree.paused = true

	return MCPToolRegistry.create_response("Game paused", {
		"paused": true
	})


func _execute_resume(_args: Dictionary = {}) -> Dictionary:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return {"content": [{"type": "text", "text": "Error: Scene tree not available"}], "isError": true}

	if not tree.paused:
		return MCPToolRegistry.create_response("Game is not paused", {
			"was_paused": false
		})

	tree.paused = false

	return MCPToolRegistry.create_response("Game resumed", {
		"paused": false
	})


func _execute_set_time_scale(args: Dictionary) -> Dictionary:
	var scale: float = args.get("scale", 1.0)

	# Clamp to valid range
	scale = clampf(scale, 0.0, 10.0)

	var previous_scale: float = Engine.time_scale
	Engine.time_scale = scale

	return MCPToolRegistry.create_response("Time scale set to %.2f" % scale, {
		"scale": scale,
		"previous_scale": previous_scale
	})


func _execute_is_running(_args: Dictionary = {}) -> Dictionary:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return MCPToolRegistry.create_response("No scene tree available", {
			"running": false,
			"paused": false,
			"time_scale": 1.0,
			"current_scene": "",
			"fps": 0
		})

	var current_scene: Node = tree.current_scene
	var scene_path: String = ""
	if current_scene != null:
		if current_scene.scene_file_path != null:
			scene_path = current_scene.scene_file_path
		else:
			scene_path = current_scene.name

	var data: Dictionary = {
		"running": true,
		"paused": tree.paused,
		"time_scale": Engine.time_scale,
		"current_scene": scene_path,
		"fps": Performance.get_monitor(Performance.TIME_FPS)
	}

	var status_text: String = "Game is %s" % ("paused" if tree.paused else "running")

	return MCPToolRegistry.create_response(status_text, data)


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array, output_schema: Dictionary = {}) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	var tool_def: Dictionary = {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}
	if not output_schema.is_empty():
		tool_def["outputSchema"] = output_schema
	return tool_def

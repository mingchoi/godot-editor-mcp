## Game Control Tools
## MCP tools for controlling game state (pause, resume, time scale).
extends RefCounted
class_name GameControlTools

## Registers all game control tools
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted) -> RefCounted:
	var tools := GameControlTools.new()

	registry.register_tool(
		_create_tool_def("runtime_game_pause", "Pauses the game", {}, []),
		tools._execute_pause
	)

	registry.register_tool(
		_create_tool_def("runtime_game_resume", "Resumes the game", {}, []),
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
		}, ["scale"]),
		tools._execute_set_time_scale
	)

	registry.register_tool(
		_create_tool_def("runtime_game_is_running", "Checks if the game is currently running and returns state", {}, []),
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
		return {
			"content": [{"type": "text", "text": "Game is already paused"}],
			"isError": false,
			"data": {"was_paused": true}
		}

	tree.paused = true

	return {
		"content": [{"type": "text", "text": "Game paused"}],
		"isError": false,
		"data": {"paused": true}
	}


func _execute_resume(_args: Dictionary = {}) -> Dictionary:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return {"content": [{"type": "text", "text": "Error: Scene tree not available"}], "isError": true}

	if not tree.paused:
		return {
			"content": [{"type": "text", "text": "Game is not paused"}],
			"isError": false,
			"data": {"was_paused": false}
		}

	tree.paused = false

	return {
		"content": [{"type": "text", "text": "Game resumed"}],
		"isError": false,
		"data": {"paused": false}
	}


func _execute_set_time_scale(args: Dictionary) -> Dictionary:
	var scale: float = args.get("scale", 1.0)

	# Clamp to valid range
	scale = clampf(scale, 0.0, 10.0)

	var previous_scale: float = Engine.time_scale
	Engine.time_scale = scale

	return {
		"content": [{"type": "text", "text": "Time scale set to %.2f" % scale}],
		"isError": false,
		"data": {
			"scale": scale,
			"previous_scale": previous_scale
		}
	}


func _execute_is_running(_args: Dictionary = {}) -> Dictionary:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return {
			"content": [{"type": "text", "text": "No scene tree available"}],
			"isError": false,
			"data": {
				"running": false,
				"paused": false,
				"time_scale": 1.0,
				"current_scene": "",
				"fps": 0
			}
		}

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

	return {
		"content": [{"type": "text", "text": status_text}],
		"isError": false,
		"data": data
	}


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}

## Game Control Tools
## MCP tools for controlling game state (pause, resume, time scale).
extends RefCounted
class_name GameControlTools

const TOOL_PAUSE := "game_pause"
const TOOL_RESUME := "game_resume"
const TOOL_SET_TIME_SCALE := "game_set_time_scale"
const TOOL_IS_RUNNING := "game_is_running"

var _logger: MCPLogger
var _editor_interface: EditorInterface


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("GameControlTools") if logger else MCPLogger.new("[GameControlTools]")
	_editor_interface = editor_interface


## Registers all game control tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_pause_tool())
	registry.register(_create_resume_tool())
	registry.register(_create_set_time_scale_tool())
	registry.register(_create_is_running_tool())


func _create_pause_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_PAUSE,
			"Pauses the game",
			{},
			[]
		)
	return MCPToolHandler.new(definition, _execute_pause)


func _create_resume_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_RESUME,
			"Resumes the game",
			{},
			[]
		)
	return MCPToolHandler.new(definition, _execute_resume)


func _create_set_time_scale_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_SET_TIME_SCALE,
			"Sets the game time scale",
			{
				"scale": {
					"type": "number",
					"minimum": 0.0,
					"maximum": 10.0,
					"description": "Time scale (1.0 = normal, 0.5 = half speed, 2.0 = double speed)"
				}
			},
			["scale"]
		)
	return MCPToolHandler.new(definition, _execute_set_time_scale)


func _create_is_running_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
			TOOL_IS_RUNNING,
			"Checks if the game is currently running and returns state",
			{},
			[]
		)
	return MCPToolHandler.new(definition, _execute_is_running)


# --- Tool Implementations ---

func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _execute_pause(_params: Dictionary = {}) -> MCPToolResult:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return MCPToolResult.error("Scene tree not available", MCPError.Code.TOOL_EXECUTION_ERROR)

	if tree.paused:
		return MCPToolResult.text("Game is already paused", {"was_paused": true})

	tree.paused = true
	_logger.info("Game paused")

	return MCPToolResult.text("Game paused", {"paused": true})


func _execute_resume(_params: Dictionary = {}) -> MCPToolResult:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return MCPToolResult.error("Scene tree not available", MCPError.Code.TOOL_EXECUTION_ERROR)

	if not tree.paused:
		return MCPToolResult.text("Game is not paused", {"was_paused": false})

	tree.paused = false
	_logger.info("Game resumed")

	return MCPToolResult.text("Game resumed", {"paused": false})


func _execute_set_time_scale(params: Dictionary) -> MCPToolResult:
	var scale: float = params.get("scale", 1.0)

	# Clamp to valid range
	scale = clampf(scale, 0.0, 10.0)

	var previous_scale: float = Engine.time_scale
	Engine.time_scale = scale

	_logger.info("Time scale set", {"scale": scale, "previous": previous_scale})

	return MCPToolResult.text("Time scale set to %.2f" % scale, {
		"scale": scale,
		"previous_scale": previous_scale
	})


func _execute_is_running(_params: Dictionary = {}) -> MCPToolResult:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return MCPToolResult.text("No scene tree available", {
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
	return MCPToolResult.text(status_text, data)

## Runtime MCP Server Autoload
## Runs MCPServer in the game runtime
extends Node

const MCPServerClass = preload("res://addons/mcp_server/mcp_server.gd")

var _mcp_server: MCPServerClass
var _port: int = 8766  # Different port from editor (8765) to avoid conflicts
var _tool_objects: Array[RefCounted] = []


func _ready() -> void:
	print("[Runtime MCP Server] Initializing on port %d..." % _port)
	_mcp_server = MCPServerClass.new(_port)

	if _mcp_server.start():
		print("[Runtime MCP Server] Started on port %d (ws://127.0.0.1:%d)" % [_port, _port])
		_register_tools()
	else:
		push_error("[Runtime MCP Server] Failed to start on port %d" % _port)


func _process(_delta: float) -> void:
	if _mcp_server and _mcp_server.is_running():
		_mcp_server.poll()


## Stop the server (call before game quits)
func stop_server() -> void:
	if _mcp_server:
		_mcp_server.stop()
		print("[Runtime MCP Server] Stopped")


func _register_tools() -> void:
	var registry = _mcp_server.get_tool_registry()

	# Import runtime tool classes
	const RuntimeQueryToolsClass = preload("res://addons/mcp_server/runtime/tools/runtime_query_tools.gd")
	const RuntimeNodeToolsClass = preload("res://addons/mcp_server/runtime/tools/runtime_node_tools.gd")
	const InputToolsClass = preload("res://addons/mcp_server/runtime/tools/input_tools.gd")
	const CaptureToolsClass = preload("res://addons/mcp_server/runtime/tools/capture_tools.gd")
	const GameControlToolsClass = preload("res://addons/mcp_server/runtime/tools/game_control_tools.gd")

	# Register tools using static register functions
	_tool_objects.append(RuntimeQueryToolsClass.register(registry))
	_tool_objects.append(RuntimeNodeToolsClass.register(registry))
	_tool_objects.append(InputToolsClass.register(registry))
	_tool_objects.append(CaptureToolsClass.register(registry))
	_tool_objects.append(GameControlToolsClass.register(registry))

	print("[Runtime MCP Server] Registered %d tools" % registry.size())

@tool
## Runtime MCP Plugin
## Registers the RuntimeMCP autoload singleton for game runtime
extends EditorPlugin


func _enter_tree() -> void:
	# Register the RuntimeMCP autoload
	var autoload_script = preload("res://addons/mcp_server/runtime/runtime_mcp_autoload.gd")
	add_autoload_singleton("RuntimeMCP", autoload_script)

	print("[Runtime MCP Plugin] Registered RuntimeMCP autoload singleton")


func _exit_tree() -> void:
	# Remove the autoload when plugin is disabled
	remove_autoload_singleton("RuntimeMCP")

	print("[Runtime MCP Plugin] Removed RuntimeMCP autoload singleton")

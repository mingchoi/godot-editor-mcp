## Runtime MCP WebSocket Server
## Lightweight WebSocket-based MCP server for game runtime
extends Node

const SimpleToolRegistryClass = preload("res://addons/mcp_server/simple_tool_registry.gd")

var _tcp_server: TCPServer
var _peers: Dictionary = {}
var _tool_registry: SimpleToolRegistry
var _port: int
var _host: String

const SERVER_INFO = {
	"name": "godot-runtime-mcp-server",
	"version": "2.0.0"
}

var _next_peer_id: int = 1


func _init(port: int = 8766, host: String = "127.0.0.1") -> void:
	_port = port
	_host = host
	_tool_registry = SimpleToolRegistryClass.new()


## Start the WebSocket server
func start() -> bool:
	_tcp_server = TCPServer.new()
	var err = _tcp_server.listen(_port, _host)
	return err == OK


## Stop the WebSocket server
func stop() -> void:
	if _tcp_server and _tcp_server.is_listening():
		_tcp_server.stop()

	for peer_id in _peers.keys():
		var peer_data = _peers[peer_id]
		peer_data.websocket.close()

	_peers.clear()


## Poll for network activity (call from _process)
func poll() -> void:
	if _tcp_server == null:
		return

	while _tcp_server.is_connection_available():
		var tcp_conn = _tcp_server.take_connection()
		_setup_websocket_peer(tcp_conn)

	var peers_to_remove := []
	for peer_id in _peers:
		var peer_data = _peers[peer_id]
		var ws: WebSocketPeer = peer_data.websocket

		ws.poll()

		var state = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			_process_peer_messages(peer_id, ws)
		elif state == WebSocketPeer.STATE_CLOSING or state == WebSocketPeer.STATE_CLOSED:
			peers_to_remove.append(peer_id)

	for peer_id in peers_to_remove:
		var peer_data = _peers[peer_id]
		peer_data.websocket.close()
		_peers.erase(peer_id)


## Check if server is running
func is_running() -> bool:
	return _tcp_server != null and _tcp_server.is_listening()


## Get the tool registry for registering tools
func get_tool_registry() -> SimpleToolRegistry:
	return _tool_registry


## Setup a new WebSocket peer connection
func _setup_websocket_peer(tcp: StreamPeerTCP) -> void:
	var ws = WebSocketPeer.new()
	var ws_id = _next_peer_id
	_next_peer_id += 1

	ws.accept_stream(tcp)

	_peers[ws_id] = {
		"websocket": ws,
		"state": "connecting"
	}

	print("[Runtime MCP] Client connected: %d" % ws_id)


## Process messages from a peer
func _process_peer_messages(peer_id: int, ws: WebSocketPeer) -> void:
	if _peers[peer_id]["state"] == "connecting":
		_peers[peer_id]["state"] = "connected"

	while ws.get_available_packet_count() > 0:
		var packet = ws.get_packet()
		if packet.is_empty():
			continue

		var text = packet.get_string_from_utf8()
		_handle_message(peer_id, text)


## Handle an incoming JSON-RPC message
func _handle_message(peer_id: int, message_text: String) -> void:
	var json = JSON.new()
	if json.parse(message_text) != OK:
		_send_error(peer_id, null, "Invalid JSON")
		return

	var data = json.data
	if not data is Dictionary:
		_send_error(peer_id, null, "Message must be a JSON object")
		return

	var request_id = data.get("id")
	var method = data.get("method")
	var params = data.get("params", {})

	match method:
		"initialize":
			_handle_initialize(peer_id, request_id)
		"notifications/initialized":
			_peers[peer_id]["state"] = "ready"
		"tools/list":
			_handle_tools_list(peer_id, request_id)
		"tools/call":
			_handle_tools_call(peer_id, request_id, params)
		_:
			_send_error(peer_id, request_id, "Unknown method: %s" % method, -32601)


## Handle initialize request
func _handle_initialize(peer_id: int, request_id) -> void:
	_send_message(peer_id, {
		"jsonrpc": "2.0",
		"id": request_id,
		"result": {
			"protocolVersion": "2025-03-26",
			"serverInfo": SERVER_INFO,
			"capabilities": {
				"tools": {}
			}
		}
	})


## Handle tools/list request
func _handle_tools_list(peer_id: int, request_id) -> void:
	_send_message(peer_id, {
		"jsonrpc": "2.0",
		"id": request_id,
		"result": {
			"tools": _tool_registry.get_tools()
		}
	})


## Handle tools/call request
func _handle_tools_call(peer_id: int, request_id, params: Dictionary) -> void:
	var tool_name = params.get("name", "")
	var arguments = params.get("arguments", {})

	if not _tool_registry.has_tool(tool_name):
		_send_error(peer_id, request_id, "Unknown tool: %s" % tool_name, -32601)
		return

	var result = _tool_registry.call_tool(tool_name, arguments)
	_send_message(peer_id, {
		"jsonrpc": "2.0",
		"id": request_id,
		"result": result
	})


## Send a message to a peer
func _send_message(peer_id: int, data: Dictionary) -> void:
	if not _peers.has(peer_id):
		return

	var peer_data = _peers[peer_id]
	var ws: WebSocketPeer = peer_data.websocket
	ws.send_text(JSON.stringify(data))


## Send an error response
func _send_error(peer_id: int, request_id, message: String, code: int = -32603) -> void:
	_send_message(peer_id, {
		"jsonrpc": "2.0",
		"id": request_id,
		"error": {
			"code": code,
			"message": message
		}
	})

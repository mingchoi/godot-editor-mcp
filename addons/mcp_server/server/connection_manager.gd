## Connection Manager
## Manages all WebSocket connections for a server.
class_name ConnectionManager
extends RefCounted

## Signal emitted when a new client connects
signal client_connected(conn_id: int)
## Signal emitted when a client disconnects
signal client_disconnected(conn_id: int)
## Signal emitted when a message is received
signal message_received(conn_id: int, message: String)

var _connections: Dictionary = {}  # int -> WSConnection
var _next_id: int = 1
var _max_connections: int = MCPConstants.MAX_CONNECTIONS
var _logger: MCPLogger


func _init(max_conn: int = MCPConstants.MAX_CONNECTIONS, logger: MCPLogger = null) -> void:
	_max_connections = max_conn
	_logger = logger


## Adds a new connection from a WebSocketPeer
func add_connection(ws: WebSocketPeer) -> int:
	if _connections.size() >= _max_connections:
		if _logger:
			_logger.warning("Connection rejected: maximum reached", {"max": _max_connections})
		return -1

	var conn_id: int = _next_id
	var conn := WSConnection.new(conn_id, ws, _logger)
	_connections[conn_id] = conn
	_next_id += 1

	if _logger:
		_logger.info("Client connected", {"conn_id": conn_id, "total": _connections.size()})

	client_connected.emit(conn_id)
	return conn_id


## Removes a connection by ID
func remove_connection(conn_id: int) -> bool:
	if not _connections.has(conn_id):
		return false

	var conn: WSConnection = _connections[conn_id]
	conn.close()
	_connections.erase(conn_id)

	if _logger:
		_logger.info("Client disconnected", {"conn_id": conn_id, "total": _connections.size()})

	client_disconnected.emit(conn_id)
	return true


## Gets a connection by ID
func get_connection(conn_id: int) -> WSConnection:
	return _connections.get(conn_id)


## Checks if a connection exists
func has_connection(conn_id: int) -> bool:
	return _connections.has(conn_id)


## Broadcasts a message to all connections
func broadcast(message: String) -> void:
	for conn: WSConnection in _connections.values():
		conn.send(message)


## Broadcasts JSON to all connections
func broadcast_json(data: Dictionary) -> void:
	broadcast(JSON.stringify(data))


## Gets the number of active connections
func get_connection_count() -> int:
	return _connections.size()


## Gets all connection IDs
func get_connection_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _connections.keys():
		ids.append(id)
	return ids


## Gets connection info for all connections
func get_all_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for conn: WSConnection in _connections.values():
		info.append(conn.get_info())
	return info


## Removes all connections
func close_all() -> void:
	for conn: WSConnection in _connections.values():
		conn.close()
	_connections.clear()
	if _logger:
		_logger.info("All connections closed")


## Polls all connections and processes incoming messages
func poll_connections() -> void:
	var to_remove: Array[int] = []

	for conn_id: int in _connections.keys():
		var conn: WSConnection = _connections[conn_id]

		if conn.websocket == null:
			to_remove.append(conn_id)
			continue

		conn.websocket.poll()

		var state: int = conn.websocket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			# Process all available messages
			while conn.websocket.get_available_packet_count() > 0:
				var packet: PackedByteArray = conn.websocket.get_packet()
				var message: String = packet.get_string_from_utf8()
				conn.touch()
				conn.increment_request_count()
				message_received.emit(conn_id, message)
		elif state == WebSocketPeer.STATE_CLOSED:
			to_remove.append(conn_id)

	# Remove closed connections
	for conn_id: int in to_remove:
		remove_connection(conn_id)


## Sets the logger instance
func set_logger(logger: MCPLogger) -> void:
	_logger = logger

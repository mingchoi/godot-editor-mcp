## MCP WebSocket Server
## Implements a WebSocket server using TCPServer + WebSocketPeer pattern.
class_name MCPWebSocketServer
extends Node

## Signal emitted when a new client connects
signal client_connected(conn_id: int)
## Signal emitted when a client disconnects
signal client_disconnected(conn_id: int)
## Signal emitted when a message is received
signal message_received(conn_id: int, message: String)

var _tcp_server: TCPServer
var _connection_manager: ConnectionManager
var _port: int
var _host: String
var _running: bool = false
var _logger: MCPLogger
var _auth_token: String = ""


func _init(port: int = MCPConstants.DEFAULT_EDITOR_PORT, host: String = MCPConstants.DEFAULT_HOST) -> void:
	_port = port
	_host = host
	_logger = MCPLogger.new("[MCPServer:%d]" % port)
	_tcp_server = TCPServer.new()
	_connection_manager = ConnectionManager.new(MCPConstants.MAX_CONNECTIONS, _logger)

	# Forward connection manager signals
	_connection_manager.client_connected.connect(func(conn_id: int): client_connected.emit(conn_id))
	_connection_manager.client_disconnected.connect(func(conn_id: int): client_disconnected.emit(conn_id))
	_connection_manager.message_received.connect(func(conn_id: int, msg: String): message_received.emit(conn_id, msg))


## Starts the WebSocket server
func start() -> Error:
	if _running:
		_logger.warning("Server already running")
		return OK

	var err: Error = _tcp_server.listen(_port, _host)
	if err != OK:
		_logger.error("Failed to start server", {"port": _port, "host": _host, "error": err})
		return err

	_running = true
	_logger.info("Server started", {"port": _port, "host": _host})
	return OK


## Stops the WebSocket server
func stop() -> void:
	if not _running:
		return

	_connection_manager.close_all()
	_tcp_server.stop()
	_running = false
	_logger.info("Server stopped")


## Checks if the server is running
func is_running() -> bool:
	return _running


## Gets the server port
func get_port() -> int:
	return _port


## Gets the server host
func get_host() -> String:
	return _host


## Sets the authentication token
func set_auth_token(token: String) -> void:
	_auth_token = token


## Gets the connection manager
func get_connection_manager() -> ConnectionManager:
	return _connection_manager


## Process loop - call this in _process
func _process(_delta: float) -> void:
	if not _running:
		return

	_accept_new_connections()
	_connection_manager.poll_connections()


## Accepts new TCP connections and upgrades to WebSocket
func _accept_new_connections() -> void:
	if not _tcp_server.is_connection_available():
		return

	var stream: StreamPeerTCP = _tcp_server.take_connection()
	if stream == null:
		return

	# Create WebSocket peer and accept the connection
	var ws := WebSocketPeer.new()
	var err: Error = ws.accept_stream(stream)
	if err != OK:
		_logger.error("Failed to accept WebSocket connection", {"error": err})
		return

	# Add to connection manager
	var conn_id: int = _connection_manager.add_connection(ws)
	if conn_id < 0:
		_logger.warning("Connection rejected (max reached)")
		ws.close(1008, "Server at maximum capacity")


## Sends a message to a specific connection
func send_to(conn_id: int, message: String) -> Error:
	var conn: WSConnection = _connection_manager.get_connection(conn_id)
	if conn == null:
		return ERR_DOES_NOT_EXIST
	return conn.send(message)


## Sends a JSON message to a specific connection
func send_json_to(conn_id: int, data: Dictionary) -> Error:
	return send_to(conn_id, JSON.stringify(data))


## Broadcasts a message to all connections
func broadcast(message: String) -> void:
	_connection_manager.broadcast(message)


## Broadcasts JSON to all connections
func broadcast_json(data: Dictionary) -> void:
	_connection_manager.broadcast_json(data)


## Gets the number of active connections
func get_connection_count() -> int:
	return _connection_manager.get_connection_count()


## Validates authentication if token is configured
func is_authenticated(conn_id: int) -> bool:
	if _auth_token.is_empty():
		return true  # No auth required

	var conn: WSConnection = _connection_manager.get_connection(conn_id)
	if conn == null:
		return false
	return conn.authenticated


## Authenticates a connection with a token
func authenticate(conn_id: int, token: String) -> bool:
	if _auth_token.is_empty():
		return true  # No auth required

	if token != _auth_token:
		return false

	var conn: WSConnection = _connection_manager.get_connection(conn_id)
	if conn == null:
		return false

	conn.authenticated = true
	_logger.info("Client authenticated", {"conn_id": conn_id})
	return true


## Cleans up on exit
func _exit_tree() -> void:
	stop()

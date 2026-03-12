## WebSocket Connection
## Represents a single WebSocket client connection.
class_name WSConnection
extends RefCounted

## Connection states matching WebSocketPeer
enum State {
	CONNECTING = 0,
	OPEN = 1,
	CLOSING = 2,
	CLOSED = 3
}

var id: int
var websocket: WebSocketPeer
var connected_at: int  # Unix timestamp
var last_activity: int
var authenticated: bool = false
var request_count: int = 0
var _logger: MCPLogger


func _init(conn_id: int, ws: WebSocketPeer, logger: MCPLogger = null) -> void:
	id = conn_id
	websocket = ws
	connected_at = Time.get_unix_time_from_system()
	last_activity = connected_at
	_logger = logger


## Checks if the connection is alive and open
func is_alive() -> bool:
	if websocket == null:
		return false
	return websocket.get_ready_state() == WebSocketPeer.STATE_OPEN


## Gets the current state of the connection
func get_state() -> State:
	if websocket == null:
		return State.CLOSED
	match websocket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return State.CONNECTING
		WebSocketPeer.STATE_OPEN:
			return State.OPEN
		WebSocketPeer.STATE_CLOSING:
			return State.CLOSING
		_:
			return State.CLOSED


## Sends a text message through the connection
func send(message: String) -> Error:
	if not is_alive():
		if _logger:
			_logger.warning("Cannot send: connection not alive", {"conn_id": id})
		return ERR_UNCONFIGURED

	var err: Error = websocket.send_text(message)
	if err != OK:
		if _logger:
			_logger.error("Failed to send message", {"conn_id": id, "error": err})
		return err

	last_activity = Time.get_unix_time_from_system()
	return OK


## Sends a JSON message (converts dict to JSON)
func send_json(data: Dictionary) -> Error:
	return send(JSON.stringify(data))


## Closes the connection
func close(code: int = 1000, reason: String = "Normal closure") -> void:
	if websocket != null:
		websocket.close(code, reason)


## Updates the last activity timestamp
func touch() -> void:
	last_activity = Time.get_unix_time_from_system()


## Increments the request counter
func increment_request_count() -> int:
	request_count += 1
	return request_count


## Gets connection age in seconds
func get_age_seconds() -> float:
	return Time.get_unix_time_from_system() - connected_at


## Gets idle time in seconds
func get_idle_seconds() -> float:
	return Time.get_unix_time_from_system() - last_activity


## Gets connection info for logging/debugging
func get_info() -> Dictionary:
	return {
		"id": id,
		"state": get_state(),
		"authenticated": authenticated,
		"connected_at": connected_at,
		"age_seconds": get_age_seconds(),
		"idle_seconds": get_idle_seconds(),
		"request_count": request_count
	}

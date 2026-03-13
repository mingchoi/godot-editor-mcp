## HTTP Connection
## Manages an individual HTTP connection from accept to response.
class_name HTTPConnection
extends RefCounted

## Connection states
enum State {
	READING,     # Reading request data
	COMPLETE,    # Request fully received
	RESPONDING,  # Sending response
	CLOSED       # Connection closed
}

## Signal emitted when response is ready to send
signal response_ready(response: String)

## Signal emitted when connection should be closed
signal connection_closed()

var _peer: StreamPeerTCP
var _state: State = State.READING
var _buffer: String = ""
var _request: HTTPRequestParser.ParsedRequest
var _logger: MCPLogger

## Maximum request size (1MB)
const MAX_REQUEST_SIZE: int = 1024 * 1024


func _init(peer: StreamPeerTCP, logger: MCPLogger = null) -> void:
	_peer = peer
	_logger = logger
	_request = HTTPRequestParser.ParsedRequest.new()


## Poll the connection for data
func poll() -> void:
	if _state == State.CLOSED:
		return

	_peer.poll()

	match _state:
		State.READING:
			_read_request()
		State.RESPONDING:
			_send_response()
		State.COMPLETE, _:
			pass


## Check if connection is still active
func is_peer_connected() -> bool:
	if _peer == null:
		return false
	var status := _peer.get_status()
	return status == StreamPeerTCP.STATUS_CONNECTED


## Check if connection is closed
func is_closed() -> bool:
	return _state == State.CLOSED or not is_peer_connected()


## Close the connection
func close() -> void:
	if _state != State.CLOSED:
		_state = State.CLOSED
		_peer.disconnect_from_host()
		connection_closed.emit()


## Get the parsed request
func get_request() -> HTTPRequestParser.ParsedRequest:
	return _request


## Send a response and prepare to close
func send_response(response: String) -> void:
	if _state == State.CLOSED:
		return

	_buffer = response
	_state = State.RESPONDING


## Read request data from peer
func _read_request() -> void:
	var available := _peer.get_available_bytes()
	if available <= 0:
		return

	var data := _peer.get_data(available)
	if data[0] != OK:
		_log_debug("Failed to read data: %d" % data[0])
		close()
		return

	var chunk := data[1] as PackedByteArray
	var chunk_str := chunk.get_string_from_utf8()
	_buffer += chunk_str

	# Check for max size
	if _buffer.length() > MAX_REQUEST_SIZE:
		_log_debug("Request too large: %d bytes" % _buffer.length())
		send_response(HTTPResponseBuilder.bad_request("Request too large"))
		return

	# Check if request is complete
	if HTTPRequestParser.is_complete_request(_buffer):
		_request = HTTPRequestParser.parse(_buffer)
		_state = State.COMPLETE
		_log_debug("Request complete: %s" % _request)
		response_ready.emit(_buffer)


## Send response data to peer
func _send_response() -> void:
	if _buffer.is_empty():
		close()
		return

	var data := _buffer.to_utf8_buffer()
	var sent := _peer.put_data(data)
	if sent != OK:
		_log_debug("Failed to send response: %d" % sent)
		close()
		return

	_log_debug("Response sent: %d bytes" % data.size())
	close()


## Log debug message
func _log_debug(message: String) -> void:
	if _logger != null:
		_logger.debug("HTTPConnection: %s" % message)

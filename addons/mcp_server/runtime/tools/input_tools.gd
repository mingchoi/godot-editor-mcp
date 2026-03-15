## Input Simulation Tools
## MCP tools for simulating input in running games.
extends RefCounted
class_name InputTools

var _held_keys: Dictionary = {}  # Key constant -> bool
var _held_actions: Dictionary = {}  # Action name -> bool


## Registers all input tools
## Returns the tool instance to prevent garbage collection
static func register(registry: RefCounted) -> RefCounted:
	var tools := InputTools.new()

	registry.register_tool(
		_create_tool_def("runtime_input_key_press", "Simulates a key press and hold", {
			"key": {"type": "string", "description": "Key name (e.g., 'KEY_A', 'KEY_SPACE', 'KEY_UP')"},
			"shift": {"type": "boolean", "default": false},
			"ctrl": {"type": "boolean", "default": false},
			"alt": {"type": "boolean", "default": false},
			"duration_ms": {"type": "integer", "default": 100, "description": "Press duration in milliseconds"}
		}, ["key"]),
		tools._execute_key_press
	)

	registry.register_tool(
		_create_tool_def("runtime_input_key_tap", "Simulates a quick key tap (press and release)", {
			"key": {"type": "string", "description": "Key name"},
			"shift": {"type": "boolean", "default": false},
			"ctrl": {"type": "boolean", "default": false},
			"alt": {"type": "boolean", "default": false}
		}, ["key"]),
		tools._execute_key_tap
	)

	registry.register_tool(
		_create_tool_def("runtime_input_key_release", "Releases a held key", {
			"key": {"type": "string", "description": "Key name to release"}
		}, ["key"]),
		tools._execute_key_release
	)

	registry.register_tool(
		_create_tool_def("runtime_input_mouse_move", "Moves the mouse to a position", {
			"position": {
				"type": "object",
				"properties": {
					"x": {"type": "number"},
					"y": {"type": "number"}
				},
				"required": ["x", "y"]
			},
			"relative": {"type": "boolean", "default": false, "description": "Position is relative"}
		}, ["position"]),
		tools._execute_mouse_move
	)

	registry.register_tool(
		_create_tool_def("runtime_input_mouse_click", "Simulates a mouse button click", {
			"button": {"type": "string", "enum": ["left", "right", "middle"], "default": "left"},
			"position": {"type": "object", "description": "Click position"},
			"double": {"type": "boolean", "default": false, "description": "Double click"},
			"duration_ms": {"type": "integer", "default": 50}
		}, []),
		tools._execute_mouse_click
	)

	registry.register_tool(
		_create_tool_def("runtime_input_action_press", "Simulates an input action press", {
			"action": {"type": "string", "description": "Action name from InputMap"},
			"strength": {"type": "number", "default": 1.0, "minimum": 0.0, "maximum": 1.0}
		}, ["action"]),
		tools._execute_action_press
	)

	registry.register_tool(
		_create_tool_def("runtime_input_action_release", "Releases an input action", {
			"action": {"type": "string", "description": "Action name to release"}
		}, ["action"]),
		tools._execute_action_release
	)

	registry.register_tool(
		_create_tool_def("runtime_input_type_text", "Types a string of text character by character", {
			"text": {"type": "string", "description": "Text to type"},
			"interval_ms": {"type": "integer", "default": 50, "description": "Delay between keystrokes"}
		}, ["text"]),
		tools._execute_type_text
	)

	return tools


# --- Key Mapping Helpers ---

func _parse_key(key_name: String) -> Key:
	# Map common key names to Godot Key constants
	match key_name.to_upper():
		"KEY_A": return KEY_A
		"KEY_B": return KEY_B
		"KEY_C": return KEY_C
		"KEY_D": return KEY_D
		"KEY_E": return KEY_E
		"KEY_F": return KEY_F
		"KEY_G": return KEY_G
		"KEY_H": return KEY_H
		"KEY_I": return KEY_I
		"KEY_J": return KEY_J
		"KEY_K": return KEY_K
		"KEY_L": return KEY_L
		"KEY_M": return KEY_M
		"KEY_N": return KEY_N
		"KEY_O": return KEY_O
		"KEY_P": return KEY_P
		"KEY_Q": return KEY_Q
		"KEY_R": return KEY_R
		"KEY_S": return KEY_S
		"KEY_T": return KEY_T
		"KEY_U": return KEY_U
		"KEY_V": return KEY_V
		"KEY_W": return KEY_W
		"KEY_X": return KEY_X
		"KEY_Y": return KEY_Y
		"KEY_Z": return KEY_Z
		"KEY_0": return KEY_0
		"KEY_1": return KEY_1
		"KEY_2": return KEY_2
		"KEY_3": return KEY_3
		"KEY_4": return KEY_4
		"KEY_5": return KEY_5
		"KEY_6": return KEY_6
		"KEY_7": return KEY_7
		"KEY_8": return KEY_8
		"KEY_9": return KEY_9
		"KEY_SPACE": return KEY_SPACE
		"KEY_ENTER", "KEY_RETURN": return KEY_ENTER
		"KEY_ESCAPE", "KEY_ESC": return KEY_ESCAPE
		"KEY_TAB": return KEY_TAB
		"KEY_BACKSPACE": return KEY_BACKSPACE
		"KEY_DELETE": return KEY_DELETE
		"KEY_UP": return KEY_UP
		"KEY_DOWN": return KEY_DOWN
		"KEY_LEFT": return KEY_LEFT
		"KEY_RIGHT": return KEY_RIGHT
		"KEY_SHIFT": return KEY_SHIFT
		"KEY_CTRL", "KEY_CONTROL": return KEY_CTRL
		"KEY_ALT": return KEY_ALT
		_:
			# Unknown key - return KEY_UNKNOWN
			return KEY_UNKNOWN


# --- Tool Implementations ---

func _execute_key_press(args: Dictionary) -> Dictionary:
	var key_name: String = args.get("key", "")
	var shift: bool = args.get("shift", false)
	var ctrl: bool = args.get("ctrl", false)
	var alt: bool = args.get("alt", false)
	var duration_ms: int = args.get("duration_ms", 100)

	var key_code: Key = _parse_key(key_name)
	if key_code == KEY_UNKNOWN:
		return {"content": [{"type": "text", "text": "Error: Unknown key: %s" % key_name}], "isError": true}

	# Create key press event
	var event := InputEventKey.new()
	event.keycode = key_code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.alt_pressed = alt

	# Send press event
	Input.parse_input_event(event)

	# Track held key
	_held_keys[key_code] = true

	# Schedule release (simplified - in production would use timer)
	if duration_ms > 0:
		await _get_tree().create_timer(duration_ms / 1000.0).timeout
		_release_key(key_code)

	return {
		"content": [{"type": "text", "text": "Pressed %s for %dms" % [key_name, duration_ms]}],
		"isError": false
	}


func _execute_key_tap(args: Dictionary) -> Dictionary:
	var key_name: String = args.get("key", "")
	var shift: bool = args.get("shift", false)
	var ctrl: bool = args.get("ctrl", false)
	var alt: bool = args.get("alt", false)

	var key_code: Key = _parse_key(key_name)
	if key_code == KEY_UNKNOWN:
		return {"content": [{"type": "text", "text": "Error: Unknown key: %s" % key_name}], "isError": true}

	# Press
	var press_event := InputEventKey.new()
	press_event.keycode = key_code
	press_event.pressed = true
	press_event.shift_pressed = shift
	press_event.ctrl_pressed = ctrl
	press_event.alt_pressed = alt
	Input.parse_input_event(press_event)

	# Small delay
	await _get_tree().process_frame

	# Release
	var release_event := InputEventKey.new()
	release_event.keycode = key_code
	release_event.pressed = false
	release_event.shift_pressed = shift
	release_event.ctrl_pressed = ctrl
	release_event.alt_pressed = alt
	Input.parse_input_event(release_event)

	return {
		"content": [{"type": "text", "text": "Tapped %s" % key_name}],
		"isError": false
	}


func _execute_key_release(args: Dictionary) -> Dictionary:
	var key_name: String = args.get("key", "")

	var key_code: Key = _parse_key(key_name)
	if key_code == KEY_UNKNOWN:
		return {"content": [{"type": "text", "text": "Error: Unknown key: %s" % key_name}], "isError": true}

	if not _held_keys.get(key_code, false):
		return {
			"content": [{"type": "text", "text": "Key %s was not held" % key_name}],
			"isError": false
		}

	_release_key(key_code)
	return {
		"content": [{"type": "text", "text": "Released %s" % key_name}],
		"isError": false
	}


func _release_key(key_code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code
	event.pressed = false
	Input.parse_input_event(event)
	_held_keys.erase(key_code)


func _execute_mouse_move(args: Dictionary) -> Dictionary:
	var position_data: Dictionary = args.get("position", {})
	var relative: bool = args.get("relative", false)

	var x: float = position_data.get("x", 0.0)
	var y: float = position_data.get("y", 0.0)

	var event := InputEventMouseMotion.new()

	if relative:
		event.relative = Vector2(x, y)
		event.velocity = Vector2(x, y)
	else:
		var viewport: Viewport = _get_viewport()
		var current_pos: Vector2 = viewport.get_mouse_position() if viewport != null else Vector2.ZERO
		event.position = Vector2(x, y)
		event.global_position = Vector2(x, y)
		event.relative = Vector2(x, y) - current_pos

	Input.parse_input_event(event)

	return {
		"content": [{"type": "text", "text": "Mouse moved to (%.0f, %.0f)" % [x, y]}],
		"isError": false
	}


func _execute_mouse_click(args: Dictionary) -> Dictionary:
	var button_str: String = args.get("button", "left")
	var position_data: Dictionary = args.get("position", {})
	var double_click: bool = args.get("double", false)
	var duration_ms: int = args.get("duration_ms", 50)

	var button_index: MouseButton
	match button_str.to_lower():
		"left": button_index = MOUSE_BUTTON_LEFT
		"right": button_index = MOUSE_BUTTON_RIGHT
		"middle": button_index = MOUSE_BUTTON_MIDDLE
		_:
			return {"content": [{"type": "text", "text": "Error: Invalid button: %s" % button_str}], "isError": true}

	var x: float = position_data.get("x", 0.0)
	var y: float = position_data.get("y", 0.0)
	var has_position: bool = not position_data.is_empty()

	# Get current position if not specified
	if not has_position:
		var viewport: Viewport = _get_viewport()
		if viewport != null:
			var current: Vector2 = viewport.get_mouse_position()
			x = current.x
			y = current.y

	# Create click event
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = Vector2(x, y)
	event.global_position = Vector2(x, y)
	event.double_click = double_click

	Input.parse_input_event(event)

	# Hold for duration
	if duration_ms > 0:
		await _get_tree().create_timer(duration_ms / 1000.0).timeout

	# Release
	var release_event := InputEventMouseButton.new()
	release_event.button_index = button_index
	release_event.pressed = false
	release_event.position = Vector2(x, y)
	release_event.global_position = Vector2(x, y)

	Input.parse_input_event(release_event)

	return {
		"content": [{"type": "text", "text": "%s click at (%.0f, %.0f)" % ["Double" if double_click else "", x, y]}],
		"isError": false
	}


func _execute_action_press(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")
	var strength: float = args.get("strength", 1.0)

	if not InputMap.has_action(action):
		return {"content": [{"type": "text", "text": "Error: Action not found in InputMap: %s" % action}], "isError": true}

	Input.action_press(action, strength)
	_held_actions[action] = true

	return {
		"content": [{"type": "text", "text": "Pressed action: %s" % action}],
		"isError": false
	}


func _execute_action_release(args: Dictionary) -> Dictionary:
	var action: String = args.get("action", "")

	if not InputMap.has_action(action):
		return {"content": [{"type": "text", "text": "Error: Action not found in InputMap: %s" % action}], "isError": true}

	if not _held_actions.get(action, false):
		return {
			"content": [{"type": "text", "text": "Action %s was not pressed" % action}],
			"isError": false
		}

	Input.action_release(action)
	_held_actions.erase(action)

	return {
		"content": [{"type": "text", "text": "Released action: %s" % action}],
		"isError": false
	}


func _execute_type_text(args: Dictionary) -> Dictionary:
	var text: String = args.get("text", "")
	var interval_ms: int = args.get("interval_ms", 50)

	if text.is_empty():
		return {"content": [{"type": "text", "text": "No text to type"}], "isError": false}

	var chars_typed: int = 0

	for i: int in range(text.length()):
		var char_code: int = text.unicode_at(i)
		var event := InputEventKey.new()
		event.keycode = char_code as Key
		event.unicode = char_code
		event.pressed = true

		Input.parse_input_event(event)
		await _get_tree().process_frame

		event.pressed = false
		Input.parse_input_event(event)

		if interval_ms > 0:
			await _get_tree().create_timer(interval_ms / 1000.0).timeout

		chars_typed += 1

	return {
		"content": [{"type": "text", "text": "Typed %d characters" % chars_typed}],
		"isError": false
	}


func _get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _get_viewport() -> Viewport:
	var tree: SceneTree = _get_tree()
	if tree == null:
		return null
	return tree.root


static func _create_tool_def(name: String, desc: String, props: Dictionary, required: Array) -> Dictionary:
	var schema: Dictionary = {"type": "object", "properties": props}
	if not required.is_empty():
		schema["required"] = required
	return {
		"name": name,
		"description": desc,
		"inputSchema": schema
	}

## Editor Viewport Tools
## MCP tools for controlling the editor viewport camera.
extends RefCounted
class_name EditorViewportTools

# Tool name constants
const TOOL_FOCUS_ON_NODE := "viewport_focus_on_node"
const TOOL_SET_CAMERA := "viewport_set_camera"
const TOOL_ORBIT := "viewport_orbit"
const TOOL_ZOOM := "viewport_zoom"

# Zoom factor constraints
const ZOOM_MIN := 0.01
const ZOOM_MAX := 100.0

# Default distance for focusing on nodes without geometry
const DEFAULT_FOCUS_DISTANCE := 5.0

var _logger: MCPLogger
var _editor_interface: EditorInterface
var _focus_point: Vector3 = Vector3.ZERO
var _focus_node_path: String = ""


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("EditorViewportTools") if logger else MCPLogger.new("[EditorViewportTools]")
	_editor_interface = editor_interface


## Registers all viewport tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_focus_tool())
	registry.register(_create_set_camera_tool())
	registry.register(_create_orbit_tool())
	registry.register(_create_zoom_tool())
	_logger.info("Viewport tools registered", {"count": 4})


# --- Tool Definitions ---

func _create_focus_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_FOCUS_ON_NODE,
		"Focus the editor viewport camera on a specific scene node, centering it in the view",
		{
			"path": {
				"type": "string",
				"description": "Node path to focus on (e.g., 'Main/Player' or '/root/Main/Player')"
			}
		},
		["path"]
	)
	return MCPToolHandler.new(definition, _execute_focus)


func _create_set_camera_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_SET_CAMERA,
		"Position the editor viewport camera at a specific location and set its look-at target",
		{
			"position": {
				"type": "object",
				"description": "Camera position in world coordinates",
				"properties": {
					"x": {"type": "number"},
					"y": {"type": "number"},
					"z": {"type": "number"}
				}
			},
			"look_at": {
				"type": "object",
				"description": "Point the camera should look at in world coordinates",
				"properties": {
					"x": {"type": "number"},
					"y": {"type": "number"},
					"z": {"type": "number"}
				}
			}
		},
		["position", "look_at"]
	)
	return MCPToolHandler.new(definition, _execute_set_camera)


func _create_orbit_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_ORBIT,
		"Orbit the camera around the current focus point by specified rotation angles",
		{
			"delta_rotation": {
				"type": "object",
				"description": "Rotation deltas in degrees",
				"properties": {
					"x": {
						"type": "number",
						"default": 0,
						"description": "Pitch rotation (tilt up/down) in degrees"
					},
					"y": {
						"type": "number",
						"default": 0,
						"description": "Yaw rotation (pan left/right) in degrees"
					},
					"z": {
						"type": "number",
						"default": 0,
						"description": "Roll rotation in degrees"
					}
				}
			}
		},
		["delta_rotation"]
	)
	return MCPToolHandler.new(definition, _execute_orbit)


func _create_zoom_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_ZOOM,
		"Zoom the camera in or out relative to the current focus point",
		{
			"factor": {
				"type": "number",
				"description": "Zoom factor relative to current distance (0.5 = zoom in 2x closer, 2.0 = zoom out 2x farther)",
				"minimum": ZOOM_MIN,
				"maximum": ZOOM_MAX
			}
		},
		["factor"]
	)
	return MCPToolHandler.new(definition, _execute_zoom)


# --- Helper Methods ---

## Gets the Camera3D from the editor's 3D viewport
func _get_camera_3d() -> Camera3D:
	if _editor_interface == null:
		return null

	var editor_viewport: Node = _editor_interface.get_editor_viewport_3d()
	if editor_viewport == null:
		return null

	var viewport: Viewport = editor_viewport.get_viewport()
	if viewport == null:
		return null

	var camera: Camera3D = viewport.get_camera_3d()
	return camera


## Resolves a node path to the actual node
func _resolve_node(path: String) -> Node:
	if _editor_interface == null:
		return null

	var edited_scene: Node = _editor_interface.get_edited_scene_root()
	if edited_scene == null:
		return null

	# Handle absolute paths starting with /root/
	if path.begins_with("/root/"):
		return edited_scene.get_tree().root.get_node_or_null(path)

	# Handle relative paths from edited scene root
	return edited_scene.get_node_or_null(path)


## Validates a Vector3 dictionary for finite values
func _validate_vector3(dict: Dictionary) -> Dictionary:
	var result := {"valid": false, "vector": Vector3.ZERO, "error": ""}

	if not dict.has("x") or not dict.has("y") or not dict.has("z"):
		result.error = "Missing coordinate values. Required: x, y, z"
		return result

	var x: float = dict.get("x", 0.0)
	var y: float = dict.get("y", 0.0)
	var z: float = dict.get("z", 0.0)

	if not is_finite(x) or not is_finite(y) or not is_finite(z):
		result.error = "Invalid coordinates: values must be finite numbers."
		return result

	result.valid = true
	result.vector = Vector3(x, y, z)
	return result


## Calculates the bounding box for a node (including its children)
func _calculate_node_bounds(node: Node) -> AABB:
	var bounds := AABB()

	# Check if node has visual instance
	if node is VisualInstance3D:
		bounds = (node as VisualInstance3D).get_aabb()

	# For nodes with geometry, also check children
	for child: Node in node.get_children():
		if child is Node3D:
			var child_bounds := _calculate_node_bounds(child)
			if child_bounds.size != Vector3.ZERO:
				if bounds.size == Vector3.ZERO:
					bounds = child_bounds
				else:
					bounds = bounds.merge(child_bounds)

	return bounds


# --- Tool Implementations ---

func _execute_focus(params: Dictionary) -> MCPToolResult:
	var camera: Camera3D = _get_camera_3d()
	if camera == null:
		return MCPToolResult.error(
			"No 3D viewport available. Open a 3D viewport first.",
			MCPError.Code.TOOL_EXECUTION_ERROR
		)

	var path: String = params.get("path", "")
	if path.is_empty():
		return MCPToolResult.error(
			"Node path is required.",
			MCPError.Code.INVALID_PARAMS
		)

	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error(
			"Node not found: %s. Check the node path." % path,
			MCPError.Code.NOT_FOUND
		)

	# Get node position
	var node_3d: Node3D = null
	if node is Node3D:
		node_3d = node as Node3D
	else:
		# Try to find a Node3D ancestor or the scene root
		var parent: Node = node.get_parent()
		while parent != null and not (parent is Node3D):
			parent = parent.get_parent()
		if parent is Node3D:
			node_3d = parent

	if node_3d == null:
		return MCPToolResult.error(
			"Node '%s' is not a 3D node and has no 3D parent." % path,
			MCPError.Code.TOOL_EXECUTION_ERROR
		)

	var target_position: Vector3 = node_3d.get_global_position()
	var bounds: AABB = _calculate_node_bounds(node_3d)

	# Calculate focus distance based on node size
	var distance: float = DEFAULT_FOCUS_DISTANCE
	if bounds.size != Vector3.ZERO:
		# Use the largest dimension to calculate view distance
		var max_size: float = max(bounds.size.x, max(bounds.size.y, bounds.size.z))
		distance = max_size * 2.0 + DEFAULT_FOCUS_DISTANCE
		# Use bounding box center if available
		target_position = bounds.get_center()

	# Calculate camera position (offset from target)
	var camera_position: Vector3 = camera.get_global_position()
	var current_direction: Vector3 = (camera_position - target_position).normalized()
	if current_direction == Vector3.ZERO:
		current_direction = Vector3(0.5, 0.5, 0.5).normalized()

	var new_camera_position: Vector3 = target_position + current_direction * distance

	# Position the camera
	camera.look_at_from_position(new_camera_position, target_position, Vector3.UP)

	# Update internal state
	_focus_point = target_position
	_focus_node_path = path

	_logger.info("Focused on node", {
		"path": path,
		"position": {"x": target_position.x, "y": target_position.y, "z": target_position.z},
		"distance": distance
	})

	return MCPToolResult.text(
		"Camera focused on node '%s' at position (%.2f, %.2f, %.2f)" % [path, target_position.x, target_position.y, target_position.z],
		{
			"success": true,
			"node_path": path,
			"node_name": node.name,
			"focus_position": {"x": target_position.x, "y": target_position.y, "z": target_position.z},
			"camera_position": {"x": new_camera_position.x, "y": new_camera_position.y, "z": new_camera_position.z},
			"distance": distance
		}
	)


func _execute_set_camera(params: Dictionary) -> MCPToolResult:
	var camera: Camera3D = _get_camera_3d()
	if camera == null:
		return MCPToolResult.error(
			"No 3D viewport available. Open a 3D viewport first.",
			MCPError.Code.TOOL_EXECUTION_ERROR
		)

	# Validate position
	var position_dict: Dictionary = params.get("position", {})
	var position_result: Dictionary = _validate_vector3(position_dict)
	if not position_result.valid:
		return MCPToolResult.error(
			position_result.error,
			MCPError.Code.INVALID_PARAMS
		)
	var position: Vector3 = position_result.vector

	# Validate look_at
	var look_at_dict: Dictionary = params.get("look_at", {})
	var look_at_result: Dictionary = _validate_vector3(look_at_dict)
	if not look_at_result.valid:
		return MCPToolResult.error(
			look_at_result.error,
			MCPError.Code.INVALID_PARAMS
		)
	var look_at: Vector3 = look_at_result.vector

	# Check that position and look_at are not the same
	if position.is_equal_approx(look_at):
		return MCPToolResult.error(
			"Camera position cannot be the same as look-at target.",
			MCPError.Code.INVALID_PARAMS
		)

	# Position the camera
	camera.look_at_from_position(position, look_at, Vector3.UP)

	# Update internal state
	_focus_point = look_at
	_focus_node_path = ""

	var distance: float = position.distance_to(look_at)

	_logger.info("Camera positioned", {
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"look_at": {"x": look_at.x, "y": look_at.y, "z": look_at.z},
		"distance": distance
	})

	return MCPToolResult.text(
		"Camera positioned at (%.2f, %.2f, %.2f) looking at (%.2f, %.2f, %.2f)" % [
			position.x, position.y, position.z,
			look_at.x, look_at.y, look_at.z
		],
		{
			"success": true,
			"camera_position": {"x": position.x, "y": position.y, "z": position.z},
			"look_at": {"x": look_at.x, "y": look_at.y, "z": look_at.z},
			"distance": distance
		}
	)


func _execute_zoom(params: Dictionary) -> MCPToolResult:
	var camera: Camera3D = _get_camera_3d()
	if camera == null:
		return MCPToolResult.error(
			"No 3D viewport available. Open a 3D viewport first.",
			MCPError.Code.TOOL_EXECUTION_ERROR
		)

	# Validate zoom factor
	var factor: float = params.get("factor", 1.0)
	if not is_finite(factor) or factor < ZOOM_MIN or factor > ZOOM_MAX:
		return MCPToolResult.error(
			"Zoom factor must be between %.2f and %.2f, got %.2f." % [ZOOM_MIN, ZOOM_MAX, factor],
			MCPError.Code.INVALID_PARAMS
		)

	var current_position: Vector3 = camera.get_global_position()
	var current_distance: float = current_position.distance_to(_focus_point)

	# Prevent division by zero if camera is at focus point
	if current_distance < 0.001:
		current_distance = DEFAULT_FOCUS_DISTANCE

	var new_distance: float = current_distance * factor

	# Calculate new camera position along the direction to focus point
	var direction: Vector3 = (current_position - _focus_point).normalized()
	if direction == Vector3.ZERO:
		direction = Vector3.BACK

	var new_position: Vector3 = _focus_point + direction * new_distance

	# Position the camera
	camera.look_at_from_position(new_position, _focus_point, Vector3.UP)

	_logger.info("Camera zoomed", {
		"factor": factor,
		"previous_distance": current_distance,
		"new_distance": new_distance
	})

	return MCPToolResult.text(
		"Camera zoomed by factor %.2f (distance: %.2f -> %.2f)" % [factor, current_distance, new_distance],
		{
			"success": true,
			"focus_point": {"x": _focus_point.x, "y": _focus_point.y, "z": _focus_point.z},
			"previous_distance": current_distance,
			"new_distance": new_distance,
			"zoom_factor": factor
		}
	)


func _execute_orbit(params: Dictionary) -> MCPToolResult:
	var camera: Camera3D = _get_camera_3d()
	if camera == null:
		return MCPToolResult.error(
			"No 3D viewport available. Open a 3D viewport first.",
			MCPError.Code.TOOL_EXECUTION_ERROR
		)

	# Get rotation deltas (default to 0 for each axis)
	var rotation_dict: Dictionary = params.get("delta_rotation", {})
	var pitch: float = deg_to_rad(rotation_dict.get("x", 0.0))  # Pitch (tilt up/down)
	var yaw: float = deg_to_rad(rotation_dict.get("y", 0.0))    # Yaw (pan left/right)
	var roll: float = deg_to_rad(rotation_dict.get("z", 0.0))   # Roll

	# Validate rotation values
	if not is_finite(pitch) or not is_finite(yaw) or not is_finite(roll):
		return MCPToolResult.error(
			"Rotation values must be finite numbers.",
			MCPError.Code.INVALID_PARAMS
		)

	var current_position: Vector3 = camera.get_global_position()
	var distance: float = current_position.distance_to(_focus_point)

	# Prevent issues if camera is at focus point
	if distance < 0.001:
		distance = DEFAULT_FOCUS_DISTANCE
		current_position = _focus_point + Vector3.BACK * distance

	# Calculate the offset from focus point to camera
	var offset: Vector3 = current_position - _focus_point

	# Apply rotations:
	# 1. Yaw (around Y axis - horizontal rotation)
	var yaw_basis: Basis = Basis(Vector3.UP, yaw)
	offset = yaw_basis * offset

	# 2. Pitch (around X axis - vertical rotation)
	# Calculate the right vector from the current offset
	var right: Vector3 = offset.cross(Vector3.UP).normalized()
	if right == Vector3.ZERO:
		right = Vector3.RIGHT
	var pitch_basis: Basis = Basis(right, pitch)
	offset = pitch_basis * offset

	# 3. Roll (around Z axis - camera roll)
	# We'll apply this to the camera's up vector in look_at_from_position
	var up_vector: Vector3 = Vector3.UP
	if roll != 0.0:
		var forward: Vector3 = (-offset).normalized()
		var roll_basis: Basis = Basis(forward, roll)
		up_vector = roll_basis * up_vector

	var new_position: Vector3 = _focus_point + offset

	# Position the camera
	camera.look_at_from_position(new_position, _focus_point, up_vector)

	_logger.info("Camera orbited", {
		"delta_rotation": {"x": rad_to_deg(pitch), "y": rad_to_deg(yaw), "z": rad_to_deg(roll)},
		"new_position": {"x": new_position.x, "y": new_position.y, "z": new_position.z}
	})

	return MCPToolResult.text(
		"Camera orbited by (%.1f, %.1f, %.1f) degrees" % [
			rad_to_deg(pitch), rad_to_deg(yaw), rad_to_deg(roll)
		],
		{
			"success": true,
			"focus_point": {"x": _focus_point.x, "y": _focus_point.y, "z": _focus_point.z},
			"camera_position": {"x": new_position.x, "y": new_position.y, "z": new_position.z},
			"rotation_applied": {
				"x": rad_to_deg(pitch),
				"y": rad_to_deg(yaw),
				"z": rad_to_deg(roll)
			}
		}
	)

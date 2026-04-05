extends Camera3D
## Fixed-angle 3rd-person ARPG camera.
## Sits OUTSIDE the player hierarchy so it NEVER inherits player rotation.
## Follows player's position only — like Diablo / Dark Souls / Zelda.

@export var camera_height: float = 5.0       # how high above player
@export var camera_distance: float = 9.0      # how far behind player
@export var camera_angle_degrees: float = -35.0 # pitch: negative = looking down
@export var smooth_speed: float = 8.0          # higher = snappier follow

var _player: CharacterBody3D


func _ready() -> void:
	# Set position offset (local space — we'll apply it to player's world pos)
	position = Vector3(0.0, camera_height, camera_distance)

	# Set rotation ONCE — this is the fixed viewing angle.
	# Since this node is NOT a child of Player, its transform is fully independent.
	rotation_degrees = Vector3(camera_angle_degrees, 0.0, 0.0)

	# Find the player by group (player is added to "player" group in player.gd)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _process(delta: float) -> void:
	if not _player:
		return

	# Target = player's world position + a FIXED world-space offset.
	# NO basis transform — this must be pure world coordinates so turning
	# the player (which changes global_transform.basis) does NOT move the camera.
	var target_pos: Vector3 = _player.global_position + Vector3(0.0, camera_height, camera_distance)

	# Smoothly interpolate toward target (prevents jittery movement)
	global_position = global_position.lerp(target_pos, smooth_speed * delta)

	# NEVER call look_at() or modify rotation — stays locked at _ready() angle

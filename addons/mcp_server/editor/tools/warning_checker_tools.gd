## Warning Checker Tools
## MCP tools for checking node configuration warnings in the edited scene.
extends RefCounted
class_name WarningCheckerTools

const TOOL_GET_NODE_WARNINGS := "editor_get_node_warnings"
const TOOL_GET_SCENE_WARNINGS := "editor_get_scene_warnings"
const TOOL_GET_WARNING_TYPES := "editor_get_warning_types"

var _editor_interface: EditorInterface
var _logger: MCPLogger


func _init(logger: MCPLogger = null, editor_interface: EditorInterface = null) -> void:
	_logger = logger.child("WarningCheckerTools") if logger else MCPLogger.new("[WarningCheckerTools]")
	_editor_interface = editor_interface


## Registers all warning checker tools
func register_all(registry: ToolRegistry) -> void:
	registry.register(_create_get_node_warnings_tool())
	registry.register(_create_get_scene_warnings_tool())
	registry.register(_create_get_warning_types_tool())


## Gets warnings from a node by checking its properties using match-based hierarchy
## This follows the structure from configuration_warnings.json
## Returns empty array if node is null or no warnings
func _get_node_warnings(node: Node) -> PackedStringArray:
	if node == null:
		return PackedStringArray()

	var node_class: String = node.get_class()
	return _check_warning(node_class, node)


## Check warnings for a specific class using match statements
## Child classes call parent checks and append results
func _check_warning(node_class: String, node: Node) -> PackedStringArray:
	var warnings: PackedStringArray = []

	match node_class:
		# === Node3D hierarchy ===
		"CollisionShape3D":
			# Own checks
			var shape_node := node as CollisionShape3D
			if shape_node.shape == null:
				warnings.append("A shape must be provided for CollisionShape3D to function. Please create a shape resource for it.")

			# Parent check (CollisionObject3D -> Node3D)
			var parent := node.get_parent()
			if not (parent is Area3D or parent is StaticBody3D or parent is RigidBody3D or parent is CharacterBody3D):
				warnings.append("CollisionShape3D only serves to provide a collision shape to a CollisionObject3D derived node. Please only use it as a child of Area3D, StaticBody3D, RigidBody3D, CharacterBody3D, etc. to give them a shape.")

		"CollisionPolygon3D":
			var polygon_node := node as CollisionPolygon3D
			if polygon_node.polygon.is_empty():
				warnings.append("An empty CollisionPolygon3D has no effect on collision.")

			var parent := node.get_parent()
			if not (parent is Area3D or parent is StaticBody3D or parent is RigidBody3D or parent is CharacterBody3D):
				warnings.append("CollisionPolygon3D only serves to provide a collision shape to a CollisionObject3D derived node. Please only use it as a child of Area3D, StaticBody3D, RigidBody3D, CharacterBody3D, etc. to give them a shape.")

		"RigidBody3D":
			# Scale check (from Godot C++ source)
			var scale: Vector3 = node.transform.basis.get_scale()
			if absf(scale.x - 1.0) > 0.05 or absf(scale.y - 1.0) > 0.05 or absf(scale.z - 1.0) > 0.05:
				warnings.append("Scale changes to RigidBody3D will be overridden by the physics engine when running. Please change the size in children collision shapes instead.")

			# Parent check (PhysicsBody3D -> CollisionObject3D -> Node3D)
			var has_shape := false
			for child in node.get_children():
				if child is CollisionShape3D or child is CollisionPolygon3D:
					has_shape = true
					break
			if not has_shape:
				warnings.append("This node has no shape, so it can't collide or interact with other objects. Consider adding a CollisionShape3D or CollisionPolygon3D as a child to define its shape.")

		"Area3D", "StaticBody3D", "CharacterBody3D":
			# Parent check (CollisionObject3D -> Node3D)
			var has_shape := false
			for child in node.get_children():
				if child is CollisionShape3D or child is CollisionPolygon3D:
					has_shape = true
					break
			if not has_shape:
				warnings.append("This node has no shape, so it can't collide or interact with other objects. Consider adding a CollisionShape3D or CollisionPolygon3D as a child to define its shape.")

		"NavigationAgent3D":
			var parent := node.get_parent()
			if not (parent is Node3D):
				warnings.append("The NavigationAgent3D can be used only under a Node3D inheriting parent node.")

		"NavigationRegion3D":
			var nav_region := node as NavigationRegion3D
			if nav_region.navigation_mesh == null and node.is_visible_in_tree() and node.is_inside_tree():
				warnings.append("A NavigationMesh resource must be set or created for this node to work.")

		"MeshInstance3D":
			var mesh_inst := node as MeshInstance3D
			if mesh_inst.mesh == null:
				warnings.append("MeshInstance3D requires a Mesh to render anything. Please add a mesh resource for it!")

		"Path3D":
			# No warnings by default
			pass

		"PathFollow3D":
			var parent := node.get_parent()
			if not (parent is Path3D):
				warnings.append("PathFollow3D should be a child of a Path3D node.")

		# === Node2D hierarchy ===
		"CollisionShape2D":
			var shape_node := node as CollisionShape2D
			if shape_node.shape == null:
				warnings.append("A shape must be provided for CollisionShape2D to function. Please create a shape resource for it!")

			var parent := node.get_parent()
			if not (parent is Area2D or parent is StaticBody2D or parent is RigidBody2D or parent is CharacterBody2D):
				warnings.append("CollisionShape2D only serves to provide a collision shape to a CollisionObject2D derived node. Please only use it as a child of Area2D, StaticBody2D, RigidBody2D, CharacterBody2D, etc. to give them a shape.")

		"CollisionPolygon2D":
			var polygon_node := node as CollisionPolygon2D
			if polygon_node.polygon.is_empty():
				warnings.append("An empty CollisionPolygon2D has no effect on collision.")

			var parent := node.get_parent()
			if not (parent is Area2D or parent is StaticBody2D or parent is RigidBody2D or parent is CharacterBody2D):
				warnings.append("CollisionPolygon2D only serves to provide a collision shape to a CollisionObject2D derived node. Please only use it as a child of Area2D, StaticBody2D, RigidBody2D, CharacterBody2D, etc. to give them a shape.")

		"RigidBody2D":
			# Transform check (from Godot C++ source)
			var t: Transform2D = node.transform
			if absf(t.x.length() - 1.0) > 0.05 or absf(t.y.length() - 1.0) > 0.05:
				warnings.append("Size changes to RigidBody2D will be overridden by the physics engine when running. Change the size in children collision shapes instead.")

			# Parent check (PhysicsBody2D -> CollisionObject2D -> Node2D)
			var has_shape := false
			for child in node.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					has_shape = true
					break
			if not has_shape:
				warnings.append("This node has no shape, so it can't collide or interact with other objects. Consider adding a CollisionShape2D or CollisionPolygon2D as a child to define its shape.")

		"Area2D", "StaticBody2D", "CharacterBody2D":
			# Parent check (CollisionObject2D -> Node2D)
			var has_shape := false
			for child in node.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					has_shape = true
					break
			if not has_shape:
				warnings.append("This node has no shape, so it can't collide or interact with other objects. Consider adding a CollisionShape2D or CollisionPolygon2D as a child to define its shape.")

		"NavigationAgent2D":
			var parent := node.get_parent()
			if not (parent is Node2D):
				warnings.append("The NavigationAgent2D can be used only under a Node2D inheriting parent node.")

		"NavigationRegion2D":
			var nav_region := node as NavigationRegion2D
			if nav_region.navigation_polygon == null and node.is_visible_in_tree() and node.is_inside_tree():
				warnings.append("A NavigationPolygon resource must be set or created for this node to work. Please set a property or draw a polygon.")

		"Path2D":
			# No warnings by default
			pass

		"PathFollow2D":
			var parent := node.get_parent()
			if not (parent is Path2D):
				warnings.append("PathFollow2D should be a child of a Path2D node.")

		"Sprite2D":
			# Check if texture is null
			if node.has_property("texture") and node.get("texture") == null:
				warnings.append("Sprite2D texture should be assigned for the sprite to be visible.")

		"AnimatedSprite2D":
			var anim_sprite := node as AnimatedSprite2D
			if anim_sprite.sprite_frames == null:
				warnings.append("A SpriteFrames resource must be created or set in the \"Sprite Frames\" property in order for AnimatedSprite2D to display frames.")

		"Bone2D":
			var bone := node as Bone2D
			if bone.skeleton == null:
				if bone.parent_bone:
					warnings.append("This Bone2D chain should end at a Skeleton2D node.")
				else:
					warnings.append("A Bone2D only works with a Skeleton2D or another Bone2D as parent node.")

		"CanvasGroup":
			# Check ancestor clipping
			var n := node.get_parent()
			while n:
				var canvas_item := n as CanvasItem
				if canvas_item and canvas_item.clip_children_mode != CanvasItem.CLIP_CHILDREN_DISABLED:
					warnings.append("Ancestor \"%s\" clips its children, so this CanvasGroup will not function properly." % canvas_item.name)
					break
				var canvas_group := n as CanvasGroup
				if canvas_group:
					warnings.append("Ancestor \"%s\" is a CanvasGroup, so this CanvasGroup will not function properly." % canvas_group.name)
					break
				n = n.get_parent()

		"LightOccluder2D":
			var occluder := node as LightOccluder2D
			if occluder.occluder_polygon == null:
				warnings.append("An occluder polygon must be set (or drawn) for this occluder to take effect.")
			elif occluder.occluder_polygon.polygon.is_empty():
				warnings.append("The occluder polygon for this occluder is empty. Please draw a polygon.")

		"MeshInstance2D":
			var mesh_inst := node as MeshInstance2D
			if mesh_inst.mesh == null:
				warnings.append("MeshInstance2D requires a Mesh to render anything. Please add a mesh resource for it!")

		"NavigationObstacle2D":
			var global_scale: Vector2 = node.get_global_scale()
			if global_scale.x < 0.001 or global_scale.y < 0.001:
				warnings.append("NavigationObstacle2D does not support negative or zero scaling.")

		"ParallaxLayer":
			var parent := node.get_parent()
			if not (parent is ParallaxBackground):
				warnings.append("ParallaxLayer node only works when set as child of a ParallaxBackground node.")

		"Polygon2D":
			var polygon := node as Polygon2D
			if polygon.polygon.is_empty():
				warnings.append("Polygon2D requires at least 3 points to render anything.")

		"RemoteTransform2D":
			var remote_transform := node as RemoteTransform2D
			if not remote_transform.has_node(remote_transform.remote_node) or not (remote_transform.get_node(remote_transform.remote_node) is Node2D):
				warnings.append("Path property must point to a valid Node2D node to work.")

		"ShapeCast2D":
			var shape_cast := node as ShapeCast2D
			if shape_cast.shape == null:
				warnings.append("This node cannot interact with other objects unless a Shape2D is assigned.")

		"TileMap":
			warnings.append("The TileMap node is deprecated as it is superseded by the use of multiple TileMapLayer nodes. To convert a TileMap to a set of TileMapLayer nodes, open the TileMap bottom panel with this node selected, click the toolbox icon in the top-right corner and choose \"Extract TileMap layers as individual TileMapLayer nodes\".")

		"TouchScreenButton":
			var button := node as TouchScreenButton
			if button.texture_normal == null and button.texture_pressed == null:
				warnings.append("TouchScreenButton requires at least one texture to be visible.")

		# === Control hierarchy (UI) ===
		"Container":
			if node.get_class() == "Container" and node.get_script() == null:
				warnings.append("Container by itself serves no purpose unless a script configures its children placement behavior. If you don't intend to add a script, use a plain Control node instead.")

		"Label":
			var label := node as Label
			if label.text.is_empty():
				warnings.append("Label has no text set.")

		"LineEdit":
			var line_edit := node as LineEdit
			if line_edit.secret_character.length() > 1:
				warnings.append("Secret Character property supports only one character. Extra characters will be ignored.")

		"Range":
			var range := node as Range
			if range.ratio and range.min_value < 0:
				warnings.append("If \"Exp Edit\" is enabled, \"Min Value\" must be greater or equal to 0.")

		"ScrollContainer":
			var child_count := 0
			for child in node.get_children():
				if child is Control and child != node.get("h_scroll") and child != node.get("v_scroll"):
					child_count += 1
			if child_count != 1:
				warnings.append("ScrollContainer is intended to work with a single child control. Use a container as child (VBox, HBox, etc.), or a Control and set the custom minimum size manually.")

		"SubViewportContainer":
			var has_viewport := false
			for child in node.get_children():
				if child is SubViewport:
					has_viewport = true
					break
			if not has_viewport:
				warnings.append("This node doesn't have a SubViewport as child, so it can't display its intended content. Consider adding a SubViewport as a child to provide something displayable.")

		"TextEdit":
			# No specific warnings in JSON
			pass

		"TextureRect":
			var texture_rect := node as TextureRect
			if texture_rect.texture == null:
				warnings.append("TextureRect requires a texture to be set to display anything.")

		"Tree":
			var tree := node as Tree
			if tree.get_columns() == 0:
				warnings.append("Tree requires at least one column to display anything.")

		# === Animation ===
		"AnimationPlayer":
			var anim_player := node as AnimationPlayer
			if anim_player.get_animation_list().is_empty():
				warnings.append("AnimationPlayer has no animations. Add an animation resource to the AnimationPlayer library.")

		"AnimationTree":
			var anim_tree := node as AnimationTree
			if anim_tree.tree_root == null:
				warnings.append("AnimationTree requires an AnimationNode as its tree root to function.")

		# === Audio ===
		"AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D":
			var player := node as AudioStreamPlayer
			if player.stream == null:
				warnings.append("No audio stream is assigned. Assign a stream to play audio.")

		# === Particles ===
		"GPUParticles2D":
			var particles := node as GPUParticles2D
			if particles.process_material == null:
				warnings.append("A material to process the particles is not assigned, so no behavior is imprinted.")

		"GPUParticles3D":
			var particles := node as GPUParticles3D
			if particles.process_material == null:
				warnings.append("A material to process the particles is not assigned, so no behavior is imprinted.")
			if particles.draw_passes == 0:
				warnings.append("Nothing is visible because meshes have not been assigned to draw passes.")

		"CPUParticles2D":
			var particles := node as CPUParticles2D
			# Check for animation without proper material
			var has_anim: bool = particles.param_max[CPUParticles2D.PARAM_ANIM_SPEED] != 0.0 or particles.param_max[CPUParticles2D.PARAM_ANIM_OFFSET] != 0.0
			if has_anim and particles.material == null:
				warnings.append("CPUParticles2D animation requires the usage of a CanvasItemMaterial with \"Particles Animation\" enabled.")

		"CPUParticles3D":
			var particles := node as CPUParticles3D
			if particles.mesh == null:
				warnings.append("Nothing is visible because no mesh has been assigned.")

		# === CSG ===
		"CSGShape3D":
			var csg := node as CSGShape3D
			# Check if the shape is empty (simplified check)
			if csg.is_root_shape():
				warnings.append("The CSGShape3D has an empty shape. CSGShape3D empty shapes typically occur because the mesh is not manifold.")

		# === Timer ===
		"Timer":
			var timer := node as Timer
			if timer.wait_time < 0.05:
				warnings.append("Very low timer wait times (< 0.05 seconds) may behave in significantly different ways depending on the rendered or physics frame rate. Consider using a script's process loop instead of relying on a Timer for very low wait times.")

		# === Viewport ===
		"Viewport":
			var viewport := node as Viewport
			if viewport.size.x <= 1 or viewport.size.y <= 1:
				warnings.append("The Viewport size must be greater than or equal to 2 pixels on both dimensions to render anything.")

		# === WorldEnvironment ===
		"WorldEnvironment":
			var world_env := node as WorldEnvironment
			if world_env.environment == null and world_env.camera_attributes == null:
				warnings.append("To have any visible effect, WorldEnvironment requires its \"Environment\" property to contain an Environment, its \"Camera Attributes\" property to contain a CameraAttributes resource, or both.")

		# === Joints ===
		"Joint2D", "Joint3D":
			# Base joint warning is checked in derived classes
			pass

		"PinJoint2D", "PinJoint3D", "HingeJoint3D", "ConeTwistJoint3D", "Generic6DOFJoint3D", "SliderJoint3D":
			# Joint-specific warnings are set via properties
			pass

		# === Camera ===
		"Camera2D", "Camera3D":
			# Camera warnings are typically minimal
			pass

		# === Light ===
		"Light2D", "Light3D":
			var light := node as Light3D
			if light and light.light_energy == 0:
				warnings.append("Light has zero energy and will not illuminate anything.")

		# === ReflectionProbe ===
		"ReflectionProbe":
			var probe := node as ReflectionProbe
			if probe and probe.size == Vector3.ZERO:
				warnings.append("ReflectionProbe has zero size and will not capture anything.")

		# === Decal ===
		"Decal":
			var decal := node as Decal
			if decal and decal.textures[Decal.TEXTURE_ALBEDO] == null and decal.textures[Decal.TEXTURE_NORMAL] == null:
				warnings.append("The decal has no textures loaded into any of its texture properties, and will therefore not be visible.")

		# === VoxelGI ===
		"VoxelGI":
			var voxel := node as VoxelGI
			if voxel.probe_data == null:
				warnings.append("No VoxelGI data set, so this node is disabled. Bake static objects to enable GI.")

		# === OccluderInstance3D ===
		"OccluderInstance3D":
			var occluder := node as OccluderInstance3D
			if occluder.occluder == null:
				warnings.append("No occluder mesh is defined in the Occluder property, so no occlusion culling will be performed using this OccluderInstance3D.")

		# === CollisionObject children checks ===
		"PhysicsBody2D", "PhysicsBody3D":
			# Already handled by specific classes
			pass

		# === Control clipping check ===
		"CanvasItem":
			if node.has_method("get_clip_children_mode") and node.get("clip_children_mode") != CanvasItem.CLIP_CHILDREN_DISABLED:
				# Check for ancestor clipping conflicts
				var n := node.get_parent()
				while n:
					var ancestor := n as CanvasItem
					if ancestor and ancestor.has_method("get_clip_children_mode") and ancestor.get("clip_children_mode") != CanvasItem.CLIP_CHILDREN_DISABLED:
						warnings.append("Ancestor \"%s\" clips its children, so this node will not be able to clip its children." % ancestor.name)
						break
					n = n.get_parent()

		_:
			# Unknown class - no warnings
			pass

	return warnings


## Creates the editor_get_node_warnings tool
func _create_get_node_warnings_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_GET_NODE_WARNINGS,
		"Gets configuration warnings for a specific node in the current scene. Returns warnings that Godot would normally display in the editor for improperly configured nodes.",
		{
			"path": {
				"type": "string",
				"description": "Node path in the scene tree. Can be absolute (/root/Main/Player) or relative (Main/Player)"
			}
		},
		["path"]
	)
	return MCPToolHandler.new(definition, _execute_get_node_warnings)


## Executes the editor_get_node_warnings tool
func _execute_get_node_warnings(params: Dictionary) -> MCPToolResult:
	# Check editor interface availability
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	# Get scene root
	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if scene_root == null:
		return MCPToolResult.error("No scene is currently open in the editor", MCPError.Code.TOOL_EXECUTION_ERROR)

	# Get and validate path parameter
	var path: String = params.get("path", "")
	if path.is_empty():
		return MCPToolResult.error("Parameter 'path' is required", MCPError.Code.INVALID_PARAMS)

	# Resolve node
	var node: Node = _resolve_node(path)
	if node == null:
		return MCPToolResult.error("Node not found: " + path, MCPError.Code.NOT_FOUND)

	# Get warnings using native method
	var warnings: PackedStringArray = _get_node_warnings(node)

	# Build result
	var result := ConfigurationWarningResult.new(
		str(node.get_path()),
		node.name,
		node.get_class(),
		warnings
	)

	# Return appropriate message based on warnings
	if result.has_warnings():
		var warning_count: int = result.warnings.size()
		var message := "Node %s has %d configuration warning(s):\n" % [result.node_name, warning_count]
		for i in range(warning_count):
			message += "  %d. %s\n" % [i + 1, result.warnings[i]]
		return MCPToolResult.text(message, result.to_dict())
	else:
		return MCPToolResult.text("Node %s has no configuration warnings" % result.node_name, result.to_dict())


## Creates the editor_get_scene_warnings tool
func _create_get_scene_warnings_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_GET_SCENE_WARNINGS,
		"Gets configuration warnings for all nodes in the current scene. Returns a comprehensive list of warnings across the entire scene.",
		{},
		[]
	)
	return MCPToolHandler.new(definition, _execute_get_scene_warnings)


## Creates the editor_get_warning_types tool (placeholder for US3)
func _create_get_warning_types_tool() -> MCPToolHandler:
	var definition := MCPToolDefinition.create(
		TOOL_GET_WARNING_TYPES,
		"Queries available configuration warning types for Godot node classes. Returns information about which node classes have configuration warnings.",
		{
			"class_name": {
				"type": "string",
				"description": "Optional filter for a specific node class",
				"required": false
			}
		},
		[]
	)
	return MCPToolHandler.new(definition, _execute_get_warning_types_placeholder)


## Executes the editor_get_scene_warnings tool
func _execute_get_scene_warnings(_params: Dictionary = {}) -> MCPToolResult:
	# Check editor interface availability
	if _editor_interface == null:
		return MCPToolResult.error("Editor interface not available", MCPError.Code.INTERNAL_ERROR)

	# Get scene root
	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if scene_root == null:
		return MCPToolResult.error("No scene is currently open in the editor", MCPError.Code.TOOL_EXECUTION_ERROR)

	# Collect warnings from all nodes in the scene
	var warnings: Array = []
	var total_nodes: int = _collect_warnings_recursive(scene_root, warnings)

	# Build response
	var response := SceneWarningsResponse.new(warnings, total_nodes, warnings.size())

	if response.nodes_with_warnings > 0:
		var message := "Found %d configuration warning(s) across %d node(s) in scene:\n\n" % [response.nodes_with_warnings, response.total_nodes_checked]
		for warning_result in warnings:
			message += "[%s] %s:\n" % [warning_result.godot_class_name, warning_result.path]
			for w in warning_result.warnings:
				message += "  - %s\n" % w
			message += "\n"
		return MCPToolResult.text(message, response.to_dict())
	else:
		return MCPToolResult.text(
			"No configuration warnings found in scene (checked %d node(s))" % response.total_nodes_checked,
			response.to_dict()
		)


## Recursively collects warnings from all nodes in the scene tree
## Returns the total count of nodes checked
func _collect_warnings_recursive(node: Node, warnings: Array) -> int:
	var total_count := 1

	# Get warnings for this node
	var node_warnings: PackedStringArray = _get_node_warnings(node)
	if not node_warnings.is_empty():
		var result := ConfigurationWarningResult.new(
			str(node.get_path()),
			node.name,
			node.get_class(),
			node_warnings
		)
		warnings.append(result)

	# Recursively check children
	for child in node.get_children():
		total_count += _collect_warnings_recursive(child, warnings)

	return total_count


## Placeholder execute method for warning types (US3 - not yet implemented)
func _execute_get_warning_types_placeholder(_params: Dictionary = {}) -> MCPToolResult:
	return MCPToolResult.error("Warning types tool not yet implemented - see User Story 3", MCPError.Code.INTERNAL_ERROR)


## Resolves a node path from the editor context
## Handles absolute paths (/root/...) and relative paths from scene root
## Returns null if editor_interface is not available, scene_root is not available, or node is not found
func _resolve_node(path: String) -> Node:
	if _editor_interface == null:
		return null

	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if scene_root == null:
		return null

	# Handle absolute paths (/root/...)
	if path.begins_with("/root/"):
		var relative_path: String = path.substr(6)
		return scene_root.get_node_or_null(relative_path)

	# Handle relative paths from scene root
	return scene_root.get_node_or_null(path)

extends CanvasLayer

var color_rect: ColorRect
var shader_material: ShaderMaterial
var is_transitioning: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var shader = load("res://Shaders/circle_wipe.gdshader")
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader

	color_rect = ColorRect.new()
	color_rect.material = shader_material
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(color_rect)

	shader_material.set_shader_parameter("progress", 0.0)

func transition_to(scene_path: String, spawn_position: Vector2) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Block player input
	get_tree().paused = true

	# Phase 1: circle closes
	var tween_close = create_tween()
	tween_close.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_close.tween_property(shader_material, "shader_parameter/progress", 1.0, 0.4)
	await tween_close.finished

	# Phase 2: change scene
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame

	# Phase 3: place player at spawn position
	var player: Player = null
	for node in get_tree().current_scene.get_children():
		if node is Player:
			player = node
			break
	if player:
		player.global_position = spawn_position

	# Phase 4: circle opens
	var tween_open = create_tween()
	tween_open.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_open.tween_property(shader_material, "shader_parameter/progress", 0.0, 0.4)
	await tween_open.finished

	# Unblock input
	get_tree().paused = false
	is_transitioning = false

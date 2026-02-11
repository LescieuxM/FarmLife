class_name Player
extends CharacterBody2D

@export var speed: float = 200.0
@export var dash_speed: float = 230.0
@export var dash_duration: float = 0.8
@export var dash_cooldown: float = 2.0
@export var hit_max_reach: float = 48.0

var _last_direction := Vector2.DOWN
var _is_dashing := false
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _is_hitting := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var torch_light: PointLight2D = $TorchLight
@onready var tile_overlay: Sprite2D = $TileHoverOverlay

func _enter_tree() -> void:
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if camera:
		if is_multiplayer_authority():
			camera.make_current()
		else:
			camera.enabled = false
	call_deferred("_connect_hotbar")


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and !is_multiplayer_authority(): return
	if _is_hitting:
		move_and_slide()
		return

	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)

	if Input.is_action_just_pressed("ui_accept") and not _is_dashing and _dash_cooldown_timer <= 0.0:
		_start_dash()

	if _is_dashing:
		_dash_timer -= delta
		velocity = _last_direction * dash_speed
		move_and_slide()
		if _dash_timer <= 0.0:
			_is_dashing = false
			_dash_cooldown_timer = dash_cooldown
			_play_anim(_last_direction, false)
		return

	var direction := _get_input_direction()
	if direction != Vector2.ZERO:
		_last_direction = direction

	velocity = direction * speed
	move_and_slide()
	_play_anim(_last_direction, direction != Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and !is_multiplayer_authority():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		torch_light.enabled = !torch_light.enabled

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_hitting or _is_dashing:
			return
		_try_hit()


# ── Hitting hittable objects ────────────────────────────────────────────

func _try_hit() -> void:
	var generator := _get_generator()
	if generator == null:
		return

	var mouse_global := get_global_mouse_position()
	var cell := generator.world_to_cell(mouse_global)

	if not generator.is_hittable_cell(cell):
		return

	var cell_center := generator.cell_to_world(cell)
	var dist := global_position.distance_to(cell_center)
	if dist > hit_max_reach:
		return

	var tool_name := generator.get_hittable_tool(cell)  # "axe", "mine", …

	# Check hotbar has the correct tool selected
	var hotbar := _get_hotbar()
	if hotbar and hotbar.get_selected_tool() != tool_name:
		return
	var dir_to_target := (cell_center - global_position).normalized()

	_is_hitting = true
	velocity = Vector2.ZERO

	# Pick direction suffix and set cardinal _last_direction
	var dir_suffix: String
	if absf(dir_to_target.y) > absf(dir_to_target.x):
		if dir_to_target.y > 0:
			dir_suffix = "down"
			_last_direction = Vector2.DOWN
		else:
			dir_suffix = "top"
			_last_direction = Vector2.UP
	else:
		dir_suffix = "side"
		_last_direction = Vector2.RIGHT if dir_to_target.x >= 0 else Vector2.LEFT

	# Play tool animation (e.g. "axe_down", "mine_side")
	var tool_anim := tool_name + "_" + dir_suffix
	anim_player.play(tool_anim)
	if sprite and dir_suffix == "side":
		sprite.flip_h = dir_to_target.x < 0

	# Hit mid-swing (~0.3s into the ~0.56s animation)
	get_tree().create_timer(0.3).timeout.connect(
		func(): generator.hit_cell(cell))

	await anim_player.animation_finished
	_is_hitting = false
	_play_anim(_last_direction, false)


# ── UI access ─────────────────────────────────────────────────────────

func _connect_hotbar() -> void:
	var hotbar := _get_hotbar()
	if hotbar and hotbar.has_signal("tool_changed"):
		hotbar.tool_changed.connect(_on_tool_changed)


func _on_tool_changed(tool_name: String) -> void:
	if tile_overlay and tile_overlay.has_method("set_overlay_enabled"):
		tile_overlay.set_overlay_enabled(tool_name == "axe" or tool_name == "mine")


func _get_hotbar() -> Control:
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		return hud.get_node_or_null("Hotbar")
	return null


# ── Generator access ───────────────────────────────────────────────────

func _get_generator() -> RandomTileGenerator:
	var parent := get_parent()
	if parent is RandomTileGenerator:
		return parent as RandomTileGenerator
	if parent != null:
		for child in parent.get_children():
			if child is RandomTileGenerator:
				return child as RandomTileGenerator
		var root := get_tree().current_scene
		if root is RandomTileGenerator:
			return root as RandomTileGenerator
	return null


# ── Movement helpers ───────────────────────────────────────────────────

func _get_input_direction() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		d.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1
	return d.normalized()


func _start_dash() -> void:
	_is_dashing = true
	_dash_timer = dash_duration
	_play_roll_anim(_last_direction)


func _play_roll_anim(direction: Vector2) -> void:
	if not anim_player:
		return
	if direction.y > 0:
		anim_player.play("roll_down")
		if sprite:
			sprite.flip_h = false
	elif direction.y < 0:
		anim_player.play("roll_top")
		if sprite:
			sprite.flip_h = false
	else:
		anim_player.play("roll_side")
		if sprite:
			sprite.flip_h = direction.x < 0


func _play_anim(direction: Vector2, walking: bool) -> void:
	if not anim_player:
		return
	var prefix := "walk_" if walking else "idle_"
	if direction.y > 0:
		anim_player.play(prefix + "down")
		if sprite:
			sprite.flip_h = false
	elif direction.y < 0:
		anim_player.play(prefix + "top")
		if sprite:
			sprite.flip_h = false
	else:
		anim_player.play(prefix + "side")
		if sprite:
			sprite.flip_h = direction.x < 0

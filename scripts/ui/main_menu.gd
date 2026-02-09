extends Control

@onready var radl_book: Sprite2D = $RadlBook
@onready var page_one: Control = $RadlBook/page_one
@onready var btn_start: Button = $RadlBook/page_one/btn_start
@onready var btn_host: Button = $RadlBook/page_one/btn_host
@onready var btn_join: Button = $RadlBook/page_one/btn_join

var book_opened: bool = false

func _ready() -> void:
	btn_start.pressed.connect(_on_btn_start_pressed)
	btn_host.pressed.connect(_on_btn_host_pressed)
	btn_join.pressed.connect(_on_btn_join_pressed)

	# Disable multiplayer buttons when Steam is not available.
	if not SteamManager.is_steam_available():
		btn_host.disabled = true
		btn_join.disabled = true

	# If we joined via a Steam invitation, go straight to the game.
	SteamManager.joined_lobby.connect(_on_joined_lobby)

func _input(event: InputEvent) -> void:
	if book_opened:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_click_on_sprite(radl_book, event.position):
			book_opened = true
			_open_book()

func _is_click_on_sprite(sprite: Sprite2D, click_pos: Vector2) -> bool:
	var tex = sprite.texture
	if tex == null:
		return false
	var frame_width := tex.get_width() / float(sprite.hframes)
	var frame_height := tex.get_height()
	var frame_size := Vector2(frame_width, frame_height) * sprite.scale
	var origin := sprite.global_position - frame_size / 2.0
	return Rect2(origin, frame_size).has_point(click_pos)

func _open_book() -> void:
	for frame_idx in range(1, 4):
		radl_book.frame = frame_idx
		await get_tree().create_timer(0.15).timeout
	page_one.visible = true

func _on_btn_start_pressed() -> void:
	SceneTransition.transition_to("res://scenes/main_game.tscn", Vector2(120, 120))

func _on_btn_host_pressed() -> void:
	btn_host.disabled = true
	btn_join.disabled = true
	SteamManager.lobby_ready.connect(_on_lobby_ready, CONNECT_ONE_SHOT)
	SteamManager.create_lobby()

func _on_btn_join_pressed() -> void:
	# Open the Steam overlay – the player picks a friend's game to join.
	# The actual join happens via _on_join_requested in SteamManager.
	if SteamManager.is_steam_available():
		Steam.activateGameOverlay("friends")

func _on_lobby_ready() -> void:
	SceneTransition.transition_to("res://scenes/main_game.tscn", Vector2(120, 120))

func _on_joined_lobby() -> void:
	SceneTransition.transition_to("res://scenes/main_game.tscn", Vector2(120, 120))

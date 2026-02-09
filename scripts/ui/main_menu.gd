extends Control

@onready var radl_book: Sprite2D = $RadlBook
@onready var page_one: Control = $RadlBook/page_one
@onready var btn_start: Button = $RadlBook/page_one/btn_start

var book_opened: bool = false

func _ready() -> void:
	btn_start.pressed.connect(_on_btn_start_pressed)

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
	var frame_width = tex.get_width() / sprite.hframes
	var frame_height = tex.get_height()
	var size = Vector2(frame_width, frame_height) * sprite.scale
	var origin = sprite.global_position - size / 2.0
	return Rect2(origin, size).has_point(click_pos)

func _open_book() -> void:
	for frame_idx in range(1, 4):
		radl_book.frame = frame_idx
		await get_tree().create_timer(0.15).timeout
	page_one.visible = true

func _on_btn_start_pressed() -> void:
	SceneTransition.transition_to("res://scenes/main_game.tscn", Vector2(120, 120))

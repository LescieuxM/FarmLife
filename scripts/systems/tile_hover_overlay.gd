extends Sprite2D
## Overlay that follows the mouse cursor snapped to the tile grid.
## Shows a white overlay when the hovered tile is within reach,
## or a red overlay when it is too far from the player.

## Maximum distance (in pixels) between the player and the hovered
## tile center for the overlay to be considered "in range" (white).
@export var max_reach: float = 48.0

## Size of a single tile in pixels (matches the TileSet).
@export var tile_size: int = 16

## Whether the overlay is currently visible.
var _overlay_enabled: bool = false

func _ready() -> void:
	# The texture is 32×16 with two 16×16 halves.
	# We only show one half at a time via region.
	region_enabled = true
	region_rect = Rect2(0, 0, tile_size, tile_size)
	# Make the overlay slightly transparent so the tile beneath is visible.
	modulate.a = 0.45
	# Render above most things but below UI.
	z_index = 10
	# The overlay lives in world space; its position is set every frame.
	top_level = true
	# Start hidden by default.
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Toggle the overlay with the P key (for testing).
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		set_overlay_enabled(!_overlay_enabled)

func _process(_delta: float) -> void:
	# Only update position and overlay state if enabled.
	if not _overlay_enabled:
		return

	# Get the mouse position in world (global) coordinates.
	var mouse_global: Vector2 = get_global_mouse_position()

	# Snap to tile grid (tile centres sit at multiples of tile_size).
	var snapped_x := floorf(mouse_global.x / tile_size) * tile_size + tile_size * 0.5
	var snapped_y := floorf(mouse_global.y / tile_size) * tile_size + tile_size * 0.5
	global_position = Vector2(snapped_x, snapped_y)

	# Distance between the player and the hovered tile centre.
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return

	var dist := player.global_position.distance_to(global_position)

	# Left half (0,0,16,16) = white / in range
	# Right half (16,0,16,16) = red / out of range
	if dist <= max_reach:
		region_rect = Rect2(0, 0, tile_size, tile_size)
	else:
		region_rect = Rect2(tile_size, 0, tile_size, tile_size)

## Enable or disable the tile hover overlay.
func set_overlay_enabled(enabled: bool) -> void:
	_overlay_enabled = enabled
	visible = enabled

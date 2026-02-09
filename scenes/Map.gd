extends Node2D

@export var tree_scene: PackedScene
@export var rock_scene: PackedScene
@export var tree_count: int = 30
@export var rock_count: int = 25
@export var min_distance: float = 32.0

@onready var tile_map: TileMap = $TileMap
@onready var ysort_node: Node2D = $YSort


func _ready() -> void:
	var bounds := _get_map_bounds_world()
	var used: Array[Vector2] = []
	_spawn_scenes(tree_scene, tree_count, bounds, used)
	_spawn_scenes(rock_scene, rock_count, bounds, used)


func _get_map_bounds_world() -> Rect2:
	var rect: Rect2i = tile_map.get_used_rect()
	if rect.has_area():
		var tl := tile_map.map_to_local(rect.position)
		var br := tile_map.map_to_local(rect.end)
		return Rect2(tl, br - tl)
	return Rect2(-400.0, -400.0, 800.0, 800.0)


func _spawn_scenes(scene: PackedScene, count: int, bounds: Rect2, used: Array[Vector2]) -> void:
	if scene == null:
		return
	var max_attempts := count * 50
	var n := 0
	for _i in max_attempts:
		if n >= count:
			break
		var pos := Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y)
		)
		if _too_close(pos, used):
			continue
		var inst := scene.instantiate()
		inst.position = pos
		ysort_node.add_child(inst)
		used.append(pos)
		n += 1


func _too_close(pos: Vector2, used: Array[Vector2]) -> bool:
	for u in used:
		if pos.distance_to(u) < min_distance:
			return true
	return false

class_name RandomTileGenerator
extends Node2D
##
## Generates random trees and stones. Manages all hittable objects with a
## unified tracking system. Each hittable has a type, HP, tool, dimensions,
## and layer. Extensible for new object types and item drops.
##

## Emitted when any hittable object is fully destroyed.
## Connect to this to spawn item drops, particles, etc.
signal object_destroyed(type: String, root: Vector2i, world_pos: Vector2)

@onready var bounds_layer: TileMapLayer = $TileMapLayer
@onready var layer_tree: TileMapLayer = $TileMapLayerTree
@onready var layer_stone: TileMapLayer = $TileMapLayerStone
## Champignons : doit être un enfant nommé TileMapLayerVegetations (TileMapLayer avec un TileSet).
var layer_vegetations: TileMapLayer

# ── Tree atlas layout (3 cols × 5 rows per frame) ──────────────────────
const TREE_PATTERN: Array = [
	{"offset": Vector2i(0, 0), "atlas_coords": Vector2i(4, 0)},
	{"offset": Vector2i(1, 0), "atlas_coords": Vector2i(5, 0)},
	{"offset": Vector2i(2, 0), "atlas_coords": Vector2i(6, 0)},
	{"offset": Vector2i(0, 1), "atlas_coords": Vector2i(4, 1)},
	{"offset": Vector2i(1, 1), "atlas_coords": Vector2i(5, 1)},
	{"offset": Vector2i(2, 1), "atlas_coords": Vector2i(6, 1)},
	{"offset": Vector2i(0, 2), "atlas_coords": Vector2i(4, 2)},
	{"offset": Vector2i(1, 2), "atlas_coords": Vector2i(5, 2)},
	{"offset": Vector2i(2, 2), "atlas_coords": Vector2i(6, 2)},
	{"offset": Vector2i(0, 3), "atlas_coords": Vector2i(4, 3)},
	{"offset": Vector2i(1, 3), "atlas_coords": Vector2i(5, 3)},
	{"offset": Vector2i(2, 3), "atlas_coords": Vector2i(6, 3)},
	{"offset": Vector2i(0, 4), "atlas_coords": Vector2i(4, 4)},
	{"offset": Vector2i(1, 4), "atlas_coords": Vector2i(5, 4)},
	{"offset": Vector2i(2, 4), "atlas_coords": Vector2i(6, 4)},
]

const TREE_FRAME_STUMP: int = 0
const TREE_FRAME_NORMAL: int = 4
const TREE_FRAME_HIT1: int = 8
const TREE_FRAME_HIT2: int = 12
const TREE_FRAME_HIT3: int = 16
const TREE_FRAME_PREBREAK1: int = 20
const TREE_FRAME_PREBREAK2: int = 23   # 4 cols wide, shifted -1
const TREE_PREBREAK2_WIDTH: int = 4

const TREE_WIDTH: int = 3
const TREE_HEIGHT: int = 5
const TRUNK_OFFSETS: Array = [Vector2i(1, 3)]

const ANIM_STEP_DURATION: float = 0.12

# ── Exports ─────────────────────────────────────────────────────────────
@export_range(0.0, 1.0, 0.01) var density_tree: float = 0.12
@export var tree_placement_max_attempts: int = 2000
@export_range(0.0, 1.0, 0.01) var density_stone: float = 0.03
## Vitesse d'animation des champignons (images par seconde). Pas de placement aléatoire : seules les tuiles déjà sur le calque sont animées.
@export var vegetations_anim_fps: float = 6.0
@export var use_custom_map_bounds: bool = true
@export var map_bounds_min: Vector2i = Vector2i(-15, 1)
@export var map_bounds_max: Vector2i = Vector2i(58, 33)
@export var random_seed_value: int = 0
@export var generate_on_ready: bool = true

# ── Unified hittable tracking ───────────────────────────────────────────
## Maps each hittable cell -> root cell of its object.
var _hittable_cells: Dictionary = {}
## Maps root cell -> info dict:
##   { type:String, hp:int, width:int, height:int,
##     layer:TileMapLayer, tool:String, hittable_offsets:Array }
var _hittable_info: Dictionary = {}

var _tree_source_id: int = -1
## Champignons animés : { cell, frames } pour _process.
var _vegetation_anim_cells: Array = []
var _vegetation_anim_time: float = 0.0


# ── Lifecycle ───────────────────────────────────────────────────────────

func _ready() -> void:
	if bounds_layer == null:
		push_warning("RandomTileGenerator: bounds_layer introuvable.")
		return
	if layer_tree == null and layer_stone == null:
		push_warning("RandomTileGenerator: TileMapLayerTree et TileMapLayerStone introuvables.")
		return
	# Connect drops: when an object is destroyed, spawn loot via InventoryManager
	object_destroyed.connect(func(type: String, _root, world_pos: Vector2):
		InventoryManager.spawn_drops(type, world_pos))
	if generate_on_ready:
		call_deferred("generate")


func _process(delta: float) -> void:
	# Animation champignons
	if not _vegetation_anim_cells.is_empty() and layer_vegetations != null:
		_vegetation_anim_time += delta
		var v_frames: Array = _vegetation_anim_cells[0].frames
		if not v_frames.is_empty():
			var v_count: int = v_frames.size()
			var v_index: int = int(_vegetation_anim_time * vegetations_anim_fps) % v_count
			var v_data: Dictionary = v_frames[v_index]
			for entry in _vegetation_anim_cells:
				layer_vegetations.set_cell(entry.cell, v_data.source_id, v_data.atlas_coords, 0)


func generate() -> void:
	if bounds_layer == null:
		return
	if random_seed_value != 0:
		seed(random_seed_value)

	_hittable_cells.clear()
	_hittable_info.clear()
	if layer_vegetations == null:
		layer_vegetations = get_node_or_null("TileMapLayerVegetations") as TileMapLayer

	var rect: Rect2i
	if use_custom_map_bounds:
		var w := map_bounds_max.x - map_bounds_min.x + 1
		var h := map_bounds_max.y - map_bounds_min.y + 1
		rect = Rect2i(map_bounds_min.x, map_bounds_min.y, w, h)
	else:
		rect = bounds_layer.get_used_rect()
		if not rect.has_area():
			rect = Rect2i(-50, -50, 100, 100)

	var cells: Array[Vector2i] = _rect_to_cells(rect)
	cells.shuffle()

	var occupied: Dictionary = {}

	if layer_tree != null and layer_tree.tile_set != null:
		_find_tree_source_id()
		_fill_trees(cells, occupied)

	var cells_free: Array[Vector2i] = []
	for c in cells:
		if not occupied.has(c):
			cells_free.append(c)
	if layer_stone != null and layer_stone.tile_set != null:
		_fill_stones(cells_free)
	if layer_vegetations != null and layer_vegetations.tile_set != null:
		_build_vegetation_anim_from_layer()

	if layer_tree != null:
		layer_tree.update_internals()
	if layer_stone != null:
		layer_stone.update_internals()
	if layer_vegetations != null:
		layer_vegetations.update_internals()


# ── Public API ──────────────────────────────────────────────────────────

func is_hittable_cell(cell: Vector2i) -> bool:
	return _hittable_cells.has(cell)


## Returns the tool name for the hittable at cell ("axe", "mine", …).
func get_hittable_tool(cell: Vector2i) -> String:
	if not _hittable_cells.has(cell):
		return ""
	var root: Vector2i = _hittable_cells[cell]
	return _hittable_info[root].tool


## Hit the object at cell. Returns true if the hit was registered.
func hit_cell(cell: Vector2i) -> bool:
	if not _hittable_cells.has(cell):
		return false
	var root: Vector2i = _hittable_cells[cell]
	if not _hittable_info.has(root):
		return false

	var info: Dictionary = _hittable_info[root]
	info.hp -= 1

	if info.hp > 0:
		_on_hit(root, info)
	else:
		_on_destroy(root, info)
	return true


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return bounds_layer.local_to_map(bounds_layer.to_local(world_pos))


func cell_to_world(cell: Vector2i) -> Vector2:
	return bounds_layer.to_global(bounds_layer.map_to_local(cell))


# ── Hit / Destroy dispatch ──────────────────────────────────────────────

func _on_hit(root: Vector2i, info: Dictionary) -> void:
	match info.type:
		"tree":
			_play_tree_hit_anim(root)
		_:
			_shake_object(root)


func _on_destroy(root: Vector2i, info: Dictionary) -> void:
	match info.type:
		"tree":
			_play_tree_last_hit_anim(root)
		_:
			_destroy_object(root)


# ── Registration helpers ────────────────────────────────────────────────

func _register_hittable(root: Vector2i, type: String, hp: int, width: int,
		height: int, layer: TileMapLayer, tool: String,
		hittable_offsets: Array) -> void:
	_hittable_info[root] = {
		"type": type, "hp": hp, "width": width, "height": height,
		"layer": layer, "tool": tool, "hittable_offsets": hittable_offsets,
	}
	for offset in hittable_offsets:
		_hittable_cells[root + offset] = root


func _unregister_hittable(root: Vector2i) -> void:
	if not _hittable_info.has(root):
		return
	var info: Dictionary = _hittable_info[root]
	for offset in info.hittable_offsets:
		_hittable_cells.erase(root + offset)
	_hittable_info.erase(root)


# ── Generic destroy ─────────────────────────────────────────────────────

func _destroy_object(root: Vector2i) -> void:
	var info: Dictionary = _hittable_info[root]
	var layer: TileMapLayer = info.layer
	for row in info.height:
		for col in info.width:
			layer.erase_cell(root + Vector2i(col, row))
	layer.update_internals()

	var world_pos := cell_to_world(root)
	object_destroyed.emit(info.type, root, world_pos)
	_unregister_hittable(root)


# ── Generic shake (works for any single-layer object) ───────────────────

func _shake_object(root: Vector2i) -> void:
	var info: Dictionary = _hittable_info[root]
	var layer: TileMapLayer = info.layer
	var tile_set := layer.tile_set
	var tile_size := Vector2(tile_set.tile_size)

	var container := Node2D.new()
	layer.add_child(container)

	var saved_tiles: Array = []

	for row in info.height:
		for col in info.width:
			var cell := root + Vector2i(col, row)
			var src_id := layer.get_cell_source_id(cell)
			if src_id == -1:
				continue
			var atlas_coords := layer.get_cell_atlas_coords(cell)
			saved_tiles.append({
				"cell": cell, "source_id": src_id, "atlas_coords": atlas_coords
			})

			var source := tile_set.get_source(src_id) as TileSetAtlasSource
			var spr := Sprite2D.new()
			spr.texture = source.texture
			spr.region_enabled = true
			spr.region_rect = Rect2(Vector2(atlas_coords) * tile_size, tile_size)
			spr.position = layer.map_to_local(cell)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			container.add_child(spr)

			layer.erase_cell(cell)

	var tween := create_tween()
	tween.tween_property(container, "position", Vector2(1, 0), 0.04)
	tween.tween_property(container, "position", Vector2(-1, 0), 0.04)
	tween.tween_property(container, "position", Vector2(1, 0), 0.04)
	tween.tween_property(container, "position", Vector2.ZERO, 0.04)
	tween.tween_callback(_restore_after_shake.bind(layer, saved_tiles, container))


func _restore_after_shake(layer: TileMapLayer, saved_tiles: Array,
		container: Node2D) -> void:
	for t in saved_tiles:
		layer.set_cell(t.cell, t.source_id, t.atlas_coords, 0)
	container.queue_free()


# ── Tree-specific animations ───────────────────────────────────────────

func _play_tree_hit_anim(root: Vector2i) -> void:
	var tween := create_tween()
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_HIT1))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_HIT2))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_HIT3))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_NORMAL))


func _play_tree_last_hit_anim(root: Vector2i) -> void:
	var tween := create_tween()
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_HIT1))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_HIT2))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_HIT3))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(_swap_tree_frame.bind(root, TREE_FRAME_PREBREAK1))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(
		_swap_tree_frame.bind(root, TREE_FRAME_PREBREAK2, TREE_PREBREAK2_WIDTH, -1))
	tween.tween_interval(ANIM_STEP_DURATION)
	tween.tween_callback(_finalize_tree_destroy.bind(root))


func _swap_tree_frame(root: Vector2i, col_offset: int,
		width: int = TREE_WIDTH, x_shift: int = 0) -> void:
	for row in TREE_HEIGHT:
		for col in width:
			var cell := root + Vector2i(col + x_shift, row)
			var atlas_coords := Vector2i(col_offset + col, row)
			layer_tree.set_cell(cell, _tree_source_id, atlas_coords, 0)


func _finalize_tree_destroy(root: Vector2i) -> void:
	# Erase extra column on the left from PREBREAK2 (shifted -1)
	for row in TREE_HEIGHT:
		layer_tree.erase_cell(root + Vector2i(-1, row))
	# Place stump tiles
	_swap_tree_frame(root, TREE_FRAME_STUMP)
	layer_tree.update_internals()

	var world_pos := cell_to_world(root + Vector2i(1, 2))
	object_destroyed.emit("tree", root, world_pos)
	_unregister_hittable(root)

	# Register stump as a new hittable
	_register_hittable(root, "stump", 3, TREE_WIDTH, TREE_HEIGHT,
		layer_tree, "axe", TRUNK_OFFSETS)


# ── Placement: trees ───────────────────────────────────────────────────

func _find_tree_source_id() -> void:
	var tile_set: TileSet = layer_tree.tile_set
	for i in range(tile_set.get_source_count()):
		var sid: int = tile_set.get_source_id(i)
		var src: TileSetSource = tile_set.get_source(sid)
		if src is TileSetAtlasSource:
			_tree_source_id = sid
			break


func _fill_trees(cells: Array[Vector2i], occupied: Dictionary) -> void:
	layer_tree.clear()

	if _tree_source_id < 0:
		push_warning("RandomTileGenerator: aucun TileSetAtlasSource pour les arbres.")
		return

	var target_fill: int = int(cells.size() * clamp(density_tree, 0.0, 1.0))
	var placed_cells: int = 0
	var attempts: int = 0

	while attempts < tree_placement_max_attempts and placed_cells < target_fill:
		attempts += 1
		var root: Vector2i = cells[randi() % cells.size()]

		var can_place := true
		for entry in TREE_PATTERN:
			if occupied.has(root + entry.offset):
				can_place = false
				break
		if not can_place:
			continue

		for entry in TREE_PATTERN:
			var cell: Vector2i = root + entry.offset
			layer_tree.set_cell(cell, _tree_source_id, entry.atlas_coords, 0)
			occupied[cell] = true
			placed_cells += 1

		_register_hittable(root, "tree", 5, TREE_WIDTH, TREE_HEIGHT,
			layer_tree, "axe", TRUNK_OFFSETS)

		if placed_cells >= target_fill:
			break


# ── Placement: stones ──────────────────────────────────────────────────

func _fill_stones(cells: Array[Vector2i]) -> void:
	layer_stone.clear()
	var tile_set: TileSet = layer_stone.tile_set
	var tiles: Array[Dictionary] = _collect_valid_tiles(tile_set)
	if tiles.is_empty():
		push_warning("RandomTileGenerator: aucun tuile valide pour les pierres.")
		return

	var count := int(cells.size() * clamp(density_stone, 0.0, 1.0))
	for i in min(count, cells.size()):
		var coords: Vector2i = cells[i]
		var t: Dictionary = tiles[randi() % tiles.size()]
		layer_stone.set_cell(coords, t.source_id, t.atlas_coords, 0)
		_register_hittable(coords, "stone", 3, 1, 1,
			layer_stone, "mine", [Vector2i(0, 0)])


## Enregistre les cellules déjà présentes sur le calque pour l'animation (aucun placement).
func _build_vegetation_anim_from_layer() -> void:
	_vegetation_anim_cells.clear()
	var tile_set: TileSet = layer_vegetations.tile_set
	## Les 6 frames du champignon, dans l’ordre chronologique (atlas : ligne puis colonne).
	var frames: Array[Dictionary] = _collect_vegetation_frames_ordered(tile_set, 6)
	if frames.is_empty():
		return
	for coords in layer_vegetations.get_used_cells():
		_vegetation_anim_cells.append({"cell": coords, "frames": frames})


# ── Utilities ──────────────────────────────────────────────────────────

func _rect_to_cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


## Retourne les tuiles végétation (champignons) triées par ordre atlas (y puis x), au plus max_frames.
func _collect_vegetation_frames_ordered(tile_set: TileSet, max_frames: int = 6) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(tile_set.get_source_count()):
		var source_id: int = tile_set.get_source_id(i)
		var source: TileSetSource = tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source as TileSetAtlasSource
			var grid: Vector2i = atlas.get_atlas_grid_size()
			for gy in range(grid.y):
				for gx in range(grid.x):
					if result.size() >= max_frames:
						return result
					var ac := Vector2i(gx, gy)
					var tile_coords: Vector2i = atlas.get_tile_at_coords(ac)
					if tile_coords != Vector2i(-1, -1):
						result.append({"source_id": source_id, "atlas_coords": tile_coords})
		if result.size() >= max_frames:
			break
	return result


func _collect_valid_tiles(tile_set: TileSet) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(tile_set.get_source_count()):
		var source_id: int = tile_set.get_source_id(i)
		var source: TileSetSource = tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source as TileSetAtlasSource
			var grid: Vector2i = atlas.get_atlas_grid_size()
			var seen: Dictionary = {}
			for gy in range(grid.y):
				for gx in range(grid.x):
					var ac := Vector2i(gx, gy)
					var tile_coords: Vector2i = atlas.get_tile_at_coords(ac)
					if tile_coords != Vector2i(-1, -1):
						var key := "%d_%d" % [tile_coords.x, tile_coords.y]
						if not seen.has(key):
							seen[key] = true
							result.append({"source_id": source_id, "atlas_coords": tile_coords})
	if result.is_empty() and tile_set.get_source_count() > 0:
		var sid: int = tile_set.get_source_id(0)
		result.append({"source_id": sid, "atlas_coords": Vector2i(0, 0)})
	return result

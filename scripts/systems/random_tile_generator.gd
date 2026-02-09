class_name RandomTileGenerator
extends Node2D
##
## Génère aléatoirement des arbres (pattern multi-tuiles fixe) et des pierres.
## Forme de l'arbre : tuiles atlas (5,0) à (6,4) + (7,3) et (4,3).
##

@onready var bounds_layer: TileMapLayer = $TileMapLayer
@onready var layer_tree: TileMapLayer = $TileMapLayerTree
@onready var layer_stone: TileMapLayer = $TileMapLayerStone

# --- Pattern d'arbre (forme fixe dans l'atlas) ---
## Offsets relatifs à la racine (0,0) et coordonnées atlas correspondantes.
## Forme : rectangle (5,0)-(6,4) + (4,3) et (7,3). Racine = (5,0) en atlas.
const TREE_PATTERN: Array = [
	{"offset": Vector2i(0, 0), "atlas_coords": Vector2i(5, 0)},
	{"offset": Vector2i(1, 0), "atlas_coords": Vector2i(6, 0)},
	{"offset": Vector2i(0, 1), "atlas_coords": Vector2i(5, 1)},
	{"offset": Vector2i(1, 1), "atlas_coords": Vector2i(6, 1)},
	{"offset": Vector2i(0, 2), "atlas_coords": Vector2i(5, 2)},
	{"offset": Vector2i(1, 2), "atlas_coords": Vector2i(6, 2)},
	{"offset": Vector2i(0, 3), "atlas_coords": Vector2i(5, 3)},
	{"offset": Vector2i(1, 3), "atlas_coords": Vector2i(6, 3)},
	{"offset": Vector2i(-1, 3), "atlas_coords": Vector2i(4, 3)},
	{"offset": Vector2i(2, 3), "atlas_coords": Vector2i(7, 3)},
	{"offset": Vector2i(0, 4), "atlas_coords": Vector2i(5, 4)},
	{"offset": Vector2i(1, 4), "atlas_coords": Vector2i(6, 4)},
]

# --- Arbres ---
@export_range(0.0, 1.0, 0.01) var density_tree: float = 0.12
@export var tree_placement_max_attempts: int = 2000

# --- Pierres (tuiles simples) ---
@export_range(0.0, 1.0, 0.01) var density_stone: float = 0.03

# --- Bornes de la map (cellules de tuiles) ---
## Si true, utilise map_bounds_min/max. Sinon, utilise le calque de référence (bounds_layer).
@export var use_custom_map_bounds: bool = true
## Coin min (inclusif) : cellule la plus en haut à gauche.
@export var map_bounds_min: Vector2i = Vector2i(-15, 1)
## Coin max (inclusif) : cellule la plus en bas à droite.
@export var map_bounds_max: Vector2i = Vector2i(58, 33)

# --- Global ---
@export var random_seed_value: int = 0
@export var generate_on_ready: bool = true


func _ready() -> void:
	if bounds_layer == null:
		push_warning("RandomTileGenerator: bounds_layer (TileMapLayer) introuvable.")
		return
	if layer_tree == null and layer_stone == null:
		push_warning("RandomTileGenerator: TileMapLayerTree et TileMapLayerStone introuvables.")
		return
	if generate_on_ready:
		call_deferred("generate")


## Point d'entrée pour régénérer la map (bouton ou appel script).
func generate() -> void:
	if bounds_layer == null:
		return
	if random_seed_value != 0:
		seed(random_seed_value)

	var rect: Rect2i
	if use_custom_map_bounds:
		# Rectangle inclusif : de map_bounds_min à map_bounds_max (les deux coins inclus)
		var w: int = map_bounds_max.x - map_bounds_min.x + 1
		var h: int = map_bounds_max.y - map_bounds_min.y + 1
		rect = Rect2i(map_bounds_min.x, map_bounds_min.y, w, h)
	else:
		rect = bounds_layer.get_used_rect()
		if not rect.has_area():
			rect = Rect2i(-50, -50, 100, 100)

	var cells: Array[Vector2i] = _rect_to_cells(rect)
	cells.shuffle()

	# 1) Placer les arbres en patterns multi-tuiles (sans chevauchement)
	var occupied_by_trees: Dictionary = {}
	if layer_tree != null and layer_tree.tile_set != null:
		_fill_trees_as_patterns(cells, occupied_by_trees)

	# 2) Pierres en tuiles simples (on évite les cellules déjà occupées par les arbres)
	var cells_for_stone: Array[Vector2i] = []
	for c in cells:
		if not occupied_by_trees.has(c):
			cells_for_stone.append(c)
	if layer_stone != null and layer_stone.tile_set != null:
		_fill_layer_single_tiles(layer_stone, cells_for_stone, density_stone)

	if layer_tree != null:
		layer_tree.update_internals()
	if layer_stone != null:
		layer_stone.update_internals()


# --- Arbres : pattern fixe (forme atlas 5,0 → 6,4 + 4,3 et 7,3) ---

func _fill_trees_as_patterns(cells: Array[Vector2i], occupied: Dictionary) -> void:
	layer_tree.clear()
	var tile_set: TileSet = layer_tree.tile_set
	var source_id: int = -1
	for i in range(tile_set.get_source_count()):
		var sid: int = tile_set.get_source_id(i)
		var src: TileSetSource = tile_set.get_source(sid)
		if src is TileSetAtlasSource:
			source_id = sid
			break
	if source_id < 0:
		push_warning("RandomTileGenerator: aucun TileSetAtlasSource pour les arbres.")
		return

	var target_fill: int = int(cells.size() * clamp(density_tree, 0.0, 1.0))
	var placed_cells: int = 0
	var attempts: int = 0

	while attempts < tree_placement_max_attempts and placed_cells < target_fill:
		attempts += 1
		var root: Vector2i = cells[randi() % cells.size()]

		# Toutes les cellules du pattern doivent être libres
		var can_place: bool = true
		for entry in TREE_PATTERN:
			var cell: Vector2i = root + entry.offset
			if occupied.has(cell):
				can_place = false
				break

		if not can_place:
			continue

		# Placer la forme complète de l'arbre (12 tuiles)
		for entry in TREE_PATTERN:
			var cell: Vector2i = root + entry.offset
			layer_tree.set_cell(cell, source_id, entry.atlas_coords, 0)
			occupied[cell] = true
			placed_cells += 1
		if placed_cells >= target_fill:
			break


# --- Pierres : tuiles simples (comportement inchangé) ---

func _fill_layer_single_tiles(
	layer: TileMapLayer,
	cells: Array[Vector2i],
	density: float
) -> void:
	var tile_set: TileSet = layer.tile_set
	var tiles: Array[Dictionary] = _collect_valid_tiles(tile_set)
	if tiles.is_empty():
		push_warning("RandomTileGenerator: aucun tuile valide dans le TileSet de %s" % layer.name)
		return

	layer.clear()
	var count := int(cells.size() * clamp(density, 0.0, 1.0))
	for i in min(count, cells.size()):
		var coords: Vector2i = cells[i]
		var t: Dictionary = tiles[randi() % tiles.size()]
		layer.set_cell(coords, t.source_id, t.atlas_coords, 0)


# --- Utilitaires ---

func _rect_to_cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


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

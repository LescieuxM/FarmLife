## Génère aléatoirement des arbres et des pierres sur la map au lancement.
## À attacher au Node2D racine de la scène de map (celui qui contient la TileMap).
## Utilise la TileMap pour les limites et respecte une distance minimale entre objets.

extends Node2D

## Scène à instancier pour chaque arbre.
@export var tree_scene: PackedScene
## Scène à instancier pour chaque pierre.
@export var rock_scene: PackedScene
## Nombre d'arbres à générer.
@export var tree_count: int = 30
## Nombre de pierres à générer.
@export var rock_count: int = 25
## Distance minimale entre deux objets (pixels) pour éviter les superpositions.
@export var min_distance: float = 32.0

## Référence à la TileMap (enfant direct de ce node).
@onready var tile_map: TileMap = $TileMap
## Nœud YSort : les instances sont ajoutées ici pour le tri par Y (ordre d’affichage type Zelda).
@onready var ysort_node: Node2D = $YSort


func _ready() -> void:
	_spawn_objects()


## Lance le spawn des arbres puis des pierres.
func _spawn_objects() -> void:
	var bounds := _get_map_bounds_world()
	var used_positions: Array[Vector2] = []

	_spawn_scenes(tree_scene, tree_count, bounds, used_positions)
	_spawn_scenes(rock_scene, rock_count, bounds, used_positions)


## Retourne le rectangle de la map en pixels (pour le tirage aléatoire).
func _get_map_bounds_world() -> Rect2:
	var used_rect: Rect2i = tile_map.get_used_rect()
	if used_rect.has_area():
		var top_left := tile_map.map_to_local(used_rect.position)
		var bottom_right := tile_map.map_to_local(used_rect.end)
		return Rect2(top_left, bottom_right - top_left)
	return Rect2(-400.0, -400.0, 800.0, 800.0)


## Instancie `count` scènes dans `bounds`, sans être plus proche que min_distance des `used_positions`.
func _spawn_scenes(
	scene: PackedScene,
	count: int,
	bounds: Rect2,
	used_positions: Array[Vector2]
) -> void:
	if scene == null:
		return

	var attempts_max := count * 50
	var spawned := 0
	var attempts := 0

	while spawned < count and attempts < attempts_max:
		attempts += 1
		var pos := Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y)
		)
		if _is_too_close_to_others(pos, used_positions):
			continue

		var instance := scene.instantiate()
		instance.position = pos
		ysort_node.add_child(instance)
		used_positions.append(pos)
		spawned += 1


## True si `pos` est à moins de min_distance d’un point de `used_positions`.
func _is_too_close_to_others(pos: Vector2, used_positions: Array[Vector2]) -> bool:
	for used in used_positions:
		if pos.distance_to(used) < min_distance:
			return true
	return false

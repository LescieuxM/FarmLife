extends Node
##
## Autoload singleton — inventory data, item database, drop tables,
## and world-item spawning.
##

signal inventory_changed

const SLOT_COUNT: int = 20
const MAX_STACK: int = 99

# ── Item database ───────────────────────────────────────────────────────
var ITEM_DB: Dictionary = {
	"wood": "res://assets/sprites/ui/item/wood.png",
	"stone": "res://assets/sprites/ui/item/stone.png",
}

# ── Drop tables ─────────────────────────────────────────────────────────
var DROP_TABLE: Dictionary = {
	"tree": "wood",
	"stump": "wood",
	"stone": "stone",
}

var DROP_COUNT: Dictionary = {
	"tree": 3,
	"stump": 1,
	"stone": 2,
}

# ── Number sprites (digits 0-9) ────────────────────────────────────────
var _number_textures: Dictionary = {}

# ── Inventory slots ─────────────────────────────────────────────────────
## Each slot is either {} (empty) or {"type": String, "count": int}.
var slots: Array[Dictionary] = []

# ── Preloaded item scene ────────────────────────────────────────────────
var _item_scene: PackedScene = null


func _ready() -> void:
	# Initialise empty slots
	slots.clear()
	for i in SLOT_COUNT:
		slots.append({})

	# Pre-load number textures 0-9
	for d in range(10):
		var path := "res://assets/sprites/ui/number/%d.png" % d
		if ResourceLoader.exists(path):
			_number_textures[d] = load(path)
		else:
			# fallback on 0
			if _number_textures.has(0):
				_number_textures[d] = _number_textures[0]

	# Pre-load item scene
	_item_scene = load("res://scenes/item.tscn")


# ── Public API ──────────────────────────────────────────────────────────

## Adds count items of the given type. Returns the overflow (items that
## could not fit).
func add_item(type: String, count: int = 1) -> int:
	var remaining := count

	# 1) Try to stack onto existing slots of the same type
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		if slots[i].has("type") and slots[i].type == type:
			var space: int = MAX_STACK - int(slots[i].count)
			if space > 0:
				var to_add: int = mini(remaining, space)
				slots[i].count += to_add
				remaining -= to_add

	# 2) Fill empty slots
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var to_add := mini(remaining, MAX_STACK)
			slots[i] = {"type": type, "count": to_add}
			remaining -= to_add

	inventory_changed.emit()
	return remaining


## Removes count items of the given type (from the end). Returns the
## number of items that could NOT be removed.
func remove_item(type: String, count: int = 1) -> int:
	var remaining := count
	# Iterate in reverse
	for i in range(SLOT_COUNT - 1, -1, -1):
		if remaining <= 0:
			break
		if slots[i].has("type") and slots[i].type == type:
			var to_remove := mini(remaining, slots[i].count)
			slots[i].count -= to_remove
			remaining -= to_remove
			if slots[i].count <= 0:
				slots[i] = {}

	inventory_changed.emit()
	return remaining


## Swaps two slots unconditionally.
func swap_slots(a: int, b: int) -> void:
	if a < 0 or a >= SLOT_COUNT or b < 0 or b >= SLOT_COUNT:
		return
	var tmp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	inventory_changed.emit()


## Merges slot `from` into slot `to` if they share the same type,
## otherwise swaps them.
func stack_slots(from: int, to: int) -> void:
	if from < 0 or from >= SLOT_COUNT or to < 0 or to >= SLOT_COUNT:
		return
	if from == to:
		return

	var sf: Dictionary = slots[from]
	var st: Dictionary = slots[to]

	# If source is empty, nothing to do
	if sf.is_empty():
		return

	# If target is empty, just move
	if st.is_empty():
		swap_slots(from, to)
		return

	# Same type → merge
	if sf.has("type") and st.has("type") and sf.type == st.type:
		var space: int = MAX_STACK - int(st.count)
		if space > 0:
			var to_move: int = mini(int(sf.count), space)
			st.count += to_move
			sf.count -= to_move
			if sf.count <= 0:
				slots[from] = {}
		inventory_changed.emit()
		return

	# Different types → swap
	swap_slots(from, to)


## Returns the Texture2D for a given item type, or null.
func get_item_texture(type: String) -> Texture2D:
	if ITEM_DB.has(type):
		return load(ITEM_DB[type])
	return null


## Returns the Texture2D for a single digit (0-9).
func get_number_texture(digit: int) -> Texture2D:
	var d := clampi(digit, 0, 9)
	if _number_textures.has(d):
		return _number_textures[d]
	return null


# ── World drops ─────────────────────────────────────────────────────────

## Spawns item drops in the world at world_pos based on the destroyed
## object type.
func spawn_drops(type: String, world_pos: Vector2) -> void:
	if not DROP_TABLE.has(type):
		return
	if _item_scene == null:
		push_warning("InventoryManager: item scene not loaded.")
		return

	var item_type: String = DROP_TABLE[type]
	var count: int = DROP_COUNT.get(type, 1)

	var root := get_tree().current_scene
	if root == null:
		return

	for i in count:
		var item: Node2D = _item_scene.instantiate()
		item.item_type = item_type
		item.position_offset = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		item.global_position = world_pos
		root.call_deferred("add_child", item)

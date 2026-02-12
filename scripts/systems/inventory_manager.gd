extends Node
##
## Autoload singleton — inventory data, item database, drop tables,
## and world-item spawning.
##

signal inventory_changed
signal hotbar_changed

const SLOT_COUNT: int = 20
const HOTBAR_SLOT_COUNT: int = 9
const MAX_STACK: int = 99

# Items that cannot be stacked (tools) — max 1 per slot.
const NON_STACKABLE: Array[String] = ["sword", "mine", "axe", "watering", "torch", "table"]

# Items that can be placed in the world.
const PLACEABLE: Array[String] = ["table"]

# ── Item database ───────────────────────────────────────────────────────
var ITEM_DB: Dictionary = {
	"wood": "res://assets/sprites/ui/item/wood.png",
	"stone": "res://assets/sprites/ui/item/stone.png",
	"sword": "res://assets/sprites/ui/itemHotBar/sword.png",
	"mine": "res://assets/sprites/ui/itemHotBar/pickaxe.png",
	"axe": "res://assets/sprites/ui/itemHotBar/axe.png",
	"watering": "res://assets/sprites/ui/itemHotBar/wateringcan.png",
	"torch": "res://assets/sprites/ui/itemHotBar/torch.png",
	"table": "res://assets/sprites/placable/table.png",
}

# ── Drop tables ─────────────────────────────────────────────────────────
var DROP_TABLE: Dictionary = {
	"tree": "wood",
	"stump": "wood",
	"stone": "stone",
	"table": "table",
}

var DROP_COUNT: Dictionary = {
	"tree": 3,
	"stump": 1,
	"stone": 2,
	"table": 1,
}

# ── Number sprites (digits 0-9) ────────────────────────────────────────
var _number_textures: Dictionary = {}

# ── Inventory slots ─────────────────────────────────────────────────────
## Each slot is either {} (empty) or {"type": String, "count": int}.
var slots: Array[Dictionary] = []

# ── Hotbar slots ───────────────────────────────────────────────────────
## Same format as inventory slots.
var hotbar_slots: Array[Dictionary] = []

# ── Preloaded item scene ────────────────────────────────────────────────
var _item_scene: PackedScene = null


func _ready() -> void:
	# Initialise empty inventory slots
	slots.clear()
	for i in SLOT_COUNT:
		slots.append({})

	# Initialise hotbar slots with default tools
	hotbar_slots = [
		{"type": "sword", "count": 1},
		{"type": "mine", "count": 1},
		{"type": "axe", "count": 1},
		{"type": "watering", "count": 1},
		{"type": "torch", "count": 1},
		{}, {}, {}, {},
	]

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
	var cap: int = get_max_stack(type)

	# 1) Try to stack onto existing slots of the same type
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		if slots[i].has("type") and slots[i].type == type:
			var space: int = cap - int(slots[i].count)
			if space > 0:
				var to_add: int = mini(remaining, space)
				slots[i].count += to_add
				remaining -= to_add

	# 2) Fill empty slots
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var to_add := mini(remaining, cap)
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

	# Same type → merge (only if stackable)
	if sf.has("type") and st.has("type") and sf.type == st.type:
		if is_stackable(sf.type):
			var space: int = get_max_stack(sf.type) - int(st.count)
			if space > 0:
				var to_move: int = mini(int(sf.count), space)
				st.count += to_move
				sf.count -= to_move
				if sf.count <= 0:
					slots[from] = {}
			inventory_changed.emit()
			return

	# Different types (or same non-stackable) → swap
	swap_slots(from, to)


## Returns true if the item type can be placed in the world.
func is_placeable(type: String) -> bool:
	return PLACEABLE.has(type)


## Returns true if the item type can be stacked (count > 1).
func is_stackable(type: String) -> bool:
	return not NON_STACKABLE.has(type)


## Returns the max stack size for a given item type.
func get_max_stack(type: String) -> int:
	return MAX_STACK if is_stackable(type) else 1


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


# ── Cross-container operations ─────────────────────────────────────────

## Returns the slot array for the given container.
func _get_container(is_hotbar: bool) -> Array[Dictionary]:
	return hotbar_slots if is_hotbar else slots


## Returns the slot count for the given container.
func _get_container_size(is_hotbar: bool) -> int:
	return HOTBAR_SLOT_COUNT if is_hotbar else SLOT_COUNT


## Moves / stacks an item from one container-slot to another.
## Works between inventory<->inventory, hotbar<->hotbar, and cross.
func stack_between(from_hotbar: bool, from_idx: int, to_hotbar: bool, to_idx: int) -> void:
	var src := _get_container(from_hotbar)
	var dst := _get_container(to_hotbar)
	if from_idx < 0 or from_idx >= _get_container_size(from_hotbar):
		return
	if to_idx < 0 or to_idx >= _get_container_size(to_hotbar):
		return
	if from_hotbar == to_hotbar and from_idx == to_idx:
		return

	var sf: Dictionary = src[from_idx]
	var st: Dictionary = dst[to_idx]

	if sf.is_empty():
		return

	# Target empty → move
	if st.is_empty():
		dst[to_idx] = sf.duplicate()
		src[from_idx] = {}
		_emit_changed(from_hotbar, to_hotbar)
		return

	# Same type → merge (only if stackable)
	if sf.has("type") and st.has("type") and sf.type == st.type:
		if is_stackable(sf.type):
			var space: int = get_max_stack(sf.type) - int(st.count)
			if space > 0:
				var to_move: int = mini(int(sf.count), space)
				st.count += to_move
				sf.count -= to_move
				if sf.count <= 0:
					src[from_idx] = {}
			_emit_changed(from_hotbar, to_hotbar)
			return

	# Different types (or same non-stackable) → swap
	src[from_idx] = st.duplicate()
	dst[to_idx] = sf.duplicate()
	_emit_changed(from_hotbar, to_hotbar)


## Clears a slot and returns its previous content.
func clear_slot(is_hotbar: bool, idx: int) -> Dictionary:
	var container := _get_container(is_hotbar)
	if idx < 0 or idx >= _get_container_size(is_hotbar):
		return {}
	var data: Dictionary = container[idx].duplicate()
	container[idx] = {}
	if is_hotbar:
		hotbar_changed.emit()
	else:
		inventory_changed.emit()
	return data


## Emits the right signal(s) after a cross-container operation.
func _emit_changed(a_hotbar: bool, b_hotbar: bool) -> void:
	if a_hotbar or b_hotbar:
		hotbar_changed.emit()
	if not a_hotbar or not b_hotbar:
		inventory_changed.emit()


## Spawns items at the player's feet.
func drop_item(type: String, count: int) -> void:
	if type.is_empty() or count <= 0:
		return
	if _item_scene == null:
		push_warning("InventoryManager: item scene not loaded.")
		return

	# Find the player
	var player: Node2D = null
	for node in get_tree().get_nodes_in_group("player"):
		player = node as Node2D
		break
	if player == null:
		# Fallback: search for Player class in the whole tree
		var all_nodes := get_tree().current_scene.find_children("*", "Player", true, false)
		if all_nodes.size() > 0:
			player = all_nodes[0] as Node2D
	if player == null:
		push_warning("InventoryManager: could not find player for drop.")
		return

	var root := get_tree().current_scene
	for i in count:
		var item: Node2D = _item_scene.instantiate()
		item.item_type = type
		item.dropped = true
		item.position_offset = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		item.global_position = player.global_position
		root.call_deferred("add_child", item)


# ── Craft recipes ────────────────────────────────────────────────────────

var CRAFT_RECIPES: Array[Dictionary] = [
	{"result": "table", "result_count": 1, "ingredients": {"wood": 5}},
]


## Returns true if the player has enough ingredients for recipe at idx.
func can_craft(recipe_idx: int) -> bool:
	if recipe_idx < 0 or recipe_idx >= CRAFT_RECIPES.size():
		return false
	var recipe: Dictionary = CRAFT_RECIPES[recipe_idx]
	var ingredients: Dictionary = recipe.ingredients
	for type in ingredients:
		var needed: int = ingredients[type]
		var have: int = 0
		for i in SLOT_COUNT:
			if slots[i].has("type") and slots[i].type == type:
				have += int(slots[i].count)
		if have < needed:
			return false
	return true


## Consumes ingredients and adds the result. Returns true if successful.
func craft(recipe_idx: int) -> bool:
	if not can_craft(recipe_idx):
		return false
	var recipe: Dictionary = CRAFT_RECIPES[recipe_idx]
	var ingredients: Dictionary = recipe.ingredients
	for type in ingredients:
		remove_item(type, ingredients[type])
	add_item(recipe.result, recipe.result_count)
	return true


## Removes one item of the given type from the hotbar. Returns true if found.
func remove_hotbar_item(type: String) -> bool:
	for i in HOTBAR_SLOT_COUNT:
		if hotbar_slots[i].has("type") and hotbar_slots[i].type == type:
			hotbar_slots[i] = {}
			hotbar_changed.emit()
			return true
	return false


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

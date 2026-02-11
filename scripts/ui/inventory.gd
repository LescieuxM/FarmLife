extends Control
##
## Inventory UI — reads from InventoryManager, displays item textures and
## quantity digits, supports drag & drop to reorganize / stack.
##

# ── Node references (set in _ready) ────────────────────────────────────
var _cases: Array[Control] = []       # 20 direct children of GridContainer
var _grid: GridContainer = null
var _btn_close: Button = null

# ── Drag state ──────────────────────────────────────────────────────────
var _dragging: bool = false
var _drag_from: int = -1
var _ghost: TextureRect = null


func _ready() -> void:
	visible = false
	_grid = $TextureRect/GridContainer
	_btn_close = $TextureRect/btn_close

	_gather_cases()

	if _btn_close:
		_btn_close.pressed.connect(func(): visible = false)

	InventoryManager.inventory_changed.connect(refresh)
	refresh()


## Collects the 20 inventory case nodes that are direct children of the
## GridContainer (excludes case19 which is nested under case14/ten).
func _gather_cases() -> void:
	_cases.clear()
	if _grid == null:
		return
	for child in _grid.get_children():
		if child is TextureRect:
			_cases.append(child)


## Refreshes every slot's display from InventoryManager data.
func refresh() -> void:
	for i in _cases.size():
		var case_node: Control = _cases[i]
		var item_rect: TextureRect = case_node.get_node_or_null("item")
		var one_rect: TextureRect = case_node.get_node_or_null("one")
		var ten_rect: TextureRect = case_node.get_node_or_null("ten")

		if i >= InventoryManager.SLOT_COUNT:
			# Extra cases beyond 20 — clear them
			if item_rect: item_rect.texture = null
			if one_rect: one_rect.texture = null
			if ten_rect: ten_rect.texture = null
			continue

		var slot: Dictionary = InventoryManager.slots[i]

		if slot.is_empty():
			if item_rect: item_rect.texture = null
			if one_rect: one_rect.texture = null
			if ten_rect: ten_rect.texture = null
		else:
			if item_rect:
				item_rect.texture = InventoryManager.get_item_texture(slot.type)
			# Units digit
			if one_rect:
				one_rect.texture = InventoryManager.get_number_texture(slot.count % 10)
			# Tens digit
			if ten_rect:
				if slot.count >= 10:
					ten_rect.texture = InventoryManager.get_number_texture(slot.count / 10)
				else:
					ten_rect.texture = null


# ── Input ───────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		visible = !visible
		if visible:
			refresh()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start_drag(event.global_position)
		else:
			if _dragging:
				_end_drag(event.global_position)

	if event is InputEventMouseMotion and _dragging and _ghost:
		_ghost.global_position = event.global_position - _ghost.size * 0.5


# ── Drag helpers ────────────────────────────────────────────────────────

func _try_start_drag(mouse_pos: Vector2) -> void:
	var idx := _case_index_at(mouse_pos)
	if idx < 0 or idx >= InventoryManager.SLOT_COUNT:
		return

	var slot: Dictionary = InventoryManager.slots[idx]
	if slot.is_empty():
		return

	_drag_from = idx
	_dragging = true

	# Create ghost
	_ghost = TextureRect.new()
	_ghost.texture = InventoryManager.get_item_texture(slot.type)
	_ghost.custom_minimum_size = Vector2(16, 16)
	_ghost.size = Vector2(16, 16)
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.modulate = Color(1, 1, 1, 0.7)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.global_position = mouse_pos - _ghost.size * 0.5
	add_child(_ghost)

	# Dim source slot
	var case_node := _cases[idx]
	var item_rect: TextureRect = case_node.get_node_or_null("item")
	if item_rect:
		item_rect.modulate = Color(1, 1, 1, 0.3)


func _end_drag(mouse_pos: Vector2) -> void:
	var to_idx := _case_index_at(mouse_pos)

	# Restore source slot visual
	if _drag_from >= 0 and _drag_from < _cases.size():
		var case_node := _cases[_drag_from]
		var item_rect: TextureRect = case_node.get_node_or_null("item")
		if item_rect:
			item_rect.modulate = Color(1, 1, 1, 1)

	# Perform inventory operation
	if to_idx >= 0 and to_idx < InventoryManager.SLOT_COUNT and to_idx != _drag_from:
		InventoryManager.stack_slots(_drag_from, to_idx)

	# Cleanup ghost
	if _ghost:
		_ghost.queue_free()
		_ghost = null

	_dragging = false
	_drag_from = -1
	refresh()


## Returns which inventory case index the given global position falls on,
## or -1 if none.
func _case_index_at(global_pos: Vector2) -> int:
	for i in _cases.size():
		var case_node: Control = _cases[i]
		var rect := Rect2(case_node.global_position, case_node.size * case_node.get_global_transform().get_scale())
		if rect.has_point(global_pos):
			return i
	return -1

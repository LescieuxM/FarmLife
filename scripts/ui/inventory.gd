extends Control
##
## Inventory UI — reads from InventoryManager, displays item textures and
## quantity digits, supports drag & drop to reorganize / stack.
## Also coordinates cross-container drag & drop with the hotbar.
##

# ── Node references (set in _ready) ────────────────────────────────────
var _cases: Array[Control] = []       # 20 direct children of GridContainer
var _grid: GridContainer = null
var _btn_close: Button = null
var _hotbar: Control = null           # sibling Hotbar node

# ── Drag state ──────────────────────────────────────────────────────────
var _dragging: bool = false
var _drag_from: int = -1
var _drag_from_hotbar: bool = false
var _ghost: TextureRect = null


func _ready() -> void:
	visible = false
	_grid = $TextureRect/GridContainer
	_btn_close = $TextureRect/btn_close

	_gather_cases()

	if _btn_close:
		_btn_close.pressed.connect(func(): _close())

	# Find sibling hotbar
	_hotbar = get_parent().get_node_or_null("Hotbar")

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
			# Only show quantity digits for stackable items
			if InventoryManager.is_stackable(slot.type):
				if one_rect:
					one_rect.texture = InventoryManager.get_number_texture(slot.count % 10)
				if ten_rect:
					if slot.count >= 10:
						ten_rect.texture = InventoryManager.get_number_texture(slot.count / 10)
					else:
						ten_rect.texture = null
			else:
				if one_rect: one_rect.texture = null
				if ten_rect: ten_rect.texture = null


# ── Open / Close ───────────────────────────────────────────────────────

func _open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _hotbar:
		_hotbar.set_interactive(true)
	refresh()


func _close() -> void:
	if _dragging:
		_cancel_drag()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _hotbar:
		_hotbar.set_interactive(false)


# ── Input ───────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if visible:
			_close()
		else:
			_open()
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
	# Check inventory slots first
	var idx := _case_index_at(mouse_pos)
	if idx >= 0 and idx < InventoryManager.SLOT_COUNT:
		var slot: Dictionary = InventoryManager.slots[idx]
		if not slot.is_empty():
			_start_drag(idx, false, slot, mouse_pos)
			return

	# Check hotbar buttons
	var hb_idx := _hotbar_button_index_at(mouse_pos)
	if hb_idx >= 0 and hb_idx < InventoryManager.HOTBAR_SLOT_COUNT:
		var slot: Dictionary = InventoryManager.hotbar_slots[hb_idx]
		if not slot.is_empty():
			_start_drag(hb_idx, true, slot, mouse_pos)
			return


func _start_drag(idx: int, from_hotbar: bool, slot: Dictionary, mouse_pos: Vector2) -> void:
	_drag_from = idx
	_drag_from_hotbar = from_hotbar
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

	# Dim source slot visual
	if from_hotbar:
		_dim_hotbar_slot(idx, 0.3)
	else:
		_dim_inventory_slot(idx, 0.3)


func _end_drag(mouse_pos: Vector2) -> void:
	# Restore source slot visual
	if _drag_from_hotbar:
		_dim_hotbar_slot(_drag_from, 1.0)
	else:
		_dim_inventory_slot(_drag_from, 1.0)

	# Determine drop target
	var inv_idx := _case_index_at(mouse_pos)
	var hb_idx := _hotbar_button_index_at(mouse_pos)

	if inv_idx >= 0 and inv_idx < InventoryManager.SLOT_COUNT:
		# Dropped on inventory slot
		InventoryManager.stack_between(_drag_from_hotbar, _drag_from, false, inv_idx)
	elif hb_idx >= 0 and hb_idx < InventoryManager.HOTBAR_SLOT_COUNT:
		# Dropped on hotbar slot
		InventoryManager.stack_between(_drag_from_hotbar, _drag_from, true, hb_idx)
	else:
		# Dropped outside both panels → drop item on the ground
		var data := InventoryManager.clear_slot(_drag_from_hotbar, _drag_from)
		if not data.is_empty():
			InventoryManager.drop_item(data.type, data.count)

	_cleanup_drag()
	refresh()


func _cancel_drag() -> void:
	# Restore source slot visual without performing any operation
	if _drag_from_hotbar:
		_dim_hotbar_slot(_drag_from, 1.0)
	else:
		_dim_inventory_slot(_drag_from, 1.0)
	_cleanup_drag()


func _cleanup_drag() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_dragging = false
	_drag_from = -1
	_drag_from_hotbar = false


## Dims/restores an inventory slot's item visual.
func _dim_inventory_slot(idx: int, alpha: float) -> void:
	if idx >= 0 and idx < _cases.size():
		var item_rect: TextureRect = _cases[idx].get_node_or_null("item")
		if item_rect:
			item_rect.modulate = Color(1, 1, 1, alpha)


## Dims/restores a hotbar slot's TextureRect visual.
func _dim_hotbar_slot(idx: int, alpha: float) -> void:
	if _hotbar == null:
		return
	var buttons: Array[Button] = _hotbar.get_buttons()
	if idx >= 0 and idx < buttons.size():
		var tex_rect: TextureRect = buttons[idx].get_node_or_null("TextureRect")
		if tex_rect:
			tex_rect.modulate = Color(1, 1, 1, alpha)


## Returns which inventory case index the given global position falls on,
## or -1 if none.
func _case_index_at(global_pos: Vector2) -> int:
	for i in _cases.size():
		var case_node: Control = _cases[i]
		var rect := Rect2(case_node.global_position, case_node.size * case_node.get_global_transform().get_scale())
		if rect.has_point(global_pos):
			return i
	return -1


## Returns which hotbar button index the given global position falls on,
## or -1 if none.
func _hotbar_button_index_at(global_pos: Vector2) -> int:
	if _hotbar == null:
		return -1
	var buttons: Array[Button] = _hotbar.get_buttons()
	for i in buttons.size():
		var btn: Button = buttons[i]
		var rect := Rect2(btn.global_position, btn.size * btn.get_global_transform().get_scale())
		if rect.has_point(global_pos):
			return i
	return -1

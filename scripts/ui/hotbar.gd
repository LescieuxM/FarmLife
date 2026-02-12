extends Control

signal tool_changed(tool_name: String)

var _buttons: Array[Button] = []
var _selected_index: int = -1

@onready var hbox: HBoxContainer = $HBoxContainer


func _ready() -> void:
	for child in hbox.get_children():
		if child is Button:
			_buttons.append(child)

	# Create "one" and "ten" digit nodes for each button
	for btn in _buttons:
		_create_digit_nodes(btn)

	# Connect pressed signals for mouse clicks
	for i in _buttons.size():
		var idx := i
		_buttons[i].pressed.connect(func(): _select_slot(idx))

	InventoryManager.hotbar_changed.connect(refresh)
	refresh()


## Creates "one" and "ten" TextureRect children inside a hotbar button
## for displaying stack quantity digits.
func _create_digit_nodes(btn: Button) -> void:
	# Position digits at bottom-right, scaled proportionally to 34x34 button
	var one := TextureRect.new()
	one.name = "one"
	one.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	one.mouse_filter = Control.MOUSE_FILTER_IGNORE
	one.position = Vector2(21.5, 20.1)
	one.size = Vector2(10.2, 9.2)
	btn.add_child(one)

	var ten := TextureRect.new()
	ten.name = "ten"
	ten.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ten.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ten.position = Vector2(17.3, 20.1)
	ten.size = Vector2(9.0, 9.0)
	btn.add_child(ten)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var idx := key - KEY_1
			if idx < _buttons.size():
				_select_slot(idx)
				get_viewport().set_input_as_handled()


func _select_slot(index: int) -> void:
	if index == _selected_index:
		# Deselect
		_buttons[index].button_pressed = false
		_selected_index = -1
		tool_changed.emit("")
		return
	# Deselect previous
	if _selected_index >= 0 and _selected_index < _buttons.size():
		_buttons[_selected_index].button_pressed = false
	# Select new
	_selected_index = index
	_buttons[index].button_pressed = true
	tool_changed.emit(get_selected_tool())


func get_selected_tool() -> String:
	if _selected_index < 0 or _selected_index >= InventoryManager.HOTBAR_SLOT_COUNT:
		return ""
	var slot: Dictionary = InventoryManager.hotbar_slots[_selected_index]
	if slot.is_empty():
		return ""
	return slot.get("type", "")


## Refreshes all hotbar button icons and quantity digits from InventoryManager.hotbar_slots.
func refresh() -> void:
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		var tex_rect: TextureRect = btn.get_node_or_null("TextureRect")
		var one_rect: TextureRect = btn.get_node_or_null("one")
		var ten_rect: TextureRect = btn.get_node_or_null("ten")

		if i >= InventoryManager.HOTBAR_SLOT_COUNT:
			if tex_rect: tex_rect.texture = null
			if one_rect: one_rect.texture = null
			if ten_rect: ten_rect.texture = null
			continue

		var slot: Dictionary = InventoryManager.hotbar_slots[i]

		if slot.is_empty():
			if tex_rect: tex_rect.texture = null
			if one_rect: one_rect.texture = null
			if ten_rect: ten_rect.texture = null
		else:
			if tex_rect:
				tex_rect.texture = InventoryManager.get_item_texture(slot.get("type", ""))
			# Only show quantity digits for stackable items
			var item_type: String = slot.get("type", "")
			if InventoryManager.is_stackable(item_type):
				var count: int = slot.get("count", 0)
				if one_rect:
					one_rect.texture = InventoryManager.get_number_texture(count % 10)
				if ten_rect:
					if count >= 10:
						ten_rect.texture = InventoryManager.get_number_texture(count / 10)
					else:
						ten_rect.texture = null
			else:
				if one_rect: one_rect.texture = null
				if ten_rect: ten_rect.texture = null


## Toggles mouse interactivity on the hotbar (for drag & drop while inventory is open).
func set_interactive(enabled: bool) -> void:
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_behavior_recursive = 0  # DEFAULT — children use their own mouse_filter
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_behavior_recursive = 1  # IGNORE — force all children to ignore mouse


## Returns the list of hotbar buttons for hit-testing by the inventory drag system.
func get_buttons() -> Array[Button]:
	return _buttons

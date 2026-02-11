extends Control

signal tool_changed(tool_name: String)

## Maps slot index (0-based) to tool name used by the hittable system.
const SLOT_TOOLS: Array[String] = [
	"sword",    # slot 1
	"mine",     # slot 2 – pickaxe
	"axe",      # slot 3
	"watering", # slot 4
	"torch",    # slot 5
	"",         # slot 6
	"",         # slot 7
	"",         # slot 8
	"",         # slot 9
]

var _buttons: Array[Button] = []
var _selected_index: int = -1

@onready var hbox: HBoxContainer = $HBoxContainer


func _ready() -> void:
	for child in hbox.get_children():
		if child is Button:
			_buttons.append(child)
	# Connect pressed signals for mouse clicks
	for i in _buttons.size():
		var idx := i
		_buttons[i].pressed.connect(func(): _select_slot(idx))


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
	if _selected_index < 0 or _selected_index >= SLOT_TOOLS.size():
		return ""
	return SLOT_TOOLS[_selected_index]

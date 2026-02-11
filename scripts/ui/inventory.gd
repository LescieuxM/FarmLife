extends Control


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		visible = !visible
		get_viewport().set_input_as_handled()

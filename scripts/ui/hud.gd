extends CanvasLayer

@onready var time_label: Label = $TimeLabel


func _ready() -> void:
	GameClock.time_changed.connect(_on_time_changed)
	_on_time_changed(GameClock.current_hour, GameClock.current_minute, GameClock.get_darkness())


func _on_time_changed(_hour: int, _minute: int, _darkness: float) -> void:
	time_label.text = GameClock.get_time_string()

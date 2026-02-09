extends CanvasModulate

@export var night_color: Color = Color(0.04, 0.04, 0.1)


func _ready() -> void:
	GameClock.time_changed.connect(_on_time_changed)
	_on_time_changed(GameClock.current_hour, GameClock.current_minute, GameClock.get_darkness())


func _on_time_changed(_hour: int, _minute: int, darkness: float) -> void:
	color = Color.WHITE.lerp(night_color, darkness)

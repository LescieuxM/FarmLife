extends Node

signal time_changed(hour: int, minute: int, darkness: float)

## Real seconds per in-game minute (1.0 → 24 real min = 1 game day)
@export var seconds_per_game_minute: float = 1.0

var current_hour: int = 3
var current_minute: int = 0
var _time_accumulator: float = 0.0


func _ready() -> void:
	_emit_time()


func _process(delta: float) -> void:
	_time_accumulator += delta
	if _time_accumulator >= seconds_per_game_minute:
		_time_accumulator -= seconds_per_game_minute
		_advance_minute()


func _advance_minute() -> void:
	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		if current_hour >= 24:
			current_hour = 0
	_emit_time()


func _emit_time() -> void:
	time_changed.emit(current_hour, current_minute, get_darkness())


func get_darkness() -> float:
	var t := current_hour + current_minute / 60.0
	if t >= 6.0 and t < 18.0:
		# Day
		return 0.0
	elif t >= 18.0 and t < 21.0:
		# Dusk: 0.0 → 1.0
		return lerpf(0.0, 1.0, (t - 18.0) / 3.0)
	elif t >= 21.0 or t < 5.0:
		# Night
		return 1.0
	else:
		# Dawn 05h-06h: 1.0 → 0.0
		return lerpf(1.0, 0.0, (t - 5.0) / 1.0)


func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

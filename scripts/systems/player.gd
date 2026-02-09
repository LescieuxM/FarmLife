class_name Player
extends CharacterBody2D

@export var speed: float = 200.0
@export var dash_speed: float = 230.0
@export var dash_duration: float = 0.8
@export var dash_cooldown: float = 2.0

var _last_direction := Vector2.DOWN
var _is_dashing := false
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	if camera:
		camera.make_current()


func _physics_process(delta: float) -> void:
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)

	if Input.is_action_just_pressed("ui_accept") and not _is_dashing and _dash_cooldown_timer <= 0.0:
		_start_dash()

	if _is_dashing:
		_dash_timer -= delta
		velocity = _last_direction * dash_speed
		move_and_slide()
		if _dash_timer <= 0.0:
			_is_dashing = false
			_dash_cooldown_timer = dash_cooldown
			_play_anim(_last_direction, false)
		return

	var direction := _get_input_direction()
	if direction != Vector2.ZERO:
		_last_direction = direction

	velocity = direction * speed
	move_and_slide()
	_play_anim(_last_direction, direction != Vector2.ZERO)


func _get_input_direction() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		d.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1
	return d.normalized()


func _start_dash() -> void:
	_is_dashing = true
	_dash_timer = dash_duration
	_play_roll_anim(_last_direction)


func _play_roll_anim(direction: Vector2) -> void:
	if not anim_player:
		return
	if direction.y > 0:
		anim_player.play("roll_down")
		if sprite:
			sprite.flip_h = false
	elif direction.y < 0:
		anim_player.play("roll_top")
		if sprite:
			sprite.flip_h = false
	else:
		anim_player.play("roll_side")
		if sprite:
			sprite.flip_h = direction.x < 0


func _play_anim(direction: Vector2, walking: bool) -> void:
	if not anim_player:
		return
	var prefix := "walk_" if walking else "idle_"
	if direction.y > 0:
		anim_player.play(prefix + "down")
		if sprite:
			sprite.flip_h = false
	elif direction.y < 0:
		anim_player.play(prefix + "top")
		if sprite:
			sprite.flip_h = false
	else:
		anim_player.play(prefix + "side")
		if sprite:
			sprite.flip_h = direction.x < 0

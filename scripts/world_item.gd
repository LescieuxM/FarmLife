extends Node2D
##
## World item — dropped loot that pops, bobs, gets attracted to the
## player, and is collected on contact.
##

## Set before adding to the scene tree.
var item_type: String = ""
var position_offset: Vector2 = Vector2.ZERO

# ── Tunables ────────────────────────────────────────────────────────────
const BOB_AMPLITUDE: float = 1.5
const BOB_SPEED: float = 3.0
const ATTRACT_SPEED: float = 120.0
const COLLECT_DISTANCE: float = 6.0
const LOSE_INTEREST_DISTANCE: float = 50.0

# ── State ───────────────────────────────────────────────────────────────
var _base_y: float = 0.0
var _bob_time: float = 0.0
var _target: Node2D = null   # player to fly towards
var _spawned: bool = false
var dropped: bool = false     # true = dropped by player, immune until they leave the zone

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea


func _ready() -> void:
	# Apply item texture
	var tex := InventoryManager.get_item_texture(item_type)
	if tex and sprite:
		sprite.texture = tex

	# Randomise bob phase so items don't bob in sync
	_bob_time = randf() * TAU

	# Connect area signals
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)
		pickup_area.body_exited.connect(_on_body_exited)

	# Play spawn pop tween
	_play_spawn_pop()


func _physics_process(delta: float) -> void:
	if not _spawned:
		return

	if _target != null and is_instance_valid(_target):
		var dist := global_position.distance_to(_target.global_position)

		# Player moved too far → stop following, go back to bobbing
		if dist > LOSE_INTEREST_DISTANCE:
			_target = null
			_base_y = position.y
		else:
			# Attract: fly towards the player
			var dir := (_target.global_position - global_position).normalized()
			global_position += dir * ATTRACT_SPEED * delta

			# Collect when close enough
			if dist < COLLECT_DISTANCE:
				InventoryManager.add_item(item_type)
				queue_free()
				return

	if _target == null or not is_instance_valid(_target):
		# Idle bob
		_bob_time += delta * BOB_SPEED
		position.y = _base_y + sin(_bob_time) * BOB_AMPLITUDE


# ── Spawn animation ────────────────────────────────────────────────────

func _play_spawn_pop() -> void:
	# Start slightly above and tween to final position with bounce
	var final_pos := global_position + position_offset
	var start_pos := Vector2(final_pos.x, final_pos.y - 8.0)

	global_position = start_pos
	_spawned = false

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", final_pos, 0.4)
	tween.tween_callback(_on_spawn_finished)


func _on_spawn_finished() -> void:
	_base_y = position.y
	_spawned = true


# ── Area2D callbacks ───────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		if dropped:
			return  # ignore — player hasn't left the zone yet
		_target = body


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and dropped:
		dropped = false

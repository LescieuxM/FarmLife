extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	HighLevelNetworkHandler.activate()

	if multiplayer.has_multiplayer_peer():
		# Remove the static Player (we spawn dynamically in multiplayer)
		var static_player = get_parent().get_node_or_null("Player")
		if static_player:
			static_player.queue_free()
		# Spawn the host player (peer_connected doesn't fire for self)
		if multiplayer.is_server():
			spawn_player(multiplayer.get_unique_id())


func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return

	var player: Node = network_player.instantiate()
	player.name = str(id)

	get_node(spawn_path).call_deferred("add_child", player)

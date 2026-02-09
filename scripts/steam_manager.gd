extends Node

## Emitted when the host lobby is ready (peer is set).
signal lobby_ready
## Emitted when a client has joined a lobby (peer is set).
signal joined_lobby

var _steam_available: bool = false
var _lobby_id: int = 0

func _ready() -> void:
	if not ClassDB.class_exists(&"Steam"):
		push_warning("SteamManager: GodotSteam not found – multiplayer disabled.")
		return

	var init: Dictionary = Steam.steamInitEx(false, 480)
	if init.status != Steam.STEAM_API_INIT_RESULT_OK:
		push_warning("SteamManager: Steam init failed – %s" % init.verbal)
		return

	_steam_available = true

	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)

	_check_command_line()


func _process(_delta: float) -> void:
	if _steam_available:
		Steam.run_callbacks()


func is_steam_available() -> bool:
	return _steam_available


## Host: create a friends-only lobby.
func create_lobby() -> void:
	if not _steam_available:
		push_error("SteamManager: cannot create lobby – Steam unavailable.")
		return
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 4)


## Client: join an existing lobby by ID.
func join_lobby(id: int) -> void:
	if not _steam_available:
		push_error("SteamManager: cannot join lobby – Steam unavailable.")
		return
	Steam.joinLobby(id)


# --- Callbacks ---

func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		push_error("SteamManager: lobby creation failed (result %d)." % result)
		return

	_lobby_id = lobby_id

	var peer := SteamMultiplayerPeer.new()
	peer.create_host(0)
	multiplayer.multiplayer_peer = peer

	lobby_ready.emit()

	# Open the Steam overlay so the host can invite friends.
	Steam.activateGameOverlayInviteDialog(lobby_id)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, result: int) -> void:
	if result != Steam.RESULT_OK:
		push_error("SteamManager: failed to join lobby (result %d)." % result)
		return

	_lobby_id = lobby_id

	var peer := SteamMultiplayerPeer.new()
	peer.create_client(Steam.getLobbyOwner(lobby_id), 0)
	multiplayer.multiplayer_peer = peer

	joined_lobby.emit()


func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	join_lobby(lobby_id)


## Handle launch via Steam invitation (+connect_lobby <id>).
func _check_command_line() -> void:
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "+connect_lobby" and i + 1 < args.size():
			var id := int(args[i + 1])
			if id > 0:
				call_deferred("join_lobby", id)
			return

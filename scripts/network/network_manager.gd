extends Node
class_name NetworkManager

# NetworkManager - handles online multiplayer for BARKADA SPIKE (Milestone 9).
#
# Architecture: Host-authoritative simulation.
#   - Host runs full physics, AI for all teammates, scoring, match state
#   - Clients send input (move, jump, spike, aim) to host via RPC
#   - Host syncs ball state, player positions, scores, phases to all clients
#
# Uses Godot 4.7 MultiplayerAPI with ENetMultiplayerPeer.
#
# IMPORTANT: ENet works on LAN / same Wi-Fi. For internet play, you need
# port forwarding (default port 7000) or a relay/NAT traversal service.
# See README.md for networking requirements.

# --- Network state -----------------------------------------------------------

enum NetworkState { DISCONNECTED, HOSTING, JOINING, CONNECTED }

var state: NetworkState = NetworkState.DISCONNECTED
var is_host: bool = false
var connection_status: String = "Disconnected"
var peer_count: int = 0

# Default port
@export var default_port: int = 7000

# --- Signals -----------------------------------------------------------------

signal state_changed(new_state: NetworkState)
signal connection_status_changed(status: String)
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_failed(reason: String)
signal game_started(is_host: bool)

# --- RPCs: Client -> Host (unreliable, for input) ---------------------------

@rpc("any_peer", "call_local", "unreliable")
func rpc_player_input(move_x: float, jump: bool, spike: bool, aim_x: float) -> void:
    # Host receives input from a client. multiplayer.get_remote_sender_id()
    # tells us which client sent it. The host applies it to that client's
    # main attacker (the Opponent for the client).
    if not is_host:
        return  # Only host processes input RPCs

    var sender_id: int = multiplayer.get_remote_sender_id()
    _on_remote_input_received(sender_id, move_x, jump, spike, aim_x)

# --- RPCs: Host -> All Clients ---------------------------------------------

@rpc("authority", "call_local", "unreliable")
func rpc_sync_ball_state(x: float, y: float, vx: float, vy: float, av: float, in_play: bool) -> void:
    # Host syncs ball state to clients. Clients set ball position/velocity.
    if is_host:
        return  # Host already has authoritative state

    var ball: BallController = _find_ball()
    if ball:
        ball.global_position = Vector2(x, y)
        ball.linear_velocity = Vector2(vx, vy)
        ball.angular_velocity = av
        ball.is_in_play = in_play

@rpc("authority", "call_local", "unreliable")
func rpc_sync_player_state(peer_id: int, x: float, y: float, flip_h: bool) -> void:
    # Host syncs the remote player's position to all clients.
    if is_host:
        return
    _apply_remote_player_state(peer_id, x, y, flip_h)

@rpc("authority", "call_local", "reliable")
func rpc_sync_score(team_a: int, team_b: int) -> void:
    # Host syncs scores.
    if is_host:
        return
    if GameManager:
        GameManager.score_team_a = team_a
        GameManager.score_team_b = team_b
    if HUD:
        HUD.set_score(team_a, team_b)

@rpc("authority", "call_local", "reliable")
func rpc_sync_phase(phase: int) -> void:
    # Host syncs match phase.
    if is_host:
        return
    if GameManager:
        GameManager.set_phase(phase)
    if HUD:
        HUD.set_phase(GameManager.get_phase_name())

@rpc("authority", "call_local", "reliable")
func rpc_match_ended(winner_team: int) -> void:
    # Host notifies clients of match end.
    if is_host:
        return
    if GameManager:
        GameManager.set_phase(GameManager.MatchPhase.MATCH_END)
    _show_match_result(winner_team)

# --- Host / Join -------------------------------------------------------------

func host_game(port: int = 7000) -> void:
    if state != NetworkState.DISCONNECTED:
        return

    var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
    var error: Error = peer.create_server(port, 2)  # max 2 players
    if error != Error.OK:
        connection_failed.emit("Failed to host on port %d: %s" % [port, error])
        connection_status = "Host failed"
        connection_status_changed.emit(connection_status)
        return

    multiplayer.peer = peer
    is_host = true
    state = NetworkState.HOSTING
    connection_status = "Hosting on port %d... waiting for player" % [port]
    peer_count = 1

    # Connect peer signals
    peer.peer_connected.connect(_on_peer_connected)
    peer.peer_disconnected.connect(_on_peer_disconnected)
    peer.connection_failed.connect(_on_connection_failed)

    state_changed.emit(state)
    connection_status_changed.emit(connection_status)
    push_notification("Hosting. Share your IP address with your friend.")

func join_game(address: String, port: int = 7000) -> void:
    if state != NetworkState.DISCONNECTED:
        return

    var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
    var error: Error = peer.create_client(address, port)
    if error != Error.OK:
        connection_failed.emit("Failed to join %s:%d: %s" % [address, port, error])
        connection_status = "Join failed"
        connection_status_changed.emit(connection_status)
        return

    multiplayer.peer = peer
    is_host = false
    state = NetworkState.JOINING
    connection_status = "Connecting to %s:%d..." % [address, port]

    # Connect peer signals
    peer.peer_connected.connect(_on_peer_connected)
    peer.peer_disconnected.connect(_on_peer_disconnected)
    peer.connection_failed.connect(_on_connection_failed)

    state_changed.emit(state)
    connection_status_changed.emit(connection_status)

func disconnect() -> void:
    if state == NetworkState.DISCONNECTED:
        return

    if multiplayer.peer:
        multiplayer.peer.close_connection()
        multiplayer.peer = null

    is_host = false
    state = NetworkState.DISCONNECTED
    connection_status = "Disconnected"
    peer_count = 0

    state_changed.emit(state)
    connection_status_changed.emit(connection_status)

    # Return to main menu
    get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")

# --- Internal: peer events ---------------------------------------------------

func _on_peer_connected(id: int) -> void:
    peer_count = multiplayer.connected_peers.size() + 1  # +1 for local peer
    connection_status = "Player connected (%d/%d)" % [peer_count, 2]
    connection_status_changed.emit(connection_status)
    peer_connected.emit(id)

    # If host and we have 2 players, start the game
    if is_host and peer_count >= 2:
        _start_networked_game()

func _on_peer_disconnected(id: int) -> void:
    peer_count = max(1, multiplayer.connected_peers.size())
    connection_status = "Peer %d disconnected" % [id]
    connection_status_changed.emit(connection_status)
    peer_disconnected.emit(id)

    # If opponent disconnects, return to menu
    if state != NetworkState.DISCONNECTED:
        push_notification("Opponent disconnected. Returning to menu.")
        disconnect()

func _on_connection_failed() -> void:
    connection_status = "Connection failed"
    connection_status_changed.emit(connection_status)
    connection_failed.emit("Network connection failed")
    disconnect()

# --- Internal: start networked game -----------------------------------------

func _start_networked_game() -> void:
    connection_status = "Connected! Starting match..."
    connection_status_changed.emit(connection_status)
    state = NetworkState.CONNECTED
    state_changed.emit(state)
    game_started.emit(is_host)

    # Load the gameplay scene for both peers
    get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

# --- Internal: find nodes ---------------------------------------------------

func _find_ball() -> BallController:
    # Search the tree for the ball
    var root: Node = get_tree().get_root()
    return _find_node_by_type(root, "BallController") as BallController

func _find_node_by_type(node: Node, type_name: String) -> Node:
    if node.get_class() == type_name or node.get_script() and node.get_script().get_class() == type_name:
        return node
    for child in node.get_children():
        var found: Node = _find_node_by_type(child, type_name)
        if found:
            return found
    return null

func _find_hud() -> GameplayHUD:
    var root: Node = get_tree().get_root()
    return _find_node_by_type(root, "GameplayHUD") as GameplayHUD

func _apply_remote_player_state(peer_id: int, x: float, y: float, flip_h: bool) -> void:
    # Applied on client to position the remote player (host's player)
    var player: Node2D = _find_remote_player()
    if player:
        player.global_position = Vector2(x, y)
        var visual: CanvasItem = player.get_node_or_null("Visual")
        if visual:
            visual.flip_h = flip_h

func _find_remote_player() -> Node2D:
    # On client, the remote player is the Opponent (right side)
    # On host, this is not used (host has local player)
    if is_host:
        return null

    # Find the Opponent character node
    var root: Node = get_tree().get_root()
    var opponent: Node2D = _find_node_by_name(root, "Opponent") as Node2D
    return opponent

func _find_node_by_name(node: Node, name: String) -> Node:
    if node.name == name:
        return node
    for child in node.get_children():
        var found: Node = _find_node_by_name(child, name)
        if found:
            return found
    return null

# --- Internal: host sends state sync ----------------------------------------

# Called by Main.gd on host each physics frame to sync ball + player state
func sync_from_host(ball_x: float, ball_y: float, ball_vx: float, ball_vy: float,
                    ball_av: float, ball_in_play: bool,
                    player_x: float, player_y: float, player_flip: bool,
                    score_a: int, score_b: int, phase: int) -> void:
    if not is_host:
        return

    rpc("rpc_sync_ball_state", ball_x, ball_y, ball_vx, ball_vy, ball_av, ball_in_play)
    rpc("rpc_sync_player_state", multiplayer.get_unique_id(), player_x, player_y, player_flip)
    rpc("rpc_sync_score", score_a, score_b)
    rpc("rpc_sync_phase", phase)

# Called by host to notify match end
func host_notify_match_end(winner_team: int) -> void:
    if not is_host:
        return
    rpc("rpc_match_ended", winner_team)

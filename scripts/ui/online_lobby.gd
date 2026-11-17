extends Control
class_name OnlineLobby

# OnlineLobby - host/join screen for online 1v1 matches.
#
# Uses NetworkManager (autoload) to create server (host) or connect to server (join).
# When both players connect, the game starts automatically.

@onready var btn_host: Button = $HostContainer/BtnHost
@onready var host_port: LineEdit = $HostContainer/HostPortInput
@onready var host_status: Label = $HostContainer/HostStatus
@onready var btn_join: Button = $JoinContainer/BtnJoin
@onready var join_address: LineEdit = $JoinContainer/JoinAddressInput
@onready var join_port: LineEdit = $JoinContainer/JoinPortInput
@onready var join_status: Label = $JoinContainer/JoinStatus
@onready var status_label: Label = $ConnectionStatus
@onready var btn_disconnect: Button = $BtnDisconnect
@onready var coins_label: Label = $CoinsLabel

func _ready() -> void:
    btn_host.pressed.connect(_on_host_pressed)
    btn_join.pressed.connect(_on_join_pressed)
    btn_disconnect.pressed.connect(_on_disconnect_pressed)

    # Listen to NetworkManager signals
    if NetworkManager:
        NetworkManager.state_changed.connect(_on_network_state_changed)
        NetworkManager.connection_status_changed.connect(_on_connection_status_changed)
        NetworkManager.connection_failed.connect(_on_connection_failed)
        NetworkManager.game_started.connect(_on_game_started)

    _update_coins()
    if ProgressionManager:
        ProgressionManager.coins_changed.connect(_update_coins)

    _refresh_ui()

func _update_coins(_amount: int = -1) -> void:
    if SaveManager:
        coins_label.text = "Coins: %d" % [SaveManager.get_coins()]

func _refresh_ui() -> void:
    if not NetworkManager:
        return

    var connected: bool = NetworkManager.state != NetworkManager.NetworkState.DISCONNECTED
    btn_host.disabled = connected
    btn_join.disabled = connected
    btn_disconnect.disabled = not connected

    if NetworkManager.is_host:
        status_label.text = "You are the HOST. Waiting for opponent..."
        status_label.custom_colors.font_color = Color(0.8, 0.9, 1, 1)
    elif NetworkManager.state == NetworkManager.NetworkState.CONNECTED:
        status_label.text = "Connected as CLIENT. Waiting for host to start..."
        status_label.custom_colors.font_color = Color(0.8, 0.9, 1, 1)
    else:
        status_label.text = NetworkManager.connection_status

func _on_host_pressed() -> void:
    if not NetworkManager:
        return
    var port_str: String = host_port.text.strip()
    var port: int = 7000
    if port_str != "":
        port = int(port_str)
    if port <= 0 or port > 65535:
        port = 7000
        host_port.text = "7000"

    host_status.text = "Hosting on port %d..." % [port]
    host_status.custom_colors.font_color = Color(0.8, 0.9, 1, 1)
    NetworkManager.host_game(port)

func _on_join_pressed() -> void:
    if not NetworkManager:
        return
    var addr: String = join_address.text.strip()
    var port_str: String = join_port.text.strip()
    var port: int = 7000
    if port_str != "":
        port = int(port_str)
    if port <= 0 or port > 65535:
        port = 7000
        join_port.text = "7000"

    if addr == "":
        addr = "127.0.0.1"
        join_address.text = "127.0.0.1"

    join_status.text = "Connecting to %s:%d..." % [addr, port]
    join_status.custom_colors.font_color = Color(0.8, 0.9, 1, 1)
    NetworkManager.join_game(addr, port)

func _on_disconnect_pressed() -> void:
    if NetworkManager:
        NetworkManager.disconnect()

func _on_network_state_changed(new_state: int) -> void:
    _refresh_ui()

func _on_connection_status_changed(status: String) -> void:
    status_label.text = status
    if NetworkManager and NetworkManager.is_host:
        host_status.text = status
    elif NetworkManager and not NetworkManager.is_host and NetworkManager.state != NetworkManager.NetworkState.DISCONNECTED:
        join_status.text = status

func _on_connection_failed(reason: String) -> void:
    status_label.text = "Failed: %s" % [reason]
    status_label.custom_colors.font_color = Color(1, 0.3, 0.3, 1)
    if NetworkManager and NetworkManager.is_host:
        host_status.text = "Host failed"
        host_status.custom_colors.font_color = Color(1, 0.3, 0.3, 1)
    elif NetworkManager:
        join_status.text = "Join failed"
        join_status.custom_colors.font_color = Color(1, 0.3, 0.3, 1)
    _refresh_ui()

func _on_game_started(is_host: bool) -> void:
    status_label.text = "Game starting..."
    # Both peers load Main.tscn via NetworkManager._start_networked_game()

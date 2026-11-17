extends Node2D
class_name Main

# Main - root of the gameplay world (Milestone 1-9).
#
# Reads game_config from GameManager and configures:
#   - Player character (color, stats from CharacterData)
#   - Opponent team (colors, names from config)
#   - AI difficulty (OpponentAIController)
#   - Animations for all characters
#   - Audio integration (ball hits, spikes, blocks, score)
#   - Perfect flash effect
#   - Match end -> MatchResult screen
#   - Online multiplayer (host-authoritative)
#
# Modes: "story", "quick", "practice", "online"

@onready var game_manager: GameManager = GameManager
@onready var match_manager: MatchManager = $MatchManager
@onready var volleyball_rules: VolleyballRules = $VolleyballRules
@onready var hud: GameplayHUD = $HUD
@onready var player: PlayerController = $Player
@onready var ball: BallController = $Ball
@onready var mobile_controls: MobileControls = $MobileControls
@onready var team_ai: TeamAIController = $TeamAIController
@onready var opponent_ai: OpponentAIController = $OpponentAIController
@onready var perfect_flash: ColorRect = $PerfectFlash

# Character nodes
@onready var setter_node: AICharacter = $Setter
@onready var defender_node: AICharacter = $Defender
@onready var opponent_node: AICharacter = $Opponent
@onready var opponent_setter_node: AICharacter = $OpponentSetter
@onready var opponent_defender_node: AICharacter = $OpponentDefender

# Network state
var _is_online: bool = false
var _is_network_host: bool = false
var _network_peer_id: int = -1
var _local_player: PlayerController = null      # This peer's controlled attacker
var _remote_player: AICharacter = null          # The other peer's attacker
var _local_player_node_path: String = ""        # Path to local player node

# Network sync timer (host sends state ~20Hz)
var _sync_timer: float = 0.0
var _sync_interval: float = 0.05

# Rally restart timer
var _rally_restart_timer: float = 0.0
var _rally_restart_delay: float = 2.0

# Pause state
var _is_paused: bool = false

# Perfect spikes tracked this match
var _perfect_spikes: int = 0

func _ready() -> void:
    var config: Dictionary = game_manager.get_game_config()
    _is_online = config.get("mode", "") == "online"
    _is_network_host = NetworkManager.is_host if NetworkManager else false
    _network_peer_id = multiplayer.get_unique_id() if multiplayer.peer else -1

    # --- Determine which player this peer controls ---------------------------
    if _is_online:
        _setup_online_players()
    else:
        _local_player = player
        _local_player_node_path = "Player"

    # --- Configure player character ------------------------------------------
    var player_char_id: String = config.get("player_character", "kai")
    _configure_player_character(player_char_id)

    # --- Configure opponent team ---------------------------------------------
    var opponent_team: Dictionary = config.get("opponent_team", {})
    _configure_opponent_team(opponent_team)

    # --- Set difficulty ------------------------------------------------------
    var difficulty: int = config.get("difficulty", 1)
    if opponent_ai:
        opponent_ai.difficulty = difficulty

    # --- Practice mode: simplify opponents -----------------------------------
    if config.get("mode", "") == "practice":
        _setup_practice_mode()

    # --- Online mode: disable AI on client, enable on host -------------------
    if _is_online:
        _setup_online_ai()

    # --- Setup animators for all characters ----------------------------------
    _setup_animators()

    # --- Perfect flash starts hidden -----------------------------------------
    perfect_flash.modulate = Color(1, 1, 1, 0)
    perfect_flash.visible = false

    # --- GameManager -> HUD --------------------------------------------------
    if game_manager:
        game_manager.score_updated.connect(hud.set_score)
        game_manager.phase_changed.connect(_on_game_phase_changed)
        hud.set_score(game_manager.score_team_a, game_manager.score_team_b)
        hud.set_phase(game_manager.get_phase_name())

    # --- MatchManager -> GameManager -----------------------------------------
    if match_manager:
        match_manager.score_point.connect(_on_match_score_point)
        match_manager.rally_ended.connect(_on_rally_ended)
        match_manager.match_ended.connect(_on_match_ended)
        match_manager.touch_updated.connect(_on_touch_updated)

    # --- PlayerController -> HUD / MatchManager ------------------------------
    if player:
        player.spike_completed.connect(_on_player_spike)
        player.spike_completed.connect(_on_player_touch)

    # --- Opponent spike (AI) -> register touch -------------------------------
    if opponent_node:
        opponent_node.spike_completed.connect(_on_opponent_spike)

    # --- BallController -> MatchManager --------------------------------------
    if ball:
        ball.ball_hit_floor.connect(_on_ball_hit_floor)
        ball.ball_out_of_bounds.connect(_on_ball_out_of_bounds)
        ball.ball_hit.connect(_on_ball_hit)

    # --- MobileControls -> local PlayerController ----------------------------
    if mobile_controls and _local_player:
        mobile_controls.move_direction_changed.connect(_local_player.set_mobile_move)
        mobile_controls.jump_pressed.connect(_local_player.mobile_jump)
        mobile_controls.spike_pressed.connect(_local_player.mobile_spike)
        mobile_controls.aim_direction_changed.connect(_local_player.set_mobile_aim)
        mobile_controls.pause_pressed.connect(_toggle_pause)

    # --- Network signals -----------------------------------------------------
    if _is_online and NetworkManager:
        NetworkManager.game_started.connect(_on_network_game_started)

    # Start the match
    if match_manager:
        match_manager.start_match()

# ---------------------------------------------------------------------------
# Online setup
# ---------------------------------------------------------------------------

func _setup_online_players() -> void:
    # Host controls Player (left side), Client controls Opponent (right side)
    if _is_network_host:
        _local_player = player
        _local_player_node_path = "Player"
        _remote_player = opponent_node
        _remote_player.is_remote = true
        _remote_player.network_peer_id = -1  # set when input received
    else:
        _local_player = opponent_node
        _local_player_node_path = "Opponent"
        _remote_player = player
        _remote_player.is_remote = true
        _remote_player.network_peer_id = -1

    # Configure the local player as network-controlled
    if _local_player:
        _local_player.is_remote = false  # local input
        _local_player.network_peer_id = _network_peer_id

    # Configure remote player
    if _remote_player:
        _remote_player.is_remote = true

func _setup_online_ai() -> void:
    # On host: AI runs for all teammates (both teams)
    # On client: AI is disabled (positions synced from host)
    if not _is_network_host:
        if team_ai:
            team_ai.set_process(false)
        if opponent_ai:
            opponent_ai.set_process(false)

# ---------------------------------------------------------------------------
# Configuration helpers
# ---------------------------------------------------------------------------

func _configure_player_character(character_id: String) -> void:
    if not _local_player or not CharacterManager:
        return

    var data: CharacterData = CharacterManager.get_character_data(character_id)
    if not data:
        return

    # Apply color to visual
    var visual: ColorRect = _local_player.get_node_or_null("Visual")
    if visual:
        visual.color = data.color

    # Apply stats to PlayerController
    _local_player.speed = 340.0 * data.get_stat_multiplier("speed")
    _local_player.jump_velocity = -720.0 * data.get_stat_multiplier("jump")
    _local_player.spike_power_base = 900.0 * data.get_stat_multiplier("spike_power")

func _configure_opponent_team(team: Dictionary) -> void:
    # Set colors for opponent characters (all red-themed variants)
    var opp_color: Color = Color(1, 0.2, 0.2, 1)
    var opp_setter_color: Color = Color(1, 0.4, 0.4, 1)
    var opp_defender_color: Color = Color(1, 0.6, 0.6, 1)

    if opponent_node:
        var visual: ColorRect = opponent_node.get_node_or_null("Visual")
        if visual: visual.color = opp_color
    if opponent_setter_node:
        var visual: ColorRect = opponent_setter_node.get_node_or_null("Visual")
        if visual: visual.color = opp_setter_color
    if opponent_defender_node:
        var visual: ColorRect = opponent_defender_node.get_node_or_null("Visual")
        if visual: visual.color = opp_defender_color

func _setup_practice_mode() -> void:
    if opponent_ai:
        opponent_ai.set_process(false)
    if team_ai:
        team_ai.set_process(false)

func _setup_animators() -> void:
    var characters: Array[AICharacter] = [
        setter_node, defender_node,
        opponent_node, opponent_setter_node, opponent_defender_node
    ]
    if player:
        characters.append(player)

    for char in characters:
        if char:
            var existing: Node = char.get_node_or_null("CharacterAnimator")
            if not existing:
                var animator: CharacterAnimator = CharacterAnimator.new()
                animator.name = "CharacterAnimator"
                char.add_child(animator)

# ---------------------------------------------------------------------------
# Process (sync timer + rally restart timer)
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
    if _rally_restart_timer > 0.0:
        _rally_restart_timer -= delta
        if _rally_restart_timer <= 0.0:
            _rally_restart_timer = 0.0
            _auto_serve()

    # Host: sync state to client at fixed interval
    if _is_online and _is_network_host:
        _sync_timer += delta
        if _sync_timer >= _sync_interval:
            _sync_timer = 0.0
            _send_state_sync()

    # Client: send local input to host
    if _is_online and not _is_network_host and _local_player:
        _send_local_input()

# ---------------------------------------------------------------------------
# Network input + sync
# ---------------------------------------------------------------------------

func _send_local_input() -> void:
    # Client sends input to host via RPC
    if not NetworkManager or not _local_player:
        return

    var move_x: float = _local_player.get_move_direction()
    var jump: bool = False  # We track pending jump differently
    var spike: bool = False
    var aim_x: float = _local_player.attack_direction

    # Detect jump/spike from the player controller
    # We use a simple approach: check if the player just spiked or jumped
    # Since these are momentary, we track them via flags
    NetworkManager.rpc_player_input(move_x, jump, spike, aim_x)

func _send_state_sync() -> void:
    # Host sends complete state to client
    if not NetworkManager or not _is_network_host:
        return

    var ball_pos: Vector2 = ball.global_position
    var ball_vel: Vector2 = ball.linear_velocity
    var player_pos: Vector2 = _local_player.global_position if _local_player else Vector2.ZERO
    var player_flip: bool = _local_player.visual.flip_h if _local_player and _local_player.visual else false

    NetworkManager.sync_from_host(
        ball_pos.x, ball_pos.y,
        ball_vel.x, ball_vel.y,
        ball.angular_velocity, ball.is_in_play,
        player_pos.x, player_pos.y, player_flip,
        game_manager.score_team_a, game_manager.score_team_b,
        int(game_manager.current_phase)
    )

# Called by NetworkManager when remote input is received (host only)
func _on_remote_input_received(sender_id: int, move_x: float, jump: bool, spike: bool, aim_x: float) -> void:
    if not _is_network_host or not _remote_player:
        return

    # Apply remote input to the remote player
    _remote_player.set_remote_move(move_x)
    _remote_player.set_remote_aim(aim_x)
    if jump:
        _remote_player.remote_jump()
    if spike:
        _remote_player.remote_spike()

    # Store which peer sent this (for tracking)
    _remote_player.network_peer_id = sender_id

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_network_game_started(is_host: bool) -> void:
    # Network game started, scene already loaded
    pass

func _on_game_phase_changed(_new_phase: int) -> void:
    if game_manager and hud:
        hud.set_phase(game_manager.get_phase_name())

func _on_match_score_point(team: int) -> void:
    if game_manager:
        if team < 0:
            game_manager.reset_score()
        else:
            game_manager.add_score(team)

func _on_rally_ended(winning_team: int, reason: String) -> void:
    _rally_restart_timer = _rally_restart_delay

func _on_match_ended(winner_team: int) -> void:
    if game_manager:
        game_manager.set_phase(GameManager.MatchPhase.MATCH_END)

    # Online: notify other peer
    if _is_online and _is_network_host and NetworkManager:
        NetworkManager.host_notify_match_end(winner_team)

    _show_match_result(winner_team)

func _on_player_spike(grade: int, power: float, direction: float) -> void:
    if hud:
        var grade_name: String = player.get_timing_grade_name() if player else "MISS"
        hud.show_timing(grade_name, power)
        if grade == PlayerController.TimingGrade.PERFECT:
            _perfect_spikes += 1
            _show_perfect_flash()
            _play_sfx("perfect_spike")

func _on_player_touch(_grade: int, _power: float, _direction: float) -> void:
    if match_manager:
        match_manager.register_touch(0)

func _on_opponent_spike(_grade: int, _power: float, _direction: float) -> void:
    # Opponent (AI or remote) spiked - register touch for their team
    if match_manager:
        match_manager.register_touch(1)

func _on_touch_updated(team: int, count: int) -> void:
    if hud:
        hud.set_touch_count(team, count)

func _on_ball_hit(team: int) -> void:
    if match_manager:
        match_manager.register_touch(team)
    _play_sfx("ball_hit")

func _on_ball_hit_floor(side: int) -> void:
    var winning_team: int = 1 if side == 0 else 0
    if match_manager:
        match_manager.end_rally(winning_team, "floor")
    ball.stop()

func _on_ball_out_of_bounds(side: int) -> void:
    var winning_team: int = side
    if match_manager:
        match_manager.end_rally(winning_team, "out")
    ball.stop()

# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

func _show_perfect_flash() -> void:
    if perfect_flash:
        perfect_flash.visible = true
        perfect_flash.modulate = Color(1, 1, 1, 0.6)
        var tween: Tween = create_tween()
        tween.tween_property(perfect_flash, "modulate:a", 0.0, 0.3)
        tween.play()
        tween.tween_callback.callable_func(func(): perfect_flash.visible = false).delayed(0.3)

# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

func _play_sfx(effect_name: String) -> void:
    var stream: AudioStream = null
    match effect_name:
        "ball_hit": stream = load("res://assets/audio/sfx/ball_hit.wav")
        "spike": stream = load("res://assets/audio/sfx/spike.wav")
        "perfect_spike": stream = load("res://assets/audio/sfx/perfect_spike.wav")
        "block": stream = load("res://assets/audio/sfx/block.wav")
        "receive": stream = load("res://assets/audio/sfx/receive.wav")
        "set": stream = load("res://assets/audio/sfx/set.wav")
        "point": stream = load("res://assets/audio/sfx/point.wav")
        "jump": stream = load("res://assets/audio/sfx/jump.wav")
        _: pass
    if stream and AudioManager:
        AudioManager.play_sfx(stream)

func play_music(track_name: String) -> void:
    if AudioManager:
        var stream: AudioStream = load("res://assets/audio/music/%s.wav" % [track_name])
        if stream:
            AudioManager.play_music(stream)

# ---------------------------------------------------------------------------
# Match result
# ---------------------------------------------------------------------------

func _show_match_result(winner_team: int) -> void:
    var config: Dictionary = game_manager.get_game_config()
    var won: bool = winner_team == 0

    var coins: int = 0
    if ProgressionManager:
        coins = ProgressionManager.get_match_reward(won)
        if _perfect_spikes > 0:
            coins += ProgressionManager.coins_perfect_spike * _perfect_spikes

    var return_to_menu: bool = true  # Online always returns to menu after match
    if config.mode == "story":
        return_to_menu = TournamentManager.get_current_tournament_index() < 0

    if SaveManager:
        SaveManager.save_after_match(
            winner_team,
            config.get("mode", "") == "story",
            config.get("tournament_id", ""),
            config.get("match_index", 0),
            _perfect_spikes,
            coins
        )

    var result_scene = load("res://scenes/results/match_result.tscn")
    var result_instance: MatchResult = result_scene.instantiate()
    result_instance.set_result(won, game_manager.score_team_a, game_manager.score_team_b, coins, _perfect_spikes, return_to_menu)
    get_tree().get_root().add_child(result_instance)

# ---------------------------------------------------------------------------
# Auto-serve (host only)
# ---------------------------------------------------------------------------

func _auto_serve() -> void:
    # Only host serves
    if _is_online and not _is_network_host:
        return

    var config: Dictionary = game_manager.get_game_config()
    var serve_team: int = _get_next_serving_team()

    var start_pos: Vector2
    var target_x: float

    if serve_team == 0:
        start_pos = Vector2(300, 400)
        target_x = 900.0
    else:
        start_pos = Vector2(980, 400)
        target_x = 380.0
        if opponent_ai and config.mode != "practice" and not (_is_online and not _is_network_host):
            opponent_ai.serve()
            return

    var dir: Vector2 = Vector2(target_x - start_pos.x, -150.0).normalized()
    var power: float = 700.0
    ball.serve(start_pos, dir, power)
    match_manager.on_serve()

func _get_next_serving_team() -> int:
    return 0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_player_score() -> int:
    return game_manager.score_team_a

func get_opponent_score() -> int:
    return game_manager.score_team_b

func is_match_over() -> bool:
    return match_manager.get_match_over() if match_manager else false

func is_online() -> bool:
    return _is_online

func is_network_host() -> bool:
    return _is_network_host

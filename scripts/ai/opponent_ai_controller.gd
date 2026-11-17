extends Node
class_name OpponentAIController

# OpponentAIController - controls the opposing team (AI).
#
# Controls opponent setter, defender, and main attacker on the right side.
# Implements ball tracking, prediction, receiving, setting, attacking, blocking.
# Difficulty settings affect reaction time and accuracy.

enum Difficulty { EASY, MEDIUM, HARD }

# --- Node references (siblings under Main) -----------------------------------

@onready var opponent_setter: AICharacter = get_node("../OpponentSetter")
@onready var opponent_defender: AICharacter = get_node("../OpponentDefender")
@onready var opponent_attacker: AICharacter = get_node("../Opponent")
@onready var ball: BallController = get_node("../Ball")

# --- Tuning ------------------------------------------------------------------

@export var difficulty: Difficulty = Difficulty.MEDIUM
@export var net_x: float = 640.0
@export var floor_y: float = 590.0
@export var gravity: float = 1100.0

# Opponent home positions (right side of court)
@export var opponent_setter_home_x: float = 730.0
@export var opponent_defender_home_x: float = 880.0
@export var opponent_attacker_home_x: float = 810.0

# Attack target on player's side
@export var attack_target_x: float = 340.0  # player attacker position

# Difficulty settings
@export var reaction_delay_easy: float = 0.6
@export var reaction_delay_medium: float = 0.35
@export var reaction_delay_hard: float = 0.15
@export var accuracy_easy: float = 0.6
@export var accuracy_medium: float = 0.85
@export var accuracy_hard: float = 0.98

# --- Internal state ----------------------------------------------------------

var _reaction_timer: float = 0.0
var _last_ball_side: int = -1  # 0 = player side (left), 1 = opponent side (right)

func _ready() -> void:
    opponent_setter.set_default_position(Vector2(opponent_setter_home_x, 404))
    opponent_defender.set_default_position(Vector2(opponent_defender_home_x, 404))
    opponent_attacker.set_default_position(Vector2(opponent_attacker_home_x, 404))

    opponent_setter.set_ball(ball)
    opponent_defender.set_ball(ball)
    opponent_attacker.set_ball(ball)

# ---------------------------------------------------------------------------
# Difficulty helpers
# ---------------------------------------------------------------------------

func _get_reaction_delay() -> float:
    match difficulty:
        Difficulty.EASY: return reaction_delay_easy
        Difficulty.MEDIUM: return reaction_delay_medium
        Difficulty.HARD: return reaction_delay_hard

func _get_accuracy() -> float:
    match difficulty:
        Difficulty.EASY: return accuracy_easy
        Difficulty.MEDIUM: return accuracy_medium
        Difficulty.HARD: return accuracy_hard

# ---------------------------------------------------------------------------
# Process (AI decision loop)
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
    if ball == null or not ball.is_in_play:
        # Ball not in play: return to home positions
        opponent_setter.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_setter_home_x, 404))
        opponent_defender.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_defender_home_x, 404))
        opponent_attacker.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_attacker_home_x, 404))
        return

    if _reaction_timer > 0.0:
        _reaction_timer -= delta
        return

    var ball_pos: Vector2 = ball.global_position
    var ball_vel: Vector2 = ball.linear_velocity
    var ball_on_opponent_side: bool = ball_pos.x > net_x

    # Track side change for block detection
    var current_side: int = 0 if ball_pos.x < net_x else 1
    if _last_ball_side != -1 and _last_ball_side != current_side:
        _on_ball_crossed_net(current_side, ball_vel)
    _last_ball_side = current_side

    if ball_on_opponent_side:
        # Ball on opponent's side: play it (receive / set / attack)
        _update_opponent_setter(ball_pos, ball_vel)
        _update_opponent_defender(ball_pos, ball_vel)
        _update_opponent_attacker(ball_pos, ball_vel)
    else:
        # Ball on player's side: prepare to defend / block
        if ball_vel.y > 0:  # ball coming down, may cross to our side
            # Attempt block at the net
            opponent_setter.set_state(AICharacter.AIState.BLOCK, Vector2(opponent_setter_home_x, 404))
        opponent_defender.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_defender_home_x, 404))
        opponent_attacker.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_attacker_home_x, 404))

# ---------------------------------------------------------------------------
# Opponent setter AI
# ---------------------------------------------------------------------------

func _update_opponent_setter(ball_pos: Vector2, ball_vel: Vector2) -> void:
    var dist_to_ball: float = abs(ball_pos.x - opponent_setter.global_position.x)

    if dist_to_ball < 120.0 and opponent_setter.is_ball_in_range():
        # Close enough to receive / set
        opponent_setter.set_state(AICharacter.AIState.RECEIVE, ball_pos)
        _opponent_setter_set_ball()
    elif dist_to_ball < 200.0:
        opponent_setter.set_state(AICharacter.AIState.MOVE_TO_BALL, ball_pos)
    else:
        # Stay near net ready to set or block
        opponent_setter.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_setter_home_x, 404))

func _opponent_setter_set_ball() -> void:
    if ball == null:
        return
    # Set the ball toward the opponent attacker
    var dir_x: float = _sign(opponent_attacker_home_x - opponent_setter.global_position.x)
    # Add some inaccuracy based on difficulty
    var accuracy: float = _get_accuracy()
    var target_x: float = opponent_attacker_home_x + randf_range(-50.0, 50.0) * (1.0 - accuracy)
    dir_x = _sign(target_x - opponent_setter.global_position.x)
    var set_velocity: Vector2 = Vector2(dir_x * 450.0, -650.0)
    ball.set_velocity(set_velocity, 1)  # team 1 = opponent

# ---------------------------------------------------------------------------
# Opponent defender AI
# ---------------------------------------------------------------------------

func _update_opponent_defender(ball_pos: Vector2, ball_vel: Vector2) -> void:
    var dist_to_ball: float = abs(ball_pos.x - opponent_defender.global_position.x)

    if dist_to_ball < 150.0 and opponent_defender.is_ball_in_range():
        opponent_defender.set_state(AICharacter.AIState.RECEIVE, ball_pos)
        _opponent_defender_receive_ball()
    elif dist_to_ball < 250.0:
        opponent_defender.set_state(AICharacter.AIState.MOVE_TO_BALL, ball_pos)
    else:
        opponent_defender.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_defender_home_x, 404))

func _opponent_defender_receive_ball() -> void:
    if ball == null:
        return
    # Bump the ball up toward the setter
    var dir_x: float = _sign(opponent_setter_home_x - opponent_defender.global_position.x)
    var accuracy: float = _get_accuracy()
    var target_x: float = opponent_setter_home_x + randf_range(-40.0, 40.0) * (1.0 - accuracy)
    dir_x = _sign(target_x - opponent_defender.global_position.x)
    var receive_velocity: Vector2 = Vector2(dir_x * 380.0, -580.0)
    ball.set_velocity(receive_velocity, 1)  # team 1 = opponent

# ---------------------------------------------------------------------------
# Opponent attacker AI (main attacker)
# ---------------------------------------------------------------------------

func _update_opponent_attacker(ball_pos: Vector2, ball_vel: Vector2) -> void:
    var dist_to_ball: float = abs(ball_pos.x - opponent_attacker.global_position.x)

    # If the ball is set to the attacker (coming from setter), spike it
    if dist_to_ball < 100.0 and opponent_attacker.is_ball_in_range() and ball_vel.y < 0:
        # Ball is above attacker (set coming down) - spike!
        opponent_attacker.set_state(AICharacter.AIState.MOVE_TO_BALL, ball_pos)
        _opponent_spike()
    elif dist_to_ball < 180.0:
        opponent_attacker.set_state(AICharacter.AIState.MOVE_TO_BALL, ball_pos)
    else:
        opponent_attacker.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(opponent_attacker_home_x, 404))

func _opponent_spike() -> void:
    if ball == null:
        return
    # Spike the ball toward the player's side
    var dir_x: float = _sign(attack_target_x - opponent_attacker.global_position.x)
    var accuracy: float = _get_accuracy()
    # Vary power and direction based on difficulty
    var power: float = 850.0 + randf_range(-100.0, 100.0) * (1.0 - accuracy)
    var spike_velocity: Vector2 = Vector2(dir_x * power * 0.5, -power * 0.8)
    ball.set_velocity(spike_velocity, 1)  # team 1 = opponent

# ---------------------------------------------------------------------------
# Ball crossed net detection (for blocking)
# ---------------------------------------------------------------------------

func _on_ball_crossed_net(new_side: int, ball_vel: Vector2) -> void:
    # If ball just crossed to opponent's side with downward velocity, block it
    if new_side == 1 and ball_vel.y > 0:
        opponent_setter.set_state(AICharacter.AIState.BLOCK, Vector2(opponent_setter_home_x, 404))

# ---------------------------------------------------------------------------
# Serve
# ---------------------------------------------------------------------------

# Opponent serves the ball to the player's side.
func serve() -> void:
    if ball == null:
        return
    var start_pos: Vector2 = Vector2(opponent_attacker_home_x, 400)
    var target_x: float = 400.0  # somewhere on player's side
    var dir: Vector2 = Vector2(target_x - start_pos.x, -150.0).normalized()
    var power: float = 650.0 + randf_range(-50.0, 50.0) * (1.0 - _get_accuracy())
    ball.serve(start_pos, dir, power)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _sign(v: float) -> float:
    if v > 0: return 1.0
    if v < 0: return -1.0
    return 0.0

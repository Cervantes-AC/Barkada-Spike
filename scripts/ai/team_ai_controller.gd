extends Node
class_name TeamAIController

# TeamAIController - manages AI teammates (setter + defender) for the player's team.
#
# Each frame, reads the ball state and assigns states/targets to setter and defender.
# Implements:
#   - Ball tracking and landing prediction
#   - Setter: moves to setting position, receives, sets toward attacker
#   - Defender: moves to defensive position, receives, covers back court
#   - Automatic blocking: jumps at net when opponent spikes

# --- Node references (siblings under Main) -----------------------------------

@onready var setter: AICharacter = get_node("../Setter")
@onready var defender: AICharacter = get_node("../Defender")
@onready var ball: BallController = get_node("../Ball")

# --- Tuning ------------------------------------------------------------------

@export var net_x: float = 640.0           # x position of net center
@export var floor_y: float = 590.0         # y position of floor
@export var gravity: float = 1100.0        # must match BallController.gravity
@export var setter_home_x: float = 550.0   # setter's home position (near net)
@export var defender_home_x: float = 400.0 # defender's home position (back court)
@export var attack_zone_x: float = 340.0   # player attacker position

# --- Internal state ----------------------------------------------------------

var _last_ball_side: int = -1  # 0 = player side, 1 = opponent side

func _ready() -> void:
    # Set default positions
    setter.set_default_position(Vector2(setter_home_x, 404))
    defender.set_default_position(Vector2(defender_home_x, 404))

    # Give AI characters a reference to the ball
    setter.set_ball(ball)
    defender.set_ball(ball)

# ---------------------------------------------------------------------------
# Process (AI decision loop)
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
    if ball == null or not ball.is_in_play:
        # Ball not in play: return to positions
        setter.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(setter_home_x, 404))
        defender.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(defender_home_x, 404))
        return

    var ball_pos: Vector2 = ball.global_position
    var ball_vel: Vector2 = ball.linear_velocity
    var ball_on_player_side: bool = ball_pos.x < net_x

    # Detect side change (ball crossed net)
    var current_side: int = 0 if ball_on_player_side else 1
    if _last_ball_side != -1 and _last_ball_side != current_side:
        _on_ball_crossed_net(current_side, ball_vel)
    _last_ball_side = current_side

    # --- Setter logic -------------------------------------------------------
    _update_setter(ball_pos, ball_vel, ball_on_player_side)

    # --- Defender logic -----------------------------------------------------
    _update_defender(ball_pos, ball_vel, ball_on_player_side)

# ---------------------------------------------------------------------------
# Setter AI
# ---------------------------------------------------------------------------

func _update_setter(ball_pos: Vector2, ball_vel: Vector2, ball_on_player_side: bool) -> void:
    var dist_to_ball: float = abs(ball_pos.x - setter.global_position.x)

    if ball_on_player_side:
        # Ball is on our side. Setter moves to ball if nearby, else stays near net ready.
        if dist_to_ball < 120.0 and setter.is_ball_in_range():
            # Close enough to receive
            setter.set_state(AICharacter.AIState.RECEIVE, ball_pos)
            _setter_receive_ball()
        elif dist_to_ball < 200.0:
            # Move toward ball to receive
            setter.set_state(AICharacter.AIState.MOVE_TO_BALL, ball_pos)
        else:
            # Stay near net, ready to set
            setter.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(setter_home_x, 404))
    else:
        # Ball on opponent side: setter returns to home (near net) ready to block/set
        setter.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(setter_home_x, 404))

# Handle setter receiving the ball (set it toward attacker)
func _setter_receive_ball() -> void:
    if ball == null:
        return
    # Set the ball upward and toward the player attacker
    var dir_x: float = _sign(attack_zone_x - setter.global_position.x)
    var set_velocity: Vector2 = Vector2(dir_x * 500.0, -700.0)
    ball.set_velocity(set_velocity, 0)  # team 0 = player's team

# ---------------------------------------------------------------------------
# Defender AI
# ---------------------------------------------------------------------------

func _update_defender(ball_pos: Vector2, ball_vel: Vector2, ball_on_player_side: bool) -> void:
    var dist_to_ball: float = abs(ball_pos.x - defender.global_position.x)

    if ball_on_player_side:
        # Ball on our side: defender moves to receive if ball is in back court area
        if dist_to_ball < 150.0 and defender.is_ball_in_range():
            defender.set_state(AICharacter.AIState.RECEIVE, ball_pos)
            _defender_receive_ball()
        elif dist_to_ball < 250.0:
            defender.set_state(AICharacter.AIState.MOVE_TO_BALL, ball_pos)
        else:
            # Cover back court
            defender.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(defender_home_x, 404))
    else:
        # Ball on opponent side: defender stays in back court ready
        defender.set_state(AICharacter.AIState.MOVE_TO_POSITION, Vector2(defender_home_x, 404))

# Handle defender receiving the ball (bump it up toward setter)
func _defender_receive_ball() -> void:
    if ball == null:
        return
    var dir_x: float = _sign(setter_home_x - defender.global_position.x)
    var receive_velocity: Vector2 = Vector2(dir_x * 400.0, -600.0)
    ball.set_velocity(receive_velocity, 0)  # team 0 = player's team

# ---------------------------------------------------------------------------
# Ball crossed net detection
# ---------------------------------------------------------------------------

func _on_ball_crossed_net(new_side: int, ball_vel: Vector2) -> void:
    # If ball just crossed to player's side with downward velocity, it's an attack
    # -> attempt automatic block at the net
    if new_side == 0 and ball_vel.y > 0:
        setter.set_state(AICharacter.AIState.BLOCK, Vector2(setter_home_x, 404))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _sign(v: float) -> float:
    if v > 0: return 1.0
    if v < 0: return -1.0
    return 0.0

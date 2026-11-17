extends CharacterBody2D
class_name AICharacter

# AICharacter - base class for AI-controlled volleyball characters (setter, defender).
#
# State machine:
#   IDLE           - waiting
#   MOVE_TO_POSITION - moving to default court position
#   MOVE_TO_BALL   - moving toward the ball to receive
#   RECEIVE        - contacting the ball (bump/receive)
#   SET            - setter only: setting the ball toward attacker
#   RECOVER        - returning to default position after action
#   BLOCK          - jumping at the net to block
#
# TeamAIController / OpponentAIController sets the state and target_position each frame.

enum AIState { IDLE, MOVE_TO_POSITION, MOVE_TO_BALL, RECEIVE, SET, RECOVER, BLOCK }

# --- Tuning ------------------------------------------------------------------

@export var speed: float = 300.0
@export var jump_velocity: float = -650.0
@export var gravity: float = 1900.0
@export var receive_range: float = 45.0     # pixels: close enough to touch ball
@export var is_setter: bool = false          # true = setter, false = defender

# --- State -------------------------------------------------------------------

var state: AIState = AIState.IDLE
var target_position: Vector2 = Vector2.ZERO
var default_position: Vector2 = Vector2.ZERO
var ball: BallController = null
var facing_right: bool = true

var velocity: Vector2 = Vector2.ZERO
var is_on_ground: bool = false
var was_on_floor: bool = false

# Timing
var _action_timer: float = 0.0
var _action_duration: float = 0.4  # seconds for receive/set/block animation

# Animator
var animator: CharacterAnimator = null

# --- Node references ---------------------------------------------------------

@onready var visual: CanvasItem = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------

func _ready() -> void:
    default_position = global_position
    target_position = default_position
    if visual:
        facing_right = not visual.flip_h

    # Create animator if not present as child node
    var existing_animator: Node = get_node_or_null("CharacterAnimator")
    if existing_animator:
        animator = existing_animator as CharacterAnimator
    else:
        animator = CharacterAnimator.new()
        animator.name = "CharacterAnimator"
        add_child(animator)

# ---------------------------------------------------------------------------
# Public API (called by TeamAIController / OpponentAIController)
# ---------------------------------------------------------------------------

func set_state(new_state: AIState, new_target: Vector2 = Vector2.ZERO) -> void:
    if state == new_state and new_target == Vector2.ZERO:
        return
    state = new_state
    if new_target != Vector2.ZERO:
        target_position = new_target
    _enter_state(state)

func set_ball(new_ball: BallController) -> void:
    ball = new_ball

func set_default_position(pos: Vector2) -> void:
    default_position = pos
    target_position = pos

# ---------------------------------------------------------------------------
# Physics frame
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
    velocity = get_velocity()
    was_on_floor = is_on_floor()

    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y += gravity * delta

    # State machine
    match state:
        AIState.IDLE:
            _update_idle()
        AIState.MOVE_TO_POSITION:
            _update_move_to_position()
        AIState.MOVE_TO_BALL:
            _update_move_to_ball()
        AIState.RECEIVE:
            _update_receive(delta)
        AIState.SET:
            _update_set(delta)
        AIState.RECOVER:
            _update_recover()
        AIState.BLOCK:
            _update_block(delta)

    # Facing direction based on movement
    if velocity.x > 0:
        facing_right = true
    elif velocity.x < 0:
        facing_right = false
    if visual:
        visual.flip_h = not facing_right

    set_velocity(velocity)
    move_and_slide()
    is_on_ground = is_on_floor()

    # Action timer countdown
    if _action_timer > 0.0:
        _action_timer -= delta
        if _action_timer <= 0.0:
            _on_action_complete()

# ---------------------------------------------------------------------------
# State update methods
# ---------------------------------------------------------------------------

func _enter_state(new_state: AIState) -> void:
    match new_state:
        AIState.RECEIVE, AIState.SET, AIState.BLOCK:
            _action_timer = _action_duration
            velocity.x = 0.0  # stop moving while acting
            if animator:
                match new_state:
                    AIState.RECEIVE: animator.play_receive()
                    AIState.SET: animator.play_set()
                    AIState.BLOCK: animator.play_block()
                    _: pass
        AIState.IDLE:
            if animator:
                animator.play_idle()
        AIState.MOVE_TO_POSITION, AIState.MOVE_TO_BALL:
            if animator:
                animator.play_run()
        _:
            pass

func _update_idle() -> void:
    velocity.x = 0.0

func _update_move_to_position() -> void:
    var dir: float = _sign(target_position.x - global_position.x)
    velocity.x = dir * speed
    # If close enough, snap to position
    if abs(target_position.x - global_position.x) < 10.0:
        velocity.x = 0.0
        global_position = Vector2(target_position.x, global_position.y)
        state = AIState.IDLE

func _update_move_to_ball() -> void:
    if ball == null:
        velocity.x = 0.0
        return
    var dir: float = _sign(ball.global_position.x - global_position.x)
    velocity.x = dir * speed
    # Stop when in receive range
    if abs(ball.global_position.x - global_position.x) < receive_range:
        velocity.x = 0.0
        state = AIState.RECEIVE

func _update_receive(delta: float) -> void:
    # Receiving: stay in place, ball will be hit by controller
    velocity.x = 0.0

func _update_set(delta: float) -> void:
    # Setting: stay in place briefly
    velocity.x = 0.0

func _update_recover() -> void:
    # Return to default position
    var dir: float = _sign(default_position.x - global_position.x)
    velocity.x = dir * speed
    if abs(default_position.x - global_position.x) < 10.0:
        velocity.x = 0.0
        state = AIState.IDLE

func _update_block(delta: float) -> void:
    # Block: jump at the net
    if is_on_floor() and _action_timer > 0.0:
        velocity.y = jump_velocity
        if animator:
            animator.play_jump()
    velocity.x = 0.0

func _on_action_complete() -> void:
    match state:
        AIState.RECEIVE:
            if is_setter:
                state = AIState.SET
                _action_timer = _action_duration
            else:
                state = AIState.RECOVER
        AIState.SET:
            state = AIState.RECOVER
        AIState.BLOCK:
            state = AIState.RECOVER
        _:
            pass

# ---------------------------------------------------------------------------
# Ball contact (AI "hits" the ball)
# ---------------------------------------------------------------------------

func is_ball_in_range() -> bool:
    if ball == null:
        return false
    return abs(ball.global_position.x - global_position.x) < receive_range and \
           abs(ball.global_position.y - global_position.y) < 60.0

# Expose for controller
func get_state() -> AIState:
    return state

# Helper: sign function
static func _sign(v: float) -> float:
    if v > 0: return 1.0
    if v < 0: return -1.0
    return 0.0

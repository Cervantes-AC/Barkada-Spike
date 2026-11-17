extends CharacterBody2D
class_name PlayerController

# PlayerController - human-controlled main attacker (Milestone 2 + 4).
#
# Handles:
#   - Left / right movement (keyboard A/D + mobile touch buttons)
#   - Jumping (keyboard SPACE + mobile jump button, only when on the floor)
#   - Gravity while in the air
#   - Facing direction and sprite flip
#   - Landing detection hook
#   - Ball contact detection (HitZone Area2D)
#   - Spike / attack with timing grades (PERFECT, GREAT, GOOD, LATE, MISS)
#   - Attack direction selection (keyboard Q/E + mobile aim buttons)
#
# Mobile input is injected via set_mobile_move(), set_mobile_aim(),
# mobile_jump(), mobile_spike() — wired from MobileControls in Main.gd.
#
# Attach to a CharacterBody2D (e.g. scenes/characters/Kai.tscn).
# Required child nodes: Visual (ColorRect), CollisionShape2D, HitZone (Area2D).
#
# Inputs (project.godot [input]):
#   - move_left / move_right   (A / D)
#   - jump                     (SPACE)
#   - spike                    (S key / mobile spike button)
#   - aim_left / aim_right     (Q / E / mobile aim buttons)

# --- Tuning (Inspector) ------------------------------------------------------

@export var speed: float = 340.0            # pixels per second (horizontal)
@export var jump_velocity: float = -720.0   # vertical jump impulse (pixels/sec)
@export var gravity: float = 1900.0         # downward acceleration (pixels/sec^2)

# Spike tuning
@export var spike_power_base: float = 900.0     # base spike speed (pixels/sec)
@export var spike_power_perfect_bonus: float = 450.0  # extra speed for PERFECT
@export var spike_max_power: float = 1600.0     # absolute cap
@export var spikeable_height_min: float = 250.0  # ball must be above this y to spike (smaller = higher)
@export var spikeable_height_max: float = 450.0  # ball must be below this y

# --- Timing grades -----------------------------------------------------------

enum TimingGrade { PERFECT, GREAT, GOOD, LATE, MISS }

# --- Internal state ----------------------------------------------------------

var velocity: Vector2 = Vector2.ZERO
var is_on_ground: bool = false
var facing_right: bool = true
var was_on_floor: bool = false

# Attack state
var is_spiking: bool = false
var attack_direction: float = 0.0   # -1 = angle left, 0 = straight, 1 = angle right
var current_ball: BallController = null   # ball currently inside HitZone
var last_timing_grade: TimingGrade = TimingGrade.MISS
var last_spike_power: float = 0.0

# Mobile input state (set by MobileControls via Main.gd wiring)
var mobile_move_x: float = 0.0
var mobile_aim_x: float = 0.0
var _pending_jump: bool = false
var _pending_spike: bool = false

# Network input state (set by NetworkManager via RPC for online play)
var is_remote: bool = false        # true = this player controlled by network
var remote_move_x: float = 0.0
var remote_jump: bool = false
var remote_spike: bool = false
var remote_aim_x: float = 0.0
var _remote_jump_pending: bool = false
var _remote_spike_pending: bool = false

# Peer ID for this player (used in online matches)
var network_peer_id: int = -1

# --- Node references ---------------------------------------------------------

@onready var visual: CanvasItem = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_zone: Area2D = $HitZone

# Animator (created in _ready if not present)
var animator: CharacterAnimator = null

# --- Signals -----------------------------------------------------------------

# Emitted when the player completes a spike attempt.
# grade: TimingGrade, power: float, direction: float
signal spike_completed(grade: int, power: float, direction: float)

# ---------------------------------------------------------------------------
# Mobile input API (called by Main.gd / MobileControls)
# ---------------------------------------------------------------------------

func set_mobile_move(x: float) -> void:
    mobile_move_x = clamp(x, -1.0, 1.0)

func set_mobile_aim(x: float) -> void:
    mobile_aim_x = clamp(x, -1.0, 1.0)

func mobile_jump() -> void:
    _pending_jump = true

func mobile_spike() -> void:
    _pending_spike = true

# ---------------------------------------------------------------------------
# Remote input API (called by NetworkManager via RPC for online play)
# ---------------------------------------------------------------------------

func set_remote_move(x: float) -> void:
    remote_move_x = clamp(x, -1.0, 1.0)

func set_remote_aim(x: float) -> void:
    remote_aim_x = clamp(x, -1.0, 1.0)

func remote_jump() -> void:
    _remote_jump_pending = true

func remote_spike() -> void:
    _remote_spike_pending = true

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------

func _ready() -> void:
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

    # Wire up ball contact detection.
    if hit_zone:
        hit_zone.body_entered.connect(_on_hit_zone_body_entered)
        hit_zone.body_exited.connect(_on_hit_zone_body_exited)

# ---------------------------------------------------------------------------
# Physics frame
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
    velocity = get_velocity()

    # Remember floor state before we move (landing detection).
    was_on_floor = is_on_floor()

    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y += gravity * delta

    # --- Combine keyboard + mobile + remote horizontal input -----------------
    var move_x: float = 0.0
    if is_remote:
        # Remote player: use network input
        move_x = remote_move_x
    else:
        # Local player: keyboard + mobile
        if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
            move_x += 1.0
        if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
            move_x -= 1.0
        move_x += mobile_move_x
    move_x = clamp(move_x, -1.0, 1.0)
    velocity.x = move_x * speed

    # --- Jump (keyboard + mobile + remote) -----------------------------------
    var jump_pressed: bool = False
    if is_remote:
        jump_pressed = _remote_jump_pending
        _remote_jump_pending = false
    else:
        jump_pressed = Input.is_action_just_pressed("jump") or Input.is_key_just_pressed(KEY_SPACE) or _pending_jump
        _pending_jump = false
    if is_on_floor() and jump_pressed:
        velocity.y = jump_velocity
        is_on_ground = false
        if animator:
            animator.play_jump()

    # --- Spike (keyboard + mobile + remote) ----------------------------------
    var spike_pressed: bool = False
    if is_remote:
        spike_pressed = _remote_spike_pending
        _remote_spike_pending = false
    else:
        spike_pressed = Input.is_action_just_pressed("spike") or Input.is_key_just_pressed(KEY_S) or _pending_spike
        _pending_spike = false
    if spike_pressed:
        _attempt_spike()

    # --- Animation state -----------------------------------------------------
    if is_spiking:
        pass  # spike animation played in _hit_ball
    elif is_on_floor():
        if abs(velocity.x) > 10.0:
            if animator:
                animator.play_run()
        else:
            if animator:
                animator.play_idle()

    # --- Combine keyboard + mobile + remote aim ------------------------------
    var aim_x: float = 0.0
    if is_remote:
        aim_x = remote_aim_x
    else:
        if Input.is_action_pressed("aim_right") or Input.is_key_pressed(KEY_E):
            aim_x += 1.0
        if Input.is_action_pressed("aim_left") or Input.is_key_pressed(KEY_Q):
            aim_x -= 1.0
        aim_x += mobile_aim_x
    aim_x = clamp(aim_x, -1.0, 1.0)
    if aim_x != 0.0:
        attack_direction = aim_x

    # --- Facing direction ----------------------------------------------------
    if move_x > 0:
        facing_right = true
    elif move_x < 0:
        facing_right = false

    if visual:
        visual.flip_h = not facing_right

    # --- Move ----------------------------------------------------------------
    set_velocity(velocity)
    move_and_slide()

    is_on_ground = is_on_floor()

    # --- Landing detection ---------------------------------------------------
    var just_landed: bool = is_on_floor() and not was_on_floor
    if just_landed:
        is_spiking = false
        if animator:
            animator.play_land()
        _on_landed()

# ---------------------------------------------------------------------------
# Spike / attack
# ---------------------------------------------------------------------------

func _attempt_spike() -> void:
    # Can only spike when in the air (jumped) and a ball is within reach.
    if is_spiking:
        return
    if is_on_floor():
        # Spiking from the ground is a weak set/bump, not a spike.
        _hit_ball(force_spike: false)
        return
    if current_ball == null:
        return  # no ball in reach

    _hit_ball(force_spike: true)

func _hit_ball(force_spike: bool) -> void:
    if current_ball == null:
        return

    var ball_pos: Vector2 = current_ball.global_position
    var player_pos: Vector2 = global_position

    # Calculate timing grade.
    var grade: TimingGrade = _calculate_timing_grade(ball_pos, player_pos, force_spike)
    last_timing_grade = grade

    # Calculate power based on grade.
    var power: float = spike_power_base
    if grade == TimingGrade.PERFECT:
        power += spike_power_perfect_bonus
    elif grade == TimingGrade.GREAT:
        power += spike_power_perfect_bonus * 0.5
    elif grade == TimingGrade.LATE:
        power *= 0.6
    elif grade == TimingGrade.MISS:
        power *= 0.3

    power = clamp(power, 0.0, spike_max_power)
    last_spike_power = power
    is_spiking = true

    # Play spike animation
    if animator:
        var is_perfect: bool = grade == TimingGrade.PERFECT
        animator.play_spike(is_perfect)

    # Build hit velocity: forward and downward (spike over the net).
    var dir_x: float = attack_direction
    if facing_right:
        dir_x = abs(dir_x) if dir_x != 0 else 1.0   # spike toward right side
    else:
        dir_x = -abs(dir_x) if dir_x != 0 else -1.0  # spike toward left side

    var spike_velocity: Vector2 = Vector2(dir_x * power * 0.5, -power * 0.8)
    # Add some upward arc if jumping at peak.
    if velocity.y < 0:
        spike_velocity.y -= 150.0

    # Apply to ball.
    var touching_team: int = 0  # player's team is team A (0)
    current_ball.set_velocity(spike_velocity, touching_team)

    # Emit signal for HUD / effects.
    spike_completed.emit(grade, power, attack_direction)

    # Release ball reference briefly so we don't double-hit same frame.
    current_ball = null

# ---------------------------------------------------------------------------
# Timing grade calculation
# ---------------------------------------------------------------------------

func _calculate_timing_grade(ball_pos: Vector2, player_pos: Vector2, force_spike: bool) -> TimingGrade:
    # Vertical difference: ball height relative to player (smaller y = higher).
    var height_diff: float = ball_pos.y - player_pos.y

    # Horizontal alignment (closer to 0 = better aligned).
    var align: float = abs(ball_pos.x - player_pos.x)

    # Jump phase: velocity.y < 0 = ascending, ~0 = peak, > 0 = descending.
    var jump_phase: float = velocity.y  # negative = going up

    # --- MISS conditions -----------------------------------------------------
    if not force_spike:
        # Ground bump/set: lower power, forgiving.
        if height_diff > spikeable_height_max:
            return TimingGrade.MISS   # ball too low
        if align > 60.0:
            return TimingGrade.MISS   # too far away
        return TimingGrade.GOOD

    # Airborne spike: stricter.
    if height_diff < spikeable_height_min or height_diff > spikeable_height_max:
        return TimingGrade.MISS       # ball not at spikeable height
    if align > 50.0:
        return TimingGrade.MISS       # not aligned with ball

    # --- PERFECT: near peak of jump, ball at ideal height, well aligned -----
    var is_at_peak: bool = abs(jump_phase) < 80.0   # near top of jump arc
    var ideal_height: bool = abs(height_diff - 120.0) < 60.0  # ball slightly above player
    var well_aligned: bool = align < 25.0

    if is_at_peak and ideal_height and well_aligned:
        return TimingGrade.PERFECT

    # --- GREAT: close to perfect ---------------------------------------------
    if (is_at_peak or ideal_height) and well_aligned:
        return TimingGrade.GREAT

    # --- GOOD: decent hit ----------------------------------------------------
    if well_aligned and height_diff > spikeable_height_min:
        return TimingGrade.GOOD

    # --- LATE: hit on the way down or poor alignment -------------------------
    if jump_phase > 100.0 or align > 35.0:
        return TimingGrade.LATE

    return TimingGrade.GOOD

# ---------------------------------------------------------------------------
# Ball contact detection (HitZone)
# ---------------------------------------------------------------------------

func _on_hit_zone_body_entered(body: Node2D) -> void:
    if body is BallController:
        current_ball = body

func _on_hit_zone_body_exited(body: Node2D) -> void:
    if body is BallController and current_ball == body:
        current_ball = null

# ---------------------------------------------------------------------------
# Hooks / public API
# ---------------------------------------------------------------------------

func _on_landed() -> void:
    # Hook: trigger land animation / dust effect (later milestones).
    pass

func get_facing_right() -> bool:
    return facing_right

func is_grounded() -> bool:
    return is_on_ground

func get_move_direction() -> float:
    var d: float = 0.0
    if velocity.x > 0: d = 1.0
    elif velocity.x < 0: d = -1.0
    return d

func get_timing_grade_name() -> String:
    match last_timing_grade:
        TimingGrade.PERFECT: return "PERFECT"
        TimingGrade.GREAT: return "GREAT"
        TimingGrade.GOOD: return "GOOD"
        TimingGrade.LATE: return "LATE"
        TimingGrade.MISS: return "MISS"
        _: return "MISS"

func is_spike_available() -> bool:
    return not is_on_floor() and current_ball != null and not is_spiking

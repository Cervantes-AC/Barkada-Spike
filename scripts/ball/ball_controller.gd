extends RigidBody2D
class_name BallController

# BallController - volleyball ball physics (Milestone 3).
#
# Handles:
#   - Manual gravity (full control over trajectory)
#   - Velocity + rotation (ball spins as it travels)
#   - Floor / net / boundary collisions
#   - Trail effect while in play
#   - Launch / hit API used by serve, receive, set, spike (later milestones)
#
# Node type: RigidBody2D (mode=rigid, gravity_scale=0 so we apply gravity manually).
# Required child nodes: Visual (ColorRect), CollisionShape2D (circle), Trail (Line2D).

# --- Tuning (Inspector) ------------------------------------------------------

@export var gravity: float = 1100.0       # pixels/sec^2 downward
@export var air_resistance: float = 0.992 # per-frame velocity multiplier
@export var max_speed: float = 1400.0     # pixels/sec
@export var rotation_speed: float = 3.0   # radians/sec per pixel of horizontal speed
@export var floor_bounce: float = 0.35    # how much vertical velocity is kept after floor hit
@export var net_bounce: float = 0.25      # how much velocity is kept after net hit
@export var court_center_x: float = 640.0 # x position of the net center (side divider)

# --- Signals -----------------------------------------------------------------

# Emitted when the ball contacts the floor. side: 0 = player side (left), 1 = opponent side (right).
signal ball_hit_floor(side: int)
# Emitted when the ball goes out of bounds. side: team that did NOT touch last (awarded point).
signal ball_out_of_bounds(side: int)
# Emitted when the ball is hit by a player or AI. team: 0 = player, 1 = opponent.
signal ball_hit(team: int)

# --- State -------------------------------------------------------------------

var is_in_play: bool = false
var is_held: bool = false                 # true while a player holds the ball (serve prep)
var last_touch_team: int = -1             # 0 = team A, 1 = team B
var touch_count: int = 0                  # team touches in current rally (max 3)

# When true, the ball begins falling immediately (useful for Milestone 3 testing;
# serve/hit systems set this properly in Milestone 4+).
@export var start_in_play: bool = true

# --- Node references ---------------------------------------------------------

@onready var visual: ColorRect = $Visual
@onready var trail: Line2D = $Trail
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Trail history (world positions)
var _trail_points: Array[Vector2] = []
var _trail_max_points: int = 12

func _ready() -> void:
    # We apply gravity manually, so disable built-in gravity scale.
    gravity_scale = 0.0
    can_sleep = false
    continuous_cd = true
    linear_velocity = Vector2.ZERO
    angular_velocity = 0.0

    # Body collisions: floor, net, players.
    body_entered.connect(_on_body_entered)
    # Area boundaries: out-of-bounds detection.
    area_entered.connect(_on_area_entered)

    is_in_play = start_in_play
    if start_in_play:
        trail.visible = true

    _reset_trail()

# ---------------------------------------------------------------------------
# Physics frame
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
    if is_held:
        # While held (e.g. on a player's hand before serve) the ball does not move.
        linear_velocity = Vector2.ZERO
        angular_velocity = 0.0
        return

    if not is_in_play:
        # Not in play: keep the ball still unless something launches it.
        if linear_velocity.length() < 5.0:
            linear_velocity = Vector2.ZERO
            angular_velocity = 0.0
        return

    # --- Apply gravity manually --------------------------------------------
    linear_velocity += Vector2(0, gravity) * delta

    # --- Air resistance -----------------------------------------------------
    linear_velocity *= air_resistance

    # --- Clamp max speed ----------------------------------------------------
    if linear_velocity.length() > max_speed:
        linear_velocity = linear_velocity.normalized() * max_speed

    # --- Rotation based on horizontal travel (ball spins as it moves) ------
    angular_velocity = linear_velocity.x * rotation_speed * 0.001

    # --- Update trail -------------------------------------------------------
    _update_trail(global_position)

# ---------------------------------------------------------------------------
# Collisions
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node2D) -> void:
    # Called when the ball collides with another physics body.
    # We inspect the body to decide: floor bounce, net deflect, or out-of-bounds.

    var name: String = body.name

    if name == "Floor":
        _handle_floor_bounce(body)
    elif name == "Net":
        _handle_net_collision(body)
    elif name == "BoundaryLeft" or name == "BoundaryRight":
        _handle_out_of_bounds()
    elif "Player" in name or "AI" in name:
        # Player / AI contact is handled by the attacker/hit system (Milestone 4).
        # Here we just register a light touch so the ball doesn't stick.
        pass

func _handle_floor_bounce(floor: Node2D) -> void:
    # Ball hit the floor. Report which side it landed on (rally ends here).
    var side: int = 0
    if global_position.x > court_center_x:
        side = 1
    ball_hit_floor.emit(side)

    # In a real rally this ends the point (Milestone 6),
    # but physically we bounce it slightly so it doesn't roll forever.
    var vel: Vector2 = linear_velocity
    vel.y = -vel.y * floor_bounce
    vel.x *= 0.7
    linear_velocity = vel
    angular_velocity = vel.x * rotation_speed * 0.001

    # If the ball has mostly stopped rolling, mark it dead.
    if abs(vel.y) < 20.0 and abs(vel.x) < 20.0:
        linear_velocity = Vector2.ZERO
        angular_velocity = 0.0

func _handle_net_collision(net: Node2D) -> void:
    # Ball hit the net: deflect horizontally and lose some speed.
    var vel: Vector2 = linear_velocity
    vel.x = -vel.x * net_bounce
    vel.y *= 0.9
    linear_velocity = vel
    angular_velocity = vel.x * rotation_speed * 0.001

func _handle_out_of_bounds() -> void:
    # Ball went outside court boundaries. Rally ends; the team that did NOT
    # touch the ball last is awarded the point.
    linear_velocity = Vector2.ZERO
    angular_velocity = 0.0
    is_in_play = false
    trail.visible = false

    # Award point to the team that did not touch last.
    var side: int = 0
    if last_touch_team == 0:
        side = 1
    ball_out_of_bounds.emit(side)

func _on_area_entered(area: Area2D) -> void:
    var name: String = area.name
    if name == "OutLeft" or name == "OutRight":
        _handle_out_of_bounds()

# ---------------------------------------------------------------------------
# Public API (used by serve / receive / set / spike in Milestone 4+)
# ---------------------------------------------------------------------------

# Launch the ball from a serve. direction is a normalized Vector2.
func serve(start_position: Vector2, direction: Vector2, power: float) -> void:
    global_position = start_position
    linear_velocity = direction.normalized() * power
    angular_velocity = direction.x * rotation_speed * 0.001
    is_in_play = true
    is_held = false
    touch_count = 0
    last_touch_team = -1
    _reset_trail()
    trail.visible = true

# Set the ball velocity directly (used by receive / set / spike).
func set_velocity(new_velocity: Vector2, touching_team: int) -> void:
    linear_velocity = new_velocity.clamp(Vector2(-max_speed, -max_speed), Vector2(max_speed, max_speed))
    angular_velocity = new_velocity.x * rotation_speed * 0.001
    is_in_play = true
    is_held = false
    last_touch_team = touching_team
    if touching_team >= 0:
        touch_count += 1
    _reset_trail()
    trail.visible = true
    ball_hit.emit(touching_team)

# Hold the ball on a player's hand (e.g. before serving).
func hold() -> void:
    is_held = true
    is_in_play = false
    linear_velocity = Vector2.ZERO
    angular_velocity = 0.0
    trail.visible = false

# Release a held ball.
func release() -> void:
    is_held = false

# Stop the ball (end of rally).
func stop() -> void:
    is_in_play = false
    is_held = false
    linear_velocity = Vector2.ZERO
    angular_velocity = 0.0
    trail.visible = false
    _reset_trail()

# Reset to a neutral position (start of match / new rally).
func reset(position: Vector2 = Vector2(640, 300)) -> void:
    stop()
    global_position = position

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _reset_trail() -> void:
    _trail_points.clear()
    trail.clear_points()

func _update_trail(point: Vector2) -> void:
    _trail_points.append(point)
    if _trail_points.size() > _trail_max_points:
        _trail_points.pop_front()
    trail.points = _trail_points.duplicate()

# Expose speed for HUD / AI prediction.
func get_speed() -> float:
    return linear_velocity.length()

func is_moving() -> bool:
    return linear_velocity.length() > 10.0

extends Node
class_name CharacterAnimator

# CharacterAnimator - tweens character visual properties based on state.
#
# Attach as a child node to any character (PlayerController, AICharacter).
# Uses Godot's Tween for smooth, reliable animation without AnimationPlayer
# scene dependencies.
#
# Required parent: CharacterBody2D with a "Visual" child node.

# --- Tuning ------------------------------------------------------------------

@export var jump_height: float = 50.0
@export var jump_duration: float = 0.5
@export var spike_squash_duration: float = 0.3
@export var land_squash_duration: float = 0.2

# --- Internal state ----------------------------------------------------------

var _visual: CanvasItem = null
var _tween: Tween = null
var _original_scale: Vector2 = Vector2(1, 1)
var _original_position: Vector2 = Vector2(0, 0)
var _is_playing: bool = false

func _ready() -> void:
    var parent: Node = get_parent()
    if parent is CharacterBody2D:
        _visual = parent.get_node_or_null("Visual")
    if _visual:
        _original_scale = _visual.scale
        _original_position = Vector2(0, 0)  # Visual is relative to parent

# ---------------------------------------------------------------------------
# Public API - called by parent character
# ---------------------------------------------------------------------------

func play_idle() -> void:
    # Idle: subtle bobbing
    if not _visual or _is_playing:
        return
    _tween = create_tween()
    _tween.tween_property(_visual, "scale", Vector2(1.02, 1.02), 1.0)
    _tween.tween_property(_visual, "scale", _original_scale, 1.0)
    _tween.set_loops(Tween.LOOP_PINGPONG)
    _tween.play()

func play_run() -> void:
    # Run: bounce up and down
    if not _visual or _is_playing:
        return
    _tween = create_tween()
    _tween.tween_property(_visual, "position:y", -4.0, 0.2)
    _tween.tween_property(_visual, "position:y", 4.0, 0.2)
    _tween.tween_property(_visual, "position:y", 0.0, 0.2)
    _tween.set_loops(Tween.LOOP_PINGPONG)
    _tween.play()

func play_jump() -> void:
    # Jump: squash then stretch upward
    if not _visual:
        return
    stop_current_tween()
    _tween = create_tween()
    _tween.tween_property(_visual, "scale", Vector2(0.95, 1.1), 0.1)
    _tween.tween_property(_visual, "scale", Vector2(1, 1), 0.1)
    _tween.tween_property(_visual, "position:y", -jump_height, jump_duration * 0.5)
    _tween.tween_property(_visual, "position:y", 0.0, jump_duration * 0.5)
    _tween.play()

func play_spike(perfect: bool = false) -> void:
    # Spike: stretch toward the hit direction
    if not _visual:
        return
    stop_current_tween()
    _tween = create_tween()
    _tween.tween_property(_visual, "scale", Vector2(1.15, 0.85), 0.1)
    _tween.tween_property(_visual, "scale", Vector2(0.85, 1.15), 0.1)
    _tween.tween_property(_visual, "scale", _original_scale, 0.1)
    if perfect:
        # Perfect spike: extra flash effect
        _tween.tween_property(_visual, "modulate", Color(1, 0.8, 0.8, 1), 0.05)
        _tween.tween_property(_visual, "modulate", _visual.modulate, 0.1)
    _tween.play()

func play_land() -> void:
    # Land: squash and stretch
    if not _visual:
        return
    stop_current_tween()
    _tween = create_tween()
    _tween.tween_property(_visual, "scale", Vector2(1.1, 0.9), 0.1)
    _tween.tween_property(_visual, "scale", Vector2(0.9, 1.1), 0.1)
    _tween.tween_property(_visual, "scale", _original_scale, 0.1)
    _tween.play()

func play_receive() -> void:
    # Receive: small bounce
    if not _visual:
        return
    stop_current_tween()
    _tween = create_tween()
    _tween.tween_property(_visual, "position:y", 10.0, 0.15)
    _tween.tween_property(_visual, "position:y", 0.0, 0.15)
    _tween.play()

func play_set() -> void:
    # Set: small upward bump
    if not _visual:
        return
    stop_current_tween()
    _tween = create_tween()
    _tween.tween_property(_visual, "position:y", -10.0, 0.15)
    _tween.tween_property(_visual, "position:y", 0.0, 0.15)
    _tween.play()

func play_block() -> void:
    # Block: jump up at net
    if not _visual:
        return
    stop_current_tween()
    _tween = create_tween()
    _tween.tween_property(_visual, "scale", Vector2(1.15, 0.85), 0.1)
    _tween.tween_property(_visual, "scale", Vector2(1, 1), 0.1)
    _tween.tween_property(_visual, "position:y", -40.0, 0.2)
    _tween.tween_property(_visual, "position:y", 0.0, 0.2)
    _tween.play()

func stop_current_tween() -> void:
    if _tween:
        _tween.kill()
        _tween = null

func stop_all() -> void:
    stop_current_tween()
    if _visual:
        _visual.scale = _original_scale
        _visual.position = _original_position

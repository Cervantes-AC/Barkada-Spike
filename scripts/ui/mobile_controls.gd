extends CanvasLayer
class_name MobileControls

# MobileControls - on-screen touch controls for BARKADA SPIKE (Milestone 2).
#
# Provides touch-friendly buttons:
#   - Move Left / Move Right (continuous while held)
#   - Jump (momentary)
#   - Spike (momentary)
#   - Aim Left / Aim Right (continuous while held)
#   - Pause
#
# Emits signals. Main.gd wires them to PlayerController so this UI layer stays
# decoupled from gameplay logic. Keyboard controls keep working in parallel.

# --- Signals -----------------------------------------------------------------

signal move_direction_changed(direction: float)   # -1 left, 0 idle, 1 right
signal jump_pressed()
signal spike_pressed()
signal aim_direction_changed(direction: float)    # -1 left, 0 neutral, 1 right
signal pause_pressed()

# --- Node references ---------------------------------------------------------

@onready var btn_move_left: Button = $MoveLeft
@onready var btn_move_right: Button = $MoveRight
@onready var btn_jump: Button = $Jump
@onready var btn_spike: Button = $Spike
@onready var btn_aim_left: Button = $AimLeft
@onready var btn_aim_right: Button = $AimRight
@onready var btn_pause: Button = $Pause

# --- Internal state ----------------------------------------------------------

var _move_direction: float = 0.0
var _aim_direction: float = 0.0

func _ready() -> void:
    # --- Move buttons (continuous while held) -------------------------------
    btn_move_left.pressed.connect(_on_move_left_pressed)
    btn_move_left.released.connect(_on_move_left_released)
    btn_move_right.pressed.connect(_on_move_right_pressed)
    btn_move_right.released.connect(_on_move_right_released)

    # --- Jump / Spike (momentary) ------------------------------------------
    btn_jump.pressed.connect(_on_jump_pressed)
    btn_spike.pressed.connect(_on_spike_pressed)

    # --- Aim buttons (continuous while held) --------------------------------
    btn_aim_left.pressed.connect(_on_aim_left_pressed)
    btn_aim_left.released.connect(_on_aim_left_released)
    btn_aim_right.pressed.connect(_on_aim_right_pressed)
    btn_aim_right.released.connect(_on_aim_right_released)

    # --- Pause --------------------------------------------------------------
    btn_pause.pressed.connect(_on_pause_pressed)

# Emit held directions every frame so the player moves smoothly.
func _process(delta: float) -> void:
    move_direction_changed.emit(_move_direction)
    aim_direction_changed.emit(_aim_direction)

# ---------------------------------------------------------------------------
# Move buttons
# ---------------------------------------------------------------------------

func _on_move_left_pressed() -> void:
    _move_direction = -1.0

func _on_move_left_released() -> void:
    if _move_direction < 0.0:
        _move_direction = 0.0

func _on_move_right_pressed() -> void:
    _move_direction = 1.0

func _on_move_right_released() -> void:
    if _move_direction > 0.0:
        _move_direction = 0.0

# ---------------------------------------------------------------------------
# Jump / Spike (momentary)
# ---------------------------------------------------------------------------

func _on_jump_pressed() -> void:
    jump_pressed.emit()

func _on_spike_pressed() -> void:
    spike_pressed.emit()

# ---------------------------------------------------------------------------
# Aim buttons
# ---------------------------------------------------------------------------

func _on_aim_left_pressed() -> void:
    _aim_direction = -1.0

func _on_aim_left_released() -> void:
    if _aim_direction < 0.0:
        _aim_direction = 0.0

func _on_aim_right_pressed() -> void:
    _aim_direction = 1.0

func _on_aim_right_released() -> void:
    if _aim_direction > 0.0:
        _aim_direction = 0.0

# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------

func _on_pause_pressed() -> void:
    pause_pressed.emit()

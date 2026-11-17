extends CanvasLayer
class_name GameplayHUD

# Gameplay HUD for BARKADA SPIKE.
# Displays score, current match phase, control hints, touch count, and spike timing feedback.

@onready var score_label: Label = $ScoreLabel
@onready var phase_label: Label = $PhaseLabel
@onready var timing_label: Label = $TimingLabel
@onready var touch_count_label: Label = $TouchCountLabel
@onready var hint_label: Label = $HintLabel

var score_team_a: int = 0
var score_team_b: int = 0

# Timer to auto-hide the timing feedback label.
var _timing_hide_timer: float = 0.0

func set_score(team_a: int, team_b: int) -> void:
    score_team_a = team_a
    score_team_b = team_b
    score_label.text = "KAI %d - %d OPPONENT" % [team_a, team_b]

func set_phase(phase_name: String) -> void:
    phase_label.text = phase_name

func show_timing(grade_name: String, power: float) -> void:
    if not timing_label:
        return
    var color: Color = Color(1, 0.9, 0.2, 1)
    match grade_name:
        "PERFECT": color = Color(0.2, 1, 0.2, 1)
        "GREAT": color = Color(0.2, 0.8, 1, 1)
        "GOOD": color = Color(1, 0.9, 0.2, 1)
        "LATE": color = Color(1, 0.6, 0.2, 1)
        "MISS": color = Color(1, 0.3, 0.3, 1)
    timing_label.custom_colors.font_color = color
    timing_label.text = "%s" % [grade_name]
    timing_label.visible = true
    _timing_hide_timer = 1.5

func set_touch_count(team: int, count: int) -> void:
    if team == 0:
        touch_count_label.text = "Touches: %d/3" % [count]
        touch_count_label.visible = true

func set_hint_visible(visible: bool) -> void:
    if hint_label:
        hint_label.visible = visible

func _ready() -> void:
    set_score(0, 0)
    set_phase("MATCH START")
    timing_label.visible = false
    touch_count_label.visible = false

func _process(delta: float) -> void:
    if _timing_hide_timer > 0.0:
        _timing_hide_timer -= delta
        if _timing_hide_timer <= 0.0 and timing_label:
            timing_label.visible = false

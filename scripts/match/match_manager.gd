extends Node
class_name MatchManager

# MatchManager - controls rally flow and match phases (Milestone 4 / 6).
#
# Works together with GameManager (scoring) and BallController (physics).
# Keeps rally state (serving team, touch counts, current phase) and emits
# signals so UI and gameplay can react without tight coupling.
#
# Later milestones extend this with full AI rally handling.

enum RallyPhase { IDLE, SERVE_PREP, BALL_IN_PLAY, RECEIVING, SETTING, ATTACKING, DEFENDING, RALLY_END }

# --- Config --------------------------------------------------------------------

@export var points_to_win: int = 15
@export var win_by: int = 2
@export var max_score: int = 21

# --- State ---------------------------------------------------------------------

var current_rally: RallyPhase = RallyPhase.IDLE
var serving_team: int = 0          # 0 = team A (player), 1 = team B (opponent)
var team_touches_a: int = 0
var team_touches_b: int = 0
var ball_crossed_net: bool = false
var net_touched: bool = false

# Scores (mirrored from GameManager so MatchManager can decide match end)
var score_team_a: int = 0
var score_team_b: int = 0

# --- Signals -------------------------------------------------------------------

signal rally_started(serving_team: int)
signal rally_ended(winning_team: int, reason: String)
signal phase_changed(new_phase: RallyPhase)
signal touch_updated(team: int, count: int)
signal score_point(team: int)       # team that just scored
signal match_ended(winner_team: int)

# ---------------------------------------------------------------------------
# Rally control
# ---------------------------------------------------------------------------

func start_match() -> void:
    score_team_a = 0
    score_team_b = 0
    team_touches_a = 0
    team_touches_b = 0
    serving_team = 0
    _set_rally(RallyPhase.SERVE_PREP)
    rally_started.emit(serving_team)
    score_point.emit(-1)  # -1 = reset scores

func start_rally(serving_team_index: int) -> void:
    serving_team = serving_team_index
    team_touches_a = 0
    team_touches_b = 0
    ball_crossed_net = false
    net_touched = false
    _set_rally(RallyPhase.SERVE_PREP)
    rally_started.emit(serving_team)

# Call this when the ball is served (leaves the server's hand).
func on_serve() -> void:
    _set_rally(RallyPhase.BALL_IN_PLAY)

# Register a touch by a team. Returns false if the touch limit would be exceeded.
func register_touch(team: int) -> bool:
    if team == 0:
        team_touches_a += 1
        touch_updated.emit(0, team_touches_a)
    elif team == 1:
        team_touches_b += 1
        touch_updated.emit(1, team_touches_b)
    return True

func set_ball_crossed_net(crossed: bool) -> void:
    ball_crossed_net = crossed

func set_net_touched(touched: bool) -> void:
    net_touched = touched

# ---------------------------------------------------------------------------
# Rally end / scoring
# ---------------------------------------------------------------------------

# End the current rally and award a point to the winning team.
# reason: "floor", "out", "net_fault", "touch_limit"
func end_rally(winning_team: int, reason: String) -> void:
    if winning_team == 0:
        score_team_a += 1
    elif winning_team == 1:
        score_team_b += 1
    score_point.emit(winning_team)

    _set_rally(RallyPhase.RALLY_END)
    rally_ended.emit(winning_team, reason)

    # Check match completion (delegated to VolleyballRules logic inline here).
    var winner: int = _check_match_complete()
    if winner >= 0:
        _set_rally(RallyPhase.IDLE)
        match_ended.emit(winner)
    else:
        # Next rally served by the team that won the point (rally scoring).
        # After a short delay the caller should call start_rally(winner).
        pass

func _check_match_complete() -> int:
    if score_team_a >= max_score or score_team_b >= max_score:
        if score_team_a >= points_to_win and (score_team_a - score_team_b) >= win_by:
            return 0
        if score_team_b >= points_to_win and (score_team_b - score_team_a) >= win_by:
            return 1
    return -1

func get_match_over() -> bool:
    return _check_match_complete() >= 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _set_rally(new_phase: RallyPhase) -> void:
    if current_rally == new_phase:
        return
    current_rally = new_phase
    phase_changed.emit(new_phase)

func get_phase_name() -> String:
    match current_rally:
        RallyPhase.IDLE: return "IDLE"
        RallyPhase.SERVE_PREP: return "SERVE PREP"
        RallyPhase.BALL_IN_PLAY: return "BALL IN PLAY"
        RallyPhase.RECEIVING: return "RECEIVING"
        RallyPhase.SETTING: return "SETTING"
        RallyPhase.ATTACKING: return "ATTACKING"
        RallyPhase.DEFENDING: return "DEFENDING"
        RallyPhase.RALLY_END: return "RALLY END"
        _: return "UNKNOWN"

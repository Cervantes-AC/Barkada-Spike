extends Node
class_name GameManager

# GameManager - high-level match state and scoring (BARKADA SPIKE).
# Autoload singleton registered in project.godot under the name "GameManager".
#
# Responsibilities (Milestone 1):
#   - Track match phase (see MatchPhase enum)
#   - Track team scores
#   - Expose signals so UI and gameplay can react without tight coupling
#
# Later milestones will extend this with match completion,
# tournament progression, and save/load integration.

# Match phases (simplified volleyball rules, spec section 5).
enum MatchPhase { MATCH_START, SERVE_PREPARATION, BALL_IN_PLAY, RECEIVING, SETTING, ATTACKING, OPPONENT_DEFENSE, RALLY_END, MATCH_END }

# Current phase
var current_phase: MatchPhase = MatchPhase.MATCH_START

# Scores
var score_team_a: int = 0
var score_team_b: int = 0

# Match configuration (kept configurable for future best-of-three)
@export var points_to_win: int = 15
@export var win_by: int = 2
@export var max_score: int = 21

# Game config for the current match session (set by menus before loading Main.tscn)
var game_config: Dictionary = {
    "mode": "quick",           # "story", "quick", "practice"
    "tournament_id": "",
    "match_index": 0,
    "player_character": "kai",
    "opponent_team": {},
    "difficulty": 1
}

# Signals - other systems connect to these (decoupled communication)
signal phase_changed(new_phase: MatchPhase)
signal score_updated(team_a: int, team_b: int)
signal match_ended(winner_team: int)

# ---------------------------------------------------------------------------
# Phase control
# ---------------------------------------------------------------------------

func set_phase(new_phase: MatchPhase) -> void:
    if current_phase == new_phase:
        return
    current_phase = new_phase
    phase_changed.emit(new_phase)

func get_phase_name() -> String:
    match current_phase:
        MatchPhase.MATCH_START: return "MATCH START"
        MatchPhase.SERVE_PREPARATION: return "SERVE PREPARATION"
        MatchPhase.BALL_IN_PLAY: return "BALL IN PLAY"
        MatchPhase.RECEIVING: return "RECEIVING"
        MatchPhase.SETTING: return "SETTING"
        MatchPhase.ATTACKING: return "ATTACKING"
        MatchPhase.OPPONENT_DEFENSE: return "OPPONENT DEFENSE"
        MatchPhase.RALLY_END: return "RALLY END"
        MatchPhase.MATCH_END: return "MATCH END"
        _: return "UNKNOWN"

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

func add_score(team: int) -> void:
    if team == 0:
        score_team_a += 1
    elif team == 1:
        score_team_b += 1
    score_updated.emit(score_team_a, score_team_b)

func reset_score() -> void:
    score_team_a = 0
    score_team_b = 0
    score_updated.emit(0, 0)

# Returns true if the match is over and sets the winner team.
func check_match_over() -> int:
    # Returns -1 if match is not over, otherwise the winning team index (0 or 1).
    var leader: int = -1
    if score_team_a >= max_score or score_team_b >= max_score:
        if score_team_a >= points_to_win and (score_team_a - score_team_b) >= win_by:
            leader = 0
        elif score_team_b >= points_to_win and (score_team_b - score_team_a) >= win_by:
            leader = 1
    if leader >= 0:
        set_phase(MatchPhase.MATCH_END)
        match_ended.emit(leader)
    return leader

# ---------------------------------------------------------------------------
# Game config (set by menus before loading gameplay scene)
# ---------------------------------------------------------------------------

func set_game_config(config: Dictionary) -> void:
    game_config = config

func get_game_config() -> Dictionary:
    return game_config.duplicate()

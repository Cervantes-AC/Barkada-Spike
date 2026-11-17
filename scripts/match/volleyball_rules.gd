extends Node
class_name VolleyballRules

# VolleyballRules - simplified volleyball rules (Milestone 4 / 6).
#
# Pure logic, no scene dependencies. Used by MatchManager and BallController
# to decide touch limits, faults, and match completion.
#
# All values are exported so they can be tuned in the Inspector or via resources.

# --- Match scoring config -----------------------------------------------------

@export var points_to_win: int = 15
@export var win_by: int = 2
@export var max_score: int = 21

# --- Rally rules --------------------------------------------------------------

@export var max_team_touches: int = 3   # maximum team touches before returning

# ---------------------------------------------------------------------------
# Touch limit
# ---------------------------------------------------------------------------

# Returns true if the team has used up all allowed touches.
func is_touch_limit_exceeded(touch_count: int) -> bool:
    return touch_count >= max_team_touches

# ---------------------------------------------------------------------------
# Net fault
# ---------------------------------------------------------------------------

# A net fault occurs when the ball touches the net and does not cross to
# the opponent's side.
func is_net_fault(touched_net: bool, crossed_net: bool) -> bool:
    return touched_net and not crossed_net

# ---------------------------------------------------------------------------
# Out of bounds
# ---------------------------------------------------------------------------

# Returns true if a world x-position is outside the court horizontal bounds.
func is_out_of_bounds_x(x: float, court_left: float, court_right: float) -> bool:
    return x < court_left or x > court_right

# ---------------------------------------------------------------------------
# Match completion
# ---------------------------------------------------------------------------

# Returns -1 if the match is not over, otherwise the winning team index (0 or 1).
func check_match_over(score_team_a: int, score_team_b: int) -> int:
    if score_team_a >= max_score or score_team_b >= max_score:
        if score_team_a >= points_to_win and (score_team_a - score_team_b) >= win_by:
            return 0
        if score_team_b >= points_to_win and (score_team_b - score_team_a) >= win_by:
            return 1
    return -1

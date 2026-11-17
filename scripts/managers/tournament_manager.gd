extends Node
class_name TournamentManager

# TournamentManager - manages 5 tournaments x 3 matches, sequential unlocking.
# Tournament data is loaded from resources/tournaments/.

# --- Signals -----------------------------------------------------------------

signal tournament_unlocked(tournament_id: String)
signal tournament_completed(tournament_id: String)
signal match_completed(tournament_id: String, match_index: int, won: bool)
signal all_tournaments_loaded()

# --- Tournament resources ----------------------------------------------------

var tournaments: Dictionary = {}   # tournament_id -> TournamentData

# Order of tournaments (sequential unlocking)
var tournament_order: Array[String] = [
    "rookie",
    "school",
    "regional",
    "national",
    "grand_finals"
]

func _ready() -> void:
    _load_all_tournaments()
    _sync_with_save()

# ---------------------------------------------------------------------------
# Load all tournament resources
# ---------------------------------------------------------------------------

func _load_all_tournaments() -> void:
    var tournament_ids: Array[String] = [
        "rookie", "school", "regional", "national", "grand_finals"
    ]
    for id in tournament_ids:
        var res: TournamentData = load("res://resources/tournaments/%s_tournament.tres" % [id])
        if res:
            tournaments[id] = res
        else:
            push_warning("TournamentManager: could not load %s_tournament.tres" % [id])
    all_tournaments_loaded.emit()

# Sync in-memory state with SaveManager
func _sync_with_save() -> void:
    if not SaveManager:
        return
    for id in tournament_order:
        var res: TournamentData = tournaments.get(id)
        if not res:
            continue
        res.is_unlocked = SaveManager.is_tournament_unlocked(id)
        res.matches_completed = SaveManager.get_tournament_matches_completed(id)
        res.is_completed = SaveManager.is_tournament_completed(id)

# ---------------------------------------------------------------------------
# Getters
# ---------------------------------------------------------------------------

func get_tournament(tournament_id: String) -> TournamentData:
    return tournaments.get(tournament_id)

func get_tournament_order() -> Array[String]:
    return tournament_order.duplicate()

func get_current_tournament_index() -> int:
    # Returns index of first incomplete tournament, or -1 if all completed
    for i in range(tournament_order.size()):
        var t: TournamentData = tournaments.get(tournament_order[i])
        if t and not t.is_completed:
            return i
    return -1

func get_next_locked_tournament() -> String:
    for id in tournament_order:
        var t: TournamentData = tournaments.get(id)
        if t and not t.is_unlocked:
            return id
    return ""

func is_tournament_unlocked(tournament_id: String) -> bool:
    var t: TournamentData = tournaments.get(tournament_id)
    return t.is_unlocked if t else false

func is_tournament_completed(tournament_id: String) -> bool:
    var t: TournamentData = tournaments.get(tournament_id)
    return t.is_completed if t else false

func get_match_opponent(tournament_id: String, match_index: int) -> Dictionary:
    var t: TournamentData = tournaments.get(tournament_id)
    if t:
        return t.get_match_opponent(match_index)
    return {}

func is_match_unlocked(tournament_id: String, match_index: Int) -> bool:
    var t: TournamentData = tournaments.get(tournament_id)
    if t:
        return t.is_match_unlocked(match_index)
    return false

# ---------------------------------------------------------------------------
# Match completion
# ---------------------------------------------------------------------------

func mark_match_completed(tournament_id: String, match_index: int, won: bool) -> void:
    var t: TournamentData = tournaments.get(tournament_id)
    if not t:
        return

    # Mark match complete (sequential)
    if match_index >= t.matches_completed:
        t.mark_match_complete()
        SaveManager.set_tournament_match_complete(tournament_id, match_index)
        SaveManager.save()

    match_completed.emit(tournament_id, match_index, won)

    # Check if tournament completed
    if t.is_completed:
        tournament_completed.emit(tournament_id)
        # Unlock next tournament
        _unlock_next_tournament(tournament_id)

# ---------------------------------------------------------------------------
# Unlock next tournament
# ---------------------------------------------------------------------------

func _unlock_next_tournament(completed_id: String) -> void:
    var current_index: int = tournament_order.find(completed_id)
    if current_index >= 0 and current_index + 1 < tournament_order.size():
        var next_id: String = tournament_order[current_index + 1]
        var next_t: TournamentData = tournaments.get(next_id)
        if next_t and not next_t.is_unlocked:
            next_t.is_unlocked = true
            SaveManager.unlock_tournament(next_id)
            SaveManager.save()
            tournament_unlocked.emit(next_id)

# ---------------------------------------------------------------------------
# Reset (for testing)
# ---------------------------------------------------------------------------

func reset_all() -> void:
    for id in tournament_order:
        var t: TournamentData = tournaments.get(id)
        if t:
            t.reset()
    if SaveManager:
        SaveManager.save()

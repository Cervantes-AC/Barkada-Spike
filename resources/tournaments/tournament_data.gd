extends Resource
class_name TournamentData

# TournamentData - reusable tournament resource.
# Defines a tournament with 3 matches, opponents, and unlock state.

@export var tournament_id: String = ""
@export var display_name: String = "Tournament"
@export var unlock_cost: int = 0
@export var is_unlocked: bool = false
@export var matches_completed: int = 0
@export var is_completed: bool = false
@export var reward_coins: int = 150
@export var difficulty: int = 1  # 0=Easy, 1=Medium, 2=Hard
@export var opponent_teams: Array[Dictionary] = []

# Total matches in tournament
@export var total_matches: int = 3

func _init(id: String = "", name: String = "", unlocked: bool = false,
           reward_coins: int = 150, difficulty: int = 1) -> void:
    tournament_id = id
    display_name = name
    is_unlocked = unlocked
    self.reward_coins = reward_coins
    self.difficulty = difficulty

func get_match_opponent(index: int) -> Dictionary:
    if index >= 0 and index < opponent_teams.size():
        return opponent_teams[index]
    return {}

func is_match_unlocked(index: int) -> bool:
    # Match N is unlocked if matches_completed >= N (sequential)
    return index <= matches_completed

func mark_match_complete() -> void:
    matches_completed += 1
    if matches_completed >= total_matches:
        is_completed = true

func reset() -> void:
    matches_completed = 0
    is_completed = false

extends Node
class_name ProgressionManager

# ProgressionManager - economy and rewards for BARKADA SPIKE.
#
# Reward values (configurable):
#   - Match victory: 50 coins
#   - Match defeat: 15 coins
#   - Tournament completion: 150 coins
#   - Perfect spike challenge: 25 coins

# --- Config ------------------------------------------------------------------

@export var coins_match_victory: int = 50
@export var coins_match_defeat: int = 15
@export var coins_tournament_completion: int = 150
@export var coins_perfect_spike: int = 25

# --- Signals -----------------------------------------------------------------

signal coins_changed(new_amount: int)
signal reward_earned(reason: String, amount: int)

# ---------------------------------------------------------------------------
# Match rewards
# ---------------------------------------------------------------------------

func get_match_reward(won: bool) -> int:
    return coins_match_victory if won else coins_match_defeat

func award_match_reward(won: bool, perfect_spikes: int = 0) -> int:
    var coins: int = get_match_reward(won)
    if perfect_spikes > 0:
        coins += coins_perfect_spike * perfect_spikes
    if SaveManager:
        SaveManager.add_coins(coins)
        SaveManager.save()
    coins_changed.emit(SaveManager.get_coins())
    reward_earned.emit("match", coins)
    return coins

func award_tournament_completion(tournament_id: String) -> int:
    var t: TournamentData = TournamentManager.get_tournament(tournament_id) if TournamentManager else null
    var coins: int = t.reward_coins if t else coins_tournament_completion
    if SaveManager:
        SaveManager.add_coins(coins)
        SaveManager.save()
    coins_changed.emit(SaveManager.get_coins())
    reward_earned.emit("tournament", coins)
    return coins

# ---------------------------------------------------------------------------
# Character unlock cost
# ---------------------------------------------------------------------------

func get_unlock_cost(character_id: String) -> int:
    var data: CharacterData = CharacterManager.get_character_data(character_id) if CharacterManager else null
    return data.unlock_cost if data else 0

func can_afford_character(character_id: String) -> bool:
    if not SaveManager:
        return false
    var cost: int = get_unlock_cost(character_id)
    return SaveManager.get_coins() >= cost

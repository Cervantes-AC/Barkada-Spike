extends Node
class_name CharacterManager

# CharacterManager - manages character data, selection, unlocks, levels, XP.
# Loads CharacterData resources from resources/characters/.

# --- Signals -----------------------------------------------------------------

signal character_unlocked(character_id: String)
signal character_selected(character_id: String)
signal character_leveled_up(character_id: String, new_level: int)
signal character_xp_added(character_id: String, amount: int)

# --- Node references (set via inspector or code) -----------------------------

# Character resources are loaded dynamically
var character_resources: Dictionary = {}   # character_id -> CharacterData

func _ready() -> void:
    _load_all_characters()

# ---------------------------------------------------------------------------
# Load all character resources
# ---------------------------------------------------------------------------

func _load_all_characters() -> void:
    var character_ids: Array[String] = [ "kai", "ren", "jiro", "mika", "dax", "yuna" ]
    for id in character_ids:
        var res: CharacterData = load("res://resources/characters/%s.tres" % [id])
        if res:
            character_resources[id] = res
        else:
            push_warning("CharacterManager: could not load %s.tres" % [id])

# ---------------------------------------------------------------------------
# Getters
# ---------------------------------------------------------------------------

func get_character_data(character_id: String) -> CharacterData:
    return character_resources.get(character_id)

func get_all_characters() -> Array[CharacterData]:
    var list: Array[CharacterData] = []
    for id in character_resources.keys():
        list.append(character_resources[id])
    return list

func get_selected_character_id() -> String:
    if SaveManager:
        return SaveManager.get_selected_character()
    return "kai"

func set_selected_character(character_id: String) -> void:
    # Verify character is unlocked
    if not is_character_unlocked(character_id):
        push_warning("CharacterManager: %s is not unlocked" % [character_id])
        return
    if SaveManager:
        SaveManager.set_selected_character(character_id)
        SaveManager.save()
    character_selected.emit(character_id)

func is_character_unlocked(character_id: String) -> bool:
    if SaveManager:
        return SaveManager.is_character_unlocked(character_id)
    return character_id == "kai"

func get_character_level(character_id: String) -> int:
    if SaveManager:
        return SaveManager.get_character_level(character_id)
    return 1

func get_character_experience(character_id: String) -> int:
    if SaveManager:
        return SaveManager.get_character_experience(character_id)
    return 0

# ---------------------------------------------------------------------------
# Unlock / XP
# ---------------------------------------------------------------------------

func unlock_character(character_id: String, coins_cost: int) -> bool:
    if is_character_unlocked(character_id):
        return false  # already unlocked
    if SaveManager:
        var coins: int = SaveManager.get_coins()
        if coins < coins_cost:
            return false  # not enough coins
        SaveManager.add_coins(-coins_cost)
        SaveManager.unlock_character(character_id)
        SaveManager.save()
    character_unlocked.emit(character_id)
    return true

func add_character_experience(character_id: String, amount: int) -> int:
    var leveled: int = 0
    if SaveManager:
        leveled = SaveManager.add_character_experience(character_id, amount)
        SaveManager.save()
    if leveled > 0:
        character_leveled_up.emit(character_id, get_character_level(character_id))
    character_xp_added.emit(character_id, amount)
    return leveled

# ---------------------------------------------------------------------------
# Stat multiplier for gameplay
# ---------------------------------------------------------------------------

func get_stat_multiplier(character_id: String, stat_name: String) -> float:
    var data: CharacterData = get_character_data(character_id)
    if data:
        return data.get_stat_multiplier(stat_name)
    return 1.0

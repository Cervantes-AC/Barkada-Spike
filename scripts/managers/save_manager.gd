extends Node
class_name SaveManager

# SaveManager - persistent local save/load using JSON in user://.
#
# Save format version 1. Handles:
#   - Player profile (name, selected character, coins)
#   - Character unlocks, levels, experience
#   - Tournament progression (unlocked, matches completed, completed)
#   - Match statistics (played, won, perfect spikes)
#   - Settings (music volume, sfx volume)
#
# Features:
#   - Save after matches, purchases, unlocks
#   - Load on start; handle missing/corrupt files
#   - Backup file (save.json.bak)
#   - Save-version migration

const SAVE_FILE: String = "user://save.json"
const BACKUP_FILE: String = "user://save.json.bak"
const SAVE_VERSION: int = 1

# --- Signals -----------------------------------------------------------------

signal save_completed()
signal load_completed()
signal save_failed(error: String)

# --- Internal state ----------------------------------------------------------

var save_data: Dictionary = {}

func _ready() -> void:
    # Ensure user directory exists
    var dir: DirAccess = DirAccess.open("user://")
    if dir == null:
        DirAccess.make_dir("user://")

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func save() -> void:
    var json_string: String = JSON.stringify(save_data, "\t")
    var file: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if file == null:
        save_failed.emit("Could not open save file for writing")
        return
    file.store_string(json_string)
    file.close()

    # Create backup
    var backup: FileAccess = FileAccess.open(BACKUP_FILE, FileAccess.WRITE)
    if backup != null:
        backup.store_string(json_string)
        backup.close()

    save_completed.emit()

func save_after_match(winner_team: int, is_story: bool, tournament_id: String = "",
                      match_index: int = -1, perfect_spikes: int = 0,
                      coins_earned: int = 0) -> void:
    # Update stats
    var stats: Dictionary = save_data.get("stats", {})
    stats["matches_played"] = stats.get("matches_played", 0) + 1
    if winner_team == 0:  # player team won
        stats["matches_won"] = stats.get("matches_won", 0) + 1
    stats["perfect_spikes"] = stats.get("perfect_spikes", 0) + perfect_spikes
    save_data["stats"] = stats

    # Add coins
    var profile: Dictionary = save_data.get("player_profile", {})
    profile["coins"] = profile.get("coins", 0) + coins_earned
    save_data["player_profile"] = profile

    # Update tournament progression (story mode)
    if is_story and tournament_id != "":
        var tournaments: Dictionary = save_data.get("tournaments", {})
        var t_data: Dictionary = tournaments.get(tournament_id, {})
        if match_index >= 0:
            t_data["matches_completed"] = match_index + 1
        tournaments[tournament_id] = t_data
        save_data["tournaments"] = tournaments

    save()

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

func load() -> bool:
    var file: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.READ)
    if file == null:
        # No save file: create default
        _create_default_save()
        save()
        load_completed.emit()
        return true

    var json_string: String = file.get_as_text()
    file.close()

    var result: Error
    var parsed: Variant
    parsed, result = JSON.parse(json_string)
    if result != Error.OK or typeof(parsed) != TYPE_DICTIONARY:
        # Corrupt file: try backup
        push_warning("Save file corrupt, attempting backup recovery")
        return _load_from_backup()

    save_data = parsed
    _migrate_save(save_data)
    load_completed.emit()
    return true

func _load_from_backup() -> bool:
    var file: FileAccess = FileAccess.open(BACKUP_FILE, FileAccess.READ)
    if file == null:
        # No backup either: create default
        _create_default_save()
        save()
        load_completed.emit()
        return true

    var json_string: String = file.get_as_text()
    file.close()

    var result: Error
    var parsed: Variant
    parsed, result = JSON.parse(json_string)
    if result != Error.OK or typeof(parsed) != TYPE_DICTIONARY:
        # Both corrupt: create default
        _create_default_save()
        save()
        load_completed.emit()
        return true

    save_data = parsed
    _migrate_save(save_data)
    load_completed.emit()
    return true

# ---------------------------------------------------------------------------
# Default save data
# ---------------------------------------------------------------------------

func _create_default_save() -> void:
    save_data = {
        "version": SAVE_VERSION,
        "player_profile": {
            "name": "Player",
            "selected_character": "kai",
            "coins": 0
        },
        "characters": {
            "kai": { "unlocked": true, "level": 1, "experience": 0 },
            "ren": { "unlocked": false, "level": 1, "experience": 0 },
            "jiro": { "unlocked": false, "level": 1, "experience": 0 },
            "mika": { "unlocked": false, "level": 1, "experience": 0 },
            "dax": { "unlocked": false, "level": 1, "experience": 0 },
            "yuna": { "unlocked": false, "level": 1, "experience": 0 }
        },
        "tournaments": {
            "rookie": { "is_unlocked": true, "matches_completed": 0, "is_completed": false },
            "school": { "is_unlocked": false, "matches_completed": 0, "is_completed": false },
            "regional": { "is_unlocked": false, "matches_completed": 0, "is_completed": false },
            "national": { "is_unlocked": false, "matches_completed": 0, "is_completed": false },
            "grand_finals": { "is_unlocked": false, "matches_completed": 0, "is_completed": false }
        },
        "stats": {
            "matches_played": 0,
            "matches_won": 0,
            "perfect_spikes": 0
        },
        "settings": {
            "music_volume": 0.7,
            "sfx_volume": 0.8
        }
    }

# ---------------------------------------------------------------------------
# Save version migration
# ---------------------------------------------------------------------------

func _migrate_save(data: Dictionary) -> void:
    var version: int = data.get("version", 0)
    if version < SAVE_VERSION:
        # Migration from v0 to v1: ensure all fields exist
        if not data.has("player_profile"):
            data["player_profile"] = { "name": "Player", "selected_character": "kai", "coins": 0 }
        if not data.has("characters"):
            data["characters"] = {}
        if not data.has("tournaments"):
            data["tournaments"] = {}
        if not data.has("stats"):
            data["stats"] = { "matches_played": 0, "matches_won": 0, "perfect_spikes": 0 }
        if not data.has("settings"):
            data["settings"] = { "music_volume": 0.7, "sfx_volume": 0.8 }
        data["version"] = SAVE_VERSION

# ---------------------------------------------------------------------------
# Getters / Setters
# ---------------------------------------------------------------------------

func get_data() -> Dictionary:
    return save_data

func get_coins() -> int:
    return save_data.get("player_profile", {}).get("coins", 0)

func set_coins(amount: int) -> void:
    var profile: Dictionary = save_data.get("player_profile", {})
    profile["coins"] = amount
    save_data["player_profile"] = profile

func add_coins(amount: int) -> void:
    var profile: Dictionary = save_data.get("player_profile", {})
    profile["coins"] = profile.get("coins", 0) + amount
    save_data["player_profile"] = profile

func get_selected_character() -> String:
    return save_data.get("player_profile", {}).get("selected_character", "kai")

func set_selected_character(character_id: String) -> void:
    var profile: Dictionary = save_data.get("player_profile", {})
    profile["selected_character"] = character_id
    save_data["player_profile"] = profile

func is_character_unlocked(character_id: String) -> bool:
    var chars: Dictionary = save_data.get("characters", {})
    var c: Dictionary = chars.get(character_id, {})
    return c.get("unlocked", false)

func unlock_character(character_id: String) -> void:
    var chars: Dictionary = save_data.get("characters", {})
    if chars.has(character_id):
        var c: Dictionary = chars[character_id]
        c["unlocked"] = true
        chars[character_id] = c
        save_data["characters"] = chars

func get_character_level(character_id: String) -> int:
    var chars: Dictionary = save_data.get("characters", {})
    var c: Dictionary = chars.get(character_id, {})
    return c.get("level", 1)

func get_character_experience(character_id: String) -> int:
    var chars: Dictionary = save_data.get("characters", {})
    var c: Dictionary = chars.get(character_id, {})
    return c.get("experience", 0)

func add_character_experience(character_id: String, amount: int) -> int:
    var chars: Dictionary = save_data.get("characters", {})
    if not chars.has(character_id):
        return 0
    var c: Dictionary = chars[character_id]
    c["experience"] = c.get("experience", 0) + amount
    var leveled: int = 0
    while c.get("experience", 0) >= c.get("experience_to_next", 100) and c.get("level", 1) < 50:
        c["experience"] = c.get("experience", 0) - c.get("experience_to_next", 100)
        c["level"] = c.get("level", 1) + 1
        c["experience_to_next"] = int(c.get("experience_to_next", 100) * 1.5)
        leveled += 1
    chars[character_id] = c
    save_data["characters"] = chars
    return leveled

func is_tournament_unlocked(tournament_id: String) -> bool:
    var tours: Dictionary = save_data.get("tournaments", {})
    var t: Dictionary = tours.get(tournament_id, {})
    return t.get("is_unlocked", false)

func unlock_tournament(tournament_id: String) -> void:
    var tours: Dictionary = save_data.get("tournaments", {})
    if tours.has(tournament_id):
        var t: Dictionary = tours[tournament_id]
        t["is_unlocked"] = true
        tours[tournament_id] = t
        save_data["tournaments"] = tours

func get_tournament_matches_completed(tournament_id: String) -> int:
    var tours: Dictionary = save_data.get("tournaments", {})
    var t: Dictionary = tours.get(tournament_id, {})
    return t.get("matches_completed", 0)

func set_tournament_match_complete(tournament_id: String, match_index: int) -> void:
    var tours: Dictionary = save_data.get("tournaments", {})
    if tours.has(tournament_id):
        var t: Dictionary = tours[tournament_id]
        t["matches_completed"] = match_index + 1
        if t["matches_completed"] >= 3:
            t["is_completed"] = true
        tours[tournament_id] = t
        save_data["tournaments"] = tours

func is_tournament_completed(tournament_id: String) -> bool:
    var tours: Dictionary = save_data.get("tournaments", {})
    var t: Dictionary = tours.get(tournament_id, {})
    return t.get("is_completed", false)

func get_setting(setting_name: String, default_value: Variant = 0) -> Variant:
    return save_data.get("settings", {}).get(setting_name, default_value)

func set_setting(setting_name: String, value: Variant) -> void:
    var settings: Dictionary = save_data.get("settings", {})
    settings[setting_name] = value
    save_data["settings"] = settings

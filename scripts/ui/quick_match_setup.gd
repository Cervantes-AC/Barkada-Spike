extends Control
class_name QuickMatchSetup

# QuickMatchSetup - select character, AI difficulty, opponent team for Quick Match.

@onready var char_list: ItemList = $CharacterContainer/CharList
@onready var char_info: Label = $CharacterContainer/CharInfo
@onready var diff_list: ItemList = $DifficultyContainer/DiffList
@onready var opp_list: ItemList = $OpponentContainer/OppList
@onready var btn_start: Button = $BtnStart
@onready var coins_label: Label = $CoinsLabel

var selected_character: String = "kai"
var selected_difficulty: int = 1   # 0=Easy, 1=Medium, 2=Hard
var selected_opponent: Dictionary = {}

func _ready() -> void:
    # Populate character list (only unlocked)
    if CharacterManager:
        for data in CharacterManager.get_all_characters():
            if CharacterManager.is_character_unlocked(data.character_id):
                char_list.add_item(data.display_name)
                char_list.set_item_metadata(char_list.get_item_count() - 1, data.character_id)
        char_list.item_selected.connect(_on_character_selected)
        if char_list.get_item_count() > 0:
            char_list.select(0)
            _on_character_selected(0)

    # Populate difficulty
    diff_list.add_item("Easy")
    diff_list.add_item("Medium")
    diff_list.add_item("Hard")
    diff_list.select(1)
    diff_list.item_selected.connect(_on_difficulty_selected)

    # Populate opponents
    var opponents: Array[Dictionary] = [
        { "name": "Eastside Eagles", "difficulty": 0, "setter": "Ren", "defender": "Jiro", "attacker": "Dax" },
        { "name": "Northview Nets", "difficulty": 1, "setter": "Yuna", "defender": "Jiro", "attacker": "Dax" },
        { "name": "Westwood Spikers", "difficulty": 2, "setter": "Ren", "defender": "Jiro", "attacker": "Dax" }
    ]
    for opp in opponents:
        opp_list.add_item("%s (Lvl %d)" % [opp.name, opp.difficulty + 1])
        opp_list.set_item_metadata(opp_list.get_item_count() - 1, opp)
    opp_list.item_selected.connect(_on_opponent_selected)
    if opp_list.get_item_count() > 0:
        opp_list.select(0)
        _on_opponent_selected(0)

    # Update coins
    _update_coins()
    if ProgressionManager:
        ProgressionManager.coins_changed.connect(_update_coins)

    btn_start.pressed.connect(_on_start_pressed)

func _update_coins(_amount: int = -1) -> void:
    if SaveManager:
        coins_label.text = "Coins: %d" % [SaveManager.get_coins()]

func _on_character_selected(index: int) -> void:
    selected_character = char_list.get_item_metadata(index)
    var data: CharacterData = CharacterManager.get_character_data(selected_character)
    if data:
        char_info.text = "%s\n%s\nSpike: %.1f  Speed: %.1f  Jump: %.1f" % [
            data.display_name, data.ability_name,
            data.spike_power, data.speed, data.jump
        ]
    _update_start_button()

func _on_difficulty_selected(index: int) -> void:
    selected_difficulty = index
    _update_start_button()

func _on_opponent_selected(index: int) -> void:
    selected_opponent = opp_list.get_item_metadata(index)
    _update_start_button()

func _update_start_button() -> void:
    btn_start.disabled = selected_character == "" or selected_opponent == {}

func _on_start_pressed() -> void:
    var config: Dictionary = {
        "mode": "quick",
        "tournament_id": "",
        "match_index": 0,
        "player_character": selected_character,
        "opponent_team": selected_opponent,
        "difficulty": selected_difficulty
    }
    GameManager.set_game_config(config)
    get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

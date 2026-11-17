extends Control
class_name PracticeMode

# PracticeMode - practice movement, jumping, spiking, timing without a full match.

@onready var btn_start: Button = $BtnStartPractice
@onready var coins_label: Label = $CoinsLabel

func _ready() -> void:
    btn_start.pressed.connect(_on_start_pressed)
    _update_coins()
    if ProgressionManager:
        ProgressionManager.coins_changed.connect(_update_coins)

func _update_coins(_amount: int = -1) -> void:
    if SaveManager:
        coins_label.text = "Coins: %d" % [SaveManager.get_coins()]

func _on_start_pressed() -> void:
    var config: Dictionary = {
        "mode": "practice",
        "tournament_id": "",
        "match_index": 0,
        "player_character": SaveManager.get_selected_character(),
        "opponent_team": {},
        "difficulty": 0
    }
    GameManager.set_game_config(config)
    get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

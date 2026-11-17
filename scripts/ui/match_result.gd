extends Control
class_name MatchResult

# MatchResult - shows match outcome, coins earned, and returns to appropriate menu.

@onready var result_title: Label = $ResultTitle
@onready var score_label: Label = $ScoreLabel
@onready var reward_label: Label = $RewardLabel
@onready var perfect_label: Label = $PerfectLabel
@onready var btn_continue: Button = $BtnContinue

var won: bool = false
var coins_earned: int = 0
var perfect_spikes: int = 0
var return_to_menu: bool = false  # if true, go to main menu; if story, go to story mode

func _ready() -> void:
    btn_continue.pressed.connect(_on_continue_pressed)
    _show_result()

func set_result(won: bool, score_team_a: int, score_team_b: int, coins: int, perfect: int, return_to_menu: bool = false) -> void:
    self.won = won
    self.coins_earned = coins
    self.perfect_spikes = perfect
    self.return_to_menu = return_to_menu

func _show_result() -> void:
    result_title.text = won ? "VICTORY" : "DEFEAT"
    result_title.custom_colors.font_color = won ? Color(0.4, 1, 0.4, 1) : Color(1, 0.4, 0.4, 1)
    score_label.text = "KAI %d - %d OPPONENT" % [get_player_score(), get_opponent_score()]
    reward_label.text = "Coins Earned: %d" % [coins_earned]
    perfect_label.text = "Perfect Spikes: %d" % [perfect_spikes]
    btn_continue.text = return_to_menu ? "Return to Menu" : "Continue"

    # Award coins via ProgressionManager
    if ProgressionManager and coins_earned > 0:
        ProgressionManager.award_match_reward(won, perfect_spikes)

    # If story mode, mark match complete in TournamentManager
    var config: Dictionary = GameManager.get_game_config()
    if config.mode == "story" and won:
        var tid: String = config.tournament_id
        var mi: int = config.match_index
        TournamentManager.mark_match_completed(tid, mi, true)

func get_player_score() -> int:
    return GameManager.score_team_a

func get_opponent_score() -> int:
    return GameManager.score_team_b

func _on_continue_pressed() -> void:
    if return_to_menu:
        get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
    else:
        var config: Dictionary = GameManager.get_game_config()
        if config.mode == "story":
            get_tree().change_scene_to_file("res://scenes/menus/story_mode.tscn")
        elif config.mode == "practice":
            get_tree().change_scene_to_file("res://scenes/menus/practice_mode.tscn")
        else:
            get_tree().change_scene_to_file("res://scenes/menus/quick_match_setup.tscn")

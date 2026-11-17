extends Control
class_name StoryMode

# StoryMode - tournament selection screen.
# Shows all tournaments; clicking "Start" on an unlocked tournament begins match 1.

@onready var tournaments_list: VBoxContainer = $TournamentsContainer/TournamentsList
@onready var card_template: Control = $TournamentCardTemplate
@onready var btn_back: Button = $BackButton

var current_tournament_id: String = ""

func _ready() -> void:
    btn_back.pressed.connect(_on_back_pressed)
    _refresh_tournaments()

    # Listen for tournament unlocks
    if TournamentManager:
        TournamentManager.tournament_unlocked.connect(_on_tournament_unlocked)
        TournamentManager.match_completed.connect(_on_match_completed)

func _refresh_tournaments() -> void:
    # Clear existing cards (except template)
    for child in tournaments_list.get_children():
        if child != card_template:
            child.queue_free()

    if not TournamentManager:
        return

    for tid in TournamentManager.get_tournament_order():
        var t: TournamentData = TournamentManager.get_tournament(tid)
        if not t:
            continue
        _create_tournament_card(t)

func _create_tournament_card(t: TournamentData) -> void:
    var card: Control = card_template.duplicate()
    card.visible = true

    var name_label: Label = $TournamentCardTemplate/CardName.duplicate()
    name_label.text = t.display_name
    card.add_child(name_label)

    var status_label: Label = $TournamentCardTemplate/CardStatus.duplicate()
    var status_text: String = t.is_completed ? "Completed" : (t.is_unlocked ? "Unlocked" : "Locked")
    status_label.text = status_text
    status_label.custom_colors.font_color = t.is_completed ? Color(0.4, 1, 0.4, 1) : (t.is_unlocked ? Color(0.8, 0.9, 1, 1) : Color(1, 0.3, 0.3, 1))
    card.add_child(status_label)

    var matches_label: Label = $TournamentCardTemplate/CardMatches.duplicate()
    matches_label.text = "Matches: %d/%d" % [t.matches_completed, t.total_matches]
    card.add_child(matches_label)

    var start_btn: Button = $TournamentCardTemplate/CardStartButton.duplicate()
    start_btn.text = t.is_completed ? "Completed" : "Start Match %d" % [t.matches_completed + 1]
    start_btn.disabled = not t.is_unlocked or t.is_completed
    start_btn.pressed.connect(func(): _on_start_tournament(t.tournament_id))
    card.add_child(start_btn)

    tournaments_list.add_child(card)

func _on_start_tournament(tournament_id: String) -> void:
    var t: TournamentData = TournamentManager.get_tournament(tournament_id)
    if not t or not t.is_unlocked or t.is_completed:
        return

    current_tournament_id = tournament_id
    var match_index: int = t.matches_completed

    # Save game config for the gameplay scene
    var config: Dictionary = {
        "mode": "story",
        "tournament_id": tournament_id,
        "match_index": match_index,
        "player_character": SaveManager.get_selected_character(),
        "opponent_team": t.get_match_opponent(match_index),
        "difficulty": t.difficulty
    }
    GameManager.set_game_config(config)

    get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")

func _on_tournament_unlocked(tournament_id: String) -> void:
    _refresh_tournaments()

func _on_match_completed(tournament_id: String, match_index: int, won: bool) -> void:
    _refresh_tournaments()

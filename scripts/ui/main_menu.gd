extends Control
class_name MainMenu

# MainMenu - main entry point for BARKADA SPIKE.
# Buttons navigate to Story, Quick Match, Practice, Settings, Exit.

@onready var btn_story: Button = $ButtonContainer/BtnStory
@onready var btn_quick_match: Button = $ButtonContainer/BtnQuickMatch
@onready var btn_practice: Button = $ButtonContainer/BtnPractice
@onready var btn_online: Button = $ButtonContainer/BtnOnline
@onready var btn_settings: Button = $ButtonContainer/BtnSettings
@onready var btn_exit: Button = $ButtonContainer/BtnExit

func _ready() -> void:
    # Ensure save data is loaded
    if SaveManager:
        SaveManager.load()

    btn_story.pressed.connect(_on_story_pressed)
    btn_quick_match.pressed.connect(_on_quick_match_pressed)
    btn_practice.pressed.connect(_on_practice_pressed)
    btn_online.pressed.connect(_on_online_pressed)
    btn_settings.pressed.connect(_on_settings_pressed)
    btn_exit.pressed.connect(_on_exit_pressed)

func _on_story_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/menus/story_mode.tscn")

func _on_quick_match_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/menus/quick_match_setup.tscn")

func _on_practice_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/menus/practice_mode.tscn")

func _on_online_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/menus/online_lobby.tscn")

func _on_settings_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")

func _on_exit_pressed() -> void:
    get_tree().quit()

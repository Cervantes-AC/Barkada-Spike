extends Control
class_name Settings

# Settings - music/SFX volume and save data management.

@onready var music_slider: HSlider = $MusicContainer/MusicSlider
@onready var sfx_slider: HSlider = $SFXContainer/SfxSlider
@onready var btn_back: Button = $BackButton
@onready var btn_reset: Button = $ResetSaveButton

func _ready() -> void:
    if SaveManager:
        music_slider.value = SaveManager.get_setting("music_volume", 0.7)
        sfx_slider.value = SaveManager.get_setting("sfx_volume", 0.8)

    music_slider.value_changed.connect(_on_music_changed)
    sfx_slider.value_changed.connect(_on_sfx_changed)
    btn_back.pressed.connect(_on_back_pressed)
    btn_reset.pressed.connect(_on_reset_pressed)

func _on_music_changed(value: float) -> void:
    if SaveManager:
        SaveManager.set_setting("music_volume", value)
        SaveManager.save()

func _on_sfx_changed(value: float) -> void:
    if SaveManager:
        SaveManager.set_setting("sfx_volume", value)
        SaveManager.save()

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")

func _on_reset_pressed() -> void:
    if SaveManager:
        SaveManager._create_default_save()
        SaveManager.save()
        music_slider.value = SaveManager.get_setting("music_volume", 0.7)
        sfx_slider.value = SaveManager.get_setting("sfx_volume", 0.8)

extends Control
class_name CharacterSelection

# CharacterSelection - view all characters, unlock with coins, select main attacker.

@onready var char_list: ItemList = $CharList
@onready var detail_name: Label = $CharDetails/DetailName
@onready var detail_role: Label = $CharDetails/DetailRole
@onready var detail_ability: Label = $CharDetails/DetailAbility
@onready var detail_stats: Label = $CharDetails/DetailStats
@onready var detail_unlock: Label = $CharDetails/DetailUnlock
@onready var btn_select: Button = $CharDetails/BtnSelect
@onready var btn_unlock: Button = $CharDetails/BtnUnlock
@onready var coins_label: Label = $CoinsLabel

var selected_character_id: String = ""

func _ready() -> void:
    char_list.item_selected.connect(_on_character_selected)
    btn_select.pressed.connect(_on_select_pressed)
    btn_unlock.pressed.connect(_on_unlock_pressed)
    _refresh_list()
    _update_coins()
    if ProgressionManager:
        ProgressionManager.coins_changed.connect(_update_coins)

func _refresh_list() -> void:
    char_list.clear()
    if not CharacterManager:
        return
    for data in CharacterManager.get_all_characters():
        var unlocked: bool = CharacterManager.is_character_unlocked(data.character_id)
        var label: String = data.display_name
        if not unlocked:
            label += " (Locked - %d coins)" % [data.unlock_cost]
        char_list.add_item(label)
        char_list.set_item_metadata(char_list.get_item_count() - 1, data.character_id)
        if not unlocked:
            char_list.set_item_custom_color(char_list.get_item_count() - 1, Color(0.5, 0.5, 0.5, 1))

    # Select first unlocked (Kai)
    for i in range(char_list.get_item_count()):
        if CharacterManager.is_character_unlocked(char_list.get_item_metadata(i)):
            char_list.select(i)
            _on_character_selected(i)
            break

func _on_character_selected(index: int) -> void:
    selected_character_id = char_list.get_item_metadata(index)
    var data: CharacterData = CharacterManager.get_character_data(selected_character_id)
    if not data:
        return

    var unlocked: bool = CharacterManager.is_character_unlocked(selected_character_id)
    detail_name.text = data.display_name
    detail_role.text = "Role: %s" % [data.role]
    detail_ability.text = "%s: %s" % [data.ability_name, data.ability_description]
    detail_stats.text = "Spike: %.1f  Jump: %.1f  Speed: %.1f  Control: %.1f  Defense: %.1f" % [
        data.spike_power, data.jump, data.speed, data.control, data.defense
    ]
    detail_stats.text += "\nLevel: %d  XP: %d/%d" % [
        CharacterManager.get_character_level(selected_character_id),
        CharacterManager.get_character_experience(selected_character_id),
        data.experience_to_next
    ]

    if unlocked:
        detail_unlock.text = "Unlocked"
        detail_unlock.custom_colors.font_color = Color(0.4, 1, 0.4, 1)
        btn_select.disabled = false
        btn_select.text = "Select as Main Attacker"
        btn_unlock.disabled = true
        btn_unlock.text = "Already Unlocked"
    else:
        detail_unlock.text = "Locked - %d coins" % [data.unlock_cost]
        detail_unlock.custom_colors.font_color = Color(1, 0.3, 0.3, 1)
        btn_select.disabled = true
        btn_select.text = "Unlock First"
        btn_unlock.disabled = false
        btn_unlock.text = "Unlock (%d coins)" % [data.unlock_cost]
        if not ProgressionManager.can_afford_character(selected_character_id):
            btn_unlock.disabled = true
            btn_unlock.text = "Not Enough Coins"

func _on_select_pressed() -> void:
    if selected_character_id != "":
        CharacterManager.set_selected_character(selected_character_id)

func _on_unlock_pressed() -> void:
    if selected_character_id == "":
        return
    var data: CharacterData = CharacterManager.get_character_data(selected_character_id)
    if not data or data.unlock_cost <= 0:
        return
    if CharacterManager.unlock_character(selected_character_id, data.unlock_cost):
        _refresh_list()

func _update_coins(_amount: int = -1) -> void:
    if SaveManager:
        coins_label.text = "Coins: %d" % [SaveManager.get_coins()]
        # Re-refresh to update unlock affordability
        _refresh_list()

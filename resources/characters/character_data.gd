extends Resource
class_name CharacterData

# CharacterData - reusable character resource for BARKADA SPIKE.
# Each character is a .tres file; no hardcoding of character configs.

@export var character_id: String = ""
@export var display_name: String = "Character"
@export var role: String = "attacker"   # "attacker", "setter", "defender"
@export var unlocked: bool = false
@export var level: int = 1
@export var experience: int = 0
@export var experience_to_next: int = 100

# Base stats (multipliers applied to gameplay values)
@export var spike_power: float = 1.0
@export var jump: float = 1.0
@export var speed: float = 1.0
@export var control: float = 1.0
@export var stamina: float = 1.0
@export var defense: float = 1.0

# Visual
@export var color: Color = Color(1, 1, 1, 1)

# Ability
@export var ability_name: String = ""
@export var ability_description: String = ""

# Unlock
@export var unlock_cost: int = 0   # 0 = already unlocked / starter

func _init(id: String = "", name: String = "", role: String = "attacker",
           unlocked: bool = false, spike_power: float = 1.0, jump: float = 1.0,
           speed: float = 1.0, control: float = 1.0, stamina: float = 1.0,
           defense: float = 1.0, color: Color = Color(1, 1, 1, 1),
           ability_name: String = "", ability_description: String = "",
           unlock_cost: int = 0) -> void:
    character_id = id
    display_name = name
    self.role = role
    self.unlocked = unlocked
    self.spike_power = spike_power
    self.jump = jump
    self.speed = speed
    self.control = control
    self.stamina = stamina
    self.defense = defense
    self.color = color
    self.ability_name = ability_name
    self.ability_description = ability_description
    self.unlock_cost = unlock_cost

# Add experience and level up if threshold reached. Returns new level if leveled.
func add_experience(amount: int) -> int:
    experience += amount
    var leveled_up: int = 0
    while experience >= experience_to_next and level < 50:
        experience -= experience_to_next
        level += 1
        experience_to_next = int(experience_to_next * 1.5)
        leveled_up += 1
    return leveled_up

func get_stat_multiplier(stat_name: String) -> float:
    match stat_name:
        "spike_power": return spike_power
        "jump": return jump
        "speed": return speed
        "control": return control
        "stamina": return stamina
        "defense": return defense
        _: return 1.0

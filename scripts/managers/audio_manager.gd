extends Node
class_name AudioManager

# AudioManager - manages music and SFX for BARKADA SPIKE.
#
# Provides independent volume control for music and SFX.
# Audio buses "Music" and "SFX" should exist in the project (set in project.godot
# or created in the Godot editor under Project -> Project Settings -> Audio).
#
# All AudioStreamPlayer nodes register here so volume changes apply globally.

# --- Signals -----------------------------------------------------------------

signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

# --- Config ------------------------------------------------------------------

@export var music_bus: String = "Music"
@export var sfx_bus: String = "SFX"

# --- Internal state ----------------------------------------------------------

var music_volume: float = 0.7
var sfx_volume: float = 0.8

# Registered players (weak references stored as objects)
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []

# --- Initialization ----------------------------------------------------------

func _ready() -> void:
    # Load saved volumes
    if SaveManager:
        music_volume = SaveManager.get_setting("music_volume", 0.7)
        sfx_volume = SaveManager.get_setting("sfx_volume", 0.8)
    _apply_music_volume()
    _apply_sfx_volume()

# ---------------------------------------------------------------------------
# Registration (call from AudioStreamPlayer nodes in scenes)
# ---------------------------------------------------------------------------

func register_music_player(player: AudioStreamPlayer) -> void:
    if player and not _music_players.has(player):
        _music_players.append(player)
        player.bus = music_bus
        player.volume_db = _linear_to_db(music_volume)

func register_sfx_player(player: AudioStreamPlayer) -> void:
    if player and not _sfx_players.has(player):
        _sfx_players.append(player)
        player.bus = sfx_bus
        player.volume_db = _linear_to_db(sfx_volume)

func unregister_player(player: AudioStreamPlayer) -> void:
    _music_players.erase(player)
    _sfx_players.erase(player)

# ---------------------------------------------------------------------------
# Volume control
# ---------------------------------------------------------------------------

func set_music_volume(volume: float) -> void:
    music_volume = clamp(volume, 0.0, 1.0)
    _apply_music_volume()
    if SaveManager:
        SaveManager.set_setting("music_volume", music_volume)
        SaveManager.save()
    music_volume_changed.emit(music_volume)

func set_sfx_volume(volume: float) -> void:
    sfx_volume = clamp(volume, 0.0, 1.0)
    _apply_sfx_volume()
    if SaveManager:
        SaveManager.set_setting("sfx_volume", sfx_volume)
        SaveManager.save()
    sfx_volume_changed.emit(sfx_volume)

func get_music_volume() -> float:
    return music_volume

func get_sfx_volume() -> float:
    return sfx_volume

func _apply_music_volume() -> void:
    var db: float = _linear_to_db(music_volume)
    for player in _music_players:
        if player:
            player.volume_db = db

func _apply_sfx_volume() -> void:
    var db: float = _linear_to_db(sfx_volume)
    for player in _sfx_players:
        if player:
            player.volume_db = db

# ---------------------------------------------------------------------------
# SFX playback (one-shot)
# ---------------------------------------------------------------------------

func play_sfx(stream: AudioStream) -> void:
    if not stream:
        return
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.stream = stream
    player.bus = sfx_bus
    player.volume_db = _linear_to_db(sfx_volume)
    player.connect("finished", player, "queue_free")
    get_tree().get_root().add_child(player)
    player.play()

# ---------------------------------------------------------------------------
# Music playback
# ---------------------------------------------------------------------------

func play_music(stream: AudioStream) -> void:
    if not stream:
        return
    # Find an existing music player or create one
    var player: AudioStreamPlayer = null
    for p in _music_players:
        if p and not p.playing:
            player = p
            break
    if not player:
        player = AudioStreamPlayer.new()
        _music_players.append(player)
        get_tree().get_root().add_child(player)
    player.stream = stream
    player.bus = music_bus
    player.volume_db = _linear_to_db(music_volume)
    player.loop = true
    player.play()

func stop_music() -> void:
    for player in _music_players:
        if player:
            player.stop()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Convert linear volume (0-1) to decibels (-80 to ~6)
func _linear_to_db(linear: float) -> float:
    if linear <= 0.0:
        return -80.0
    return AudioServer.linear_to_db(linear)

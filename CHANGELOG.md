# BARKADA SPIKE — Changelog

## [Unreleased] — Milestone 1 (Project Setup)

### Added
- Godot 4.7 project configuration (`project.godot`): landscape 1280x720, canvas_items stretch, mobile renderer, input map (move_left/right, jump, pause, spike, aim_left/aim_right), GameManager autoload.
- `scenes/main/Main.tscn` — root gameplay scene; instances Court, Player, Ball, HUD, MobileControls, MatchManager, VolleyballRules.
- `scenes/match/Court.tscn` — background, green court surface, floor StaticBody2D, net, out-of-bounds Area2Ds.
- `scenes/characters/Kai.tscn` — placeholder main attacker (CharacterBody2D, ColorRect visual, capsule collision, HitZone Area2D) with PlayerController.
- `scenes/match/Ball.tscn` — placeholder ball (RigidBody2D, circle collision, ColorRect visual, Line2D trail) with BallController.
- `scenes/ui/GameplayHUD.tscn` — score, phase, timing feedback label, control hint, pause button.
- `scenes/ui/MobileControls.tscn` — touch buttons: Move Left/Right, Jump, Spike, Aim Left/Right, Pause.
- `scripts/managers/game_manager.gd` — MatchPhase enum (9 phases), team scores, win condition, signals.
- `scripts/player/player_controller.gd` — left/right movement, jumping, gravity, landing detection, facing/flip, spike with timing grades (PERFECT/GREAT/GOOD/LATE/MISS), attack direction, mobile input API (set_mobile_move, set_mobile_aim, mobile_jump, mobile_spike).
- `scripts/ball/ball_controller.gd` — manual gravity, velocity, rotation, floor/net/boundary collisions, trail, serve/set_velocity/hold/release/stop/reset API, ball_hit_floor and ball_out_of_bounds signals.
- `scripts/match/match_manager.gd` — rally flow, serving team, touch counts, phases, end_rally, start_match, on_serve.
- `scripts/match/volleyball_rules.gd` — pure rules logic: 3-touch limit, net faults, out-of-bounds, match-completion check.
- `scripts/ui/gameplay_hud.gd` — HUD display API including show_timing().
- `scripts/ui/mobile_controls.gd` — touch control signal emitter.
- `scripts/main/main.gd` — scene wiring: GameManager→HUD, MatchManager→GameManager, Player→HUD/MatchManager, Ball→MatchManager, MobileControls→Player, pause toggle.
- Docs: README.md, ARCHITECTURE.md, DEVELOPMENT_ROADMAP.md, GDD.md, CHANGELOG.md, TEST_PLAN.md.

### Notes
- Online multiplayer, progression, tournaments, and AI are NOT in M1/M2 (see roadmap).
- Placeholder art only; replace with anime assets in M8.

## [Unreleased] — Milestone 2 (Mobile Touch Controls)

### Added
- `scenes/ui/MobileControls.tscn` — touch button CanvasLayer (Move Left/Right, Jump, Spike, Aim Left/Right, Pause).
- `scripts/ui/mobile_controls.gd` — emits move_direction_changed, jump_pressed, spike_pressed, aim_direction_changed, pause_pressed signals.
- `scripts/player/player_controller.gd` — mobile input integration: set_mobile_move, set_mobile_aim, mobile_jump, mobile_spike; keyboard + mobile input combined in _physics_process.
- `scripts/main/main.gd` — wires MobileControls signals to PlayerController; pause toggle via get_tree().paused.
- `scenes/main/Main.tscn` — instances MobileControls node.
- `project.godot` — added input actions: spike (S), aim_left (Q), aim_right (E).

## [Unreleased] — Milestone 3 (Ball Physics)

### Added
- `scenes/match/Ball.tscn` — placeholder ball scene (RigidBody2D, circle collision, ColorRect visual, Line2D trail).
- `scripts/ball/ball_controller.gd` — BallController with manual gravity, velocity, rotation, floor/net/boundary collisions, trail, serve/set_velocity/hold/release/stop/reset API.
- `scenes/match/Court.tscn` — updated with Net StaticBody2D and out-of-bounds Area2D detectors.
- `scenes/main/Main.tscn` — instances Ball node.

## [Unreleased] — Milestone 4 (Attack Mechanics)

### Added
- `scripts/match/volleyball_rules.gd` — pure rules logic: 3-touch limit, net faults, out-of-bounds, match-completion check.
- `scripts/match/match_manager.gd` — rally flow, serving team, touch counts, phases, end_rally, start_match, on_serve.
- `scenes/characters/Kai.tscn` — added HitZone Area2D for ball contact detection.
- `scripts/player/player_controller.gd` — spike input (S), aim input (Q/E), ball contact via HitZone, timing-grade calculation (PERFECT/GREAT/GOOD/LATE/MISS), attack direction, spike_completed signal.
- `scripts/ball/ball_controller.gd` — added ball_hit_floor(side) and ball_out_of_bounds(side) signals; court_center_x export.
- `scripts/ui/gameplay_hud.gd` — added show_timing(grade, power) for timing feedback.
- `scenes/ui/GameplayHUD.tscn` — added TimingLabel (center screen, auto-hides).
- `scripts/main/main.gd` — full signal wiring across all systems; auto-serve after points.
- `scenes/main/Main.tscn` — instances MatchManager and VolleyballRules nodes.
- `project.godot` — added input actions: spike (S), aim_left (Q), aim_right (E).

## [Unreleased] — Milestone 5 (Automatic Teammates)

### Added
- `scripts/ai/ball_predictor.gd` — ball landing prediction utility.
- `scripts/ai/ai_character.gd` — base AI character with state machine (idle, move, receive, set, block, recover).
- `scenes/characters/Setter.tscn` — placeholder setter character (green).
- `scenes/characters/Defender.tscn` — placeholder defender character (orange).
- `scripts/ai/team_ai_controller.gd` — coordinates setter + defender AI based on ball state.

## [Unreleased] — Milestone 6 (Complete Match)

### Added
- `scripts/ai/opponent_ai_controller.gd` — opponent team AI: serve, receive, set, attack, block, difficulty.
- `scenes/characters/Opponent.tscn` — opponent main attacker (red).
- `scenes/characters/OpponentSetter.tscn` — opponent setter (red).
- `scenes/characters/OpponentDefender.tscn` — opponent defender (red).
- `scripts/ball/ball_controller.gd` — added ball_hit(team) signal.
- `scripts/main/main.gd` — opponent AI wiring, serve alternation, match result routing.

## [Unreleased] — Milestone 7 (Offline Game)

### Added
- `resources/characters/character_data.gd` — reusable CharacterData resource class
- `resources/characters/{kai,ren,jiro,mika,dax,yuna}.tres` — character data files (Kai unlocked at start)
- `resources/tournaments/tournament_data.gd` — reusable TournamentData resource class
- `resources/tournaments/{rookie_tournament,school_league,regional_cup,national_championship,grand_finals}_tournament.tres` — 5 tournaments x 3 matches
- `scripts/managers/save_manager.gd` — JSON save/load in user://, validation, backup, version migration
- `scripts/managers/character_manager.gd` — character selection, unlocks, levels, XP
- `scripts/managers/tournament_manager.gd` — 5 tournaments x 3 matches, sequential unlocking
- `scripts/managers/progression_manager.gd` — coins, rewards (win 50, lose 15, tournament 150, perfect spike 25)
- `scripts/ui/main_menu.gd` + `scenes/menus/MainMenu.tscn` — main menu entry point
- `scripts/ui/story_mode.gd` + `scenes/menus/story_mode.tscn` — tournament selection
- `scripts/ui/quick_match_setup.gd` + `scenes/menus/quick_match_setup.tscn` — quick match setup
- `scripts/ui/practice_mode.gd` + `scenes/menus/practice_mode.tscn` — practice mode
- `scripts/ui/character_selection.gd` + `scenes/menus/character_selection.tscn` — character select/unlock
- `scripts/ui/settings.gd` + `scenes/menus/settings.tscn` — volume settings, save reset
- `scripts/ui/match_result.gd` + `scenes/results/match_result.tscn` — match outcome screen
- `scripts/main/main.gd` — reads game_config, configures player/opponent, routes to MatchResult
- `scripts/ball/ball_controller.gd` — added ball_hit(team) signal
- `scripts/ai/team_ai_controller.gd` — fixed node paths (get_node("../Node"))
- `scripts/ai/opponent_ai_controller.gd` — fixed node paths (get_node("../Node"))
- `project.godot` — main scene changed to MainMenu, registered SaveManager/CharacterManager/TournamentManager/ProgressionManager autoloads, added game_config to GameManager

### Notes
- Kai available at start; other characters unlockable with coins
- Tournaments unlock sequentially after completion
- Save after matches, unlocks, settings changes
- Online multiplayer still NOT implemented (Milestone 9)

## [Unreleased] — Milestone 8 (UI and Presentation)

### Added
- `scripts/managers/audio_manager.gd` — AudioManager singleton with independent music/SFX volume, one-shot SFX playback, music looping
- `scripts/ui/character_animation_controller.gd` — CharacterAnimator using Tween for idle/run/jump/spike/land/receive/set/block animations
- `scenes/animations/{idle,run,jump,spike,land,receive,set,block}_animation.tscn` — AnimationPlayer scenes for each character action
- `scenes/effects/spike_impact_particles.tscn` — CPUParticles2D spike impact effect
- `scenes/effects/perfect_flash.tscn` — Full-screen white flash for PERFECT timing
- `scripts/ai/ai_character.gd` — Base AI character class with animator integration (updated)
- `scenes/characters/{Setter,Defender,Opponent,OpponentSetter,OpponentDefender}.tscn` — All AI character scenes
- `scripts/main/main.gd` — Animator setup for all characters, perfect flash effect, audio integration (ball_hit, perfect_spike), touch count display
- `scripts/ui/gameplay_hud.gd` — Added touch count display, improved timing colors
- `scenes/ui/GameplayHUD.tscn` — Touch count label, improved timing label styling
- `project.godot` — Added AudioManager autoload, Music/SFX audio buses

### Notes
- Placeholder audio streams (WAV files) need to be added to assets/audio/sfx/ and assets/audio/music/
- Replace ColorRect visuals with animated sprites in Milestone 10 polish
- Online multiplayer still NOT implemented (Milestone 9)

## [Unreleased] — Milestone 9 (Online Multiplayer)

### Added
- `scripts/network/network_manager.gd` — NetworkManager singleton with host-authoritative multiplayer using Godot 4.7 ENetMultiplayerPeer
- `scenes/menus/online_lobby.tscn` — Host/join lobby UI with IP address, port, connection status
- `scripts/ui/online_lobby.gd` — Lobby logic: host game, join game, disconnect, network state signals
- `scripts/player/player_controller.gd` — Remote input support: is_remote flag, set_remote_move/set_remote_aim/remote_jump/remote_spike API
- `scripts/main/main.gd` — Online mode detection, host/client player assignment, state sync timer (20Hz), remote input handling
- `scenes/menus/MainMenu.tscn` — Added "Online 1v1" button
- `scripts/ui/main_menu.gd` — Online button handler
- `project.godot` — Registered NetworkManager autoload

### Network Architecture (Host-Authoritative)
- Host runs full physics, AI for all teammates, scoring, match state
- Clients send input (move, jump, spike, aim) to host via RPC
- Host syncs ball state, player positions, scores, phases to clients (~20Hz)
- RPCs: rpc_player_input (client→host), rpc_sync_ball_state / rpc_sync_player_state / rpc_sync_score / rpc_sync_phase / rpc_match_ended (host→clients)

### Notes
- ENet works on LAN / same Wi-Fi by default
- For internet play: port forward UDP port 7000 (or use relay/NAT traversal)
- Placeholder audio streams (WAV files) in assets/audio/sfx/ and assets/audio/music/
- Online match always returns to lobby after match ends

## [Unreleased] — Milestone 10 (Finalization)

### Added
- `README.md` — comprehensive GitHub-ready project documentation
- Android export configuration guide (export templates, SDK paths, APK build)
- Performance targets documented (60 FPS, <50ms input response, <50MB APK)
- GitHub repository setup instructions (git init, remote, push)
- All documentation files finalized and consistent

### Notes
- All 10 milestones complete
- Game is playable end-to-end: Main Menu → Story/Quick/Practice/Online → Match → Result
- Replace ColorRect placeholders with anime sprites for production
- Add real audio WAV files to assets/audio/ for production sound
- Test on real Android devices before release


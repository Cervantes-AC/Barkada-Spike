# BARKADA SPIKE — Architecture

Godot 4.7 + GDScript. Modular, signal-driven, scene-based. All 10 milestones complete.

## Systems (autoloads)

| System | File | Responsibility |
|---|---|---|
| GameManager | scripts/managers/game_manager.gd | Match phase (9 phases), scoring, win condition, game_config. Emits signals. |
| MatchManager | scripts/managers/match_manager.gd | Rally flow, touch counts, serve rotation, phase transitions, match end. |
| PlayerController | scripts/player/player_controller.gd | Human main attacker: move, jump, land, spike, timing grades, aim. Supports local + remote (online) input. |
| TeamAIController | scripts/ai/team_ai_controller.gd | Player's team AI: setter + defender (ball tracking, prediction, receiving, setting, blocking). |
| OpponentAIController | scripts/ai/opponent_ai_controller.gd | Opponent team AI: setter, defender, attacker (serve, receive, set, spike, block, difficulty). |
| BallController | scripts/ball/ball_controller.gd | Ball gravity, velocity, rotation, floor/net/boundary collision, trail, serve/hit API. |
| VolleyballRules | scripts/match/volleyball_rules.gd | Pure rules: 3-touch limit, net faults, out-of-bounds, match-completion check. |
| CharacterManager | scripts/managers/character_manager.gd | Character data, selection, unlocks (coins), levels, XP, stat multipliers. |
| TournamentManager | scripts/managers/tournament_manager.gd | 5 tournaments x 3 matches, sequential unlocking, match completion. |
| ProgressionManager | scripts/managers/progression_manager.gd | Coins economy, match/tournament rewards, perfect spike bonus. |
| SaveManager | scripts/managers/save_manager.gd | JSON save/load in user://, validation, backup, version migration. |
| AudioManager | scripts/managers/audio_manager.gd | SFX + music, independent volume, one-shot playback, music looping. |
| NetworkManager | scripts/network/network_manager.gd | Host/join (ENet), input/ball/score/phase sync, disconnect handling. |

## Scene-based UI (no single UIManager)

Each screen is its own Control scene with its own script:

| Scene | Script | Purpose |
|---|---|---|
| scenes/menus/MainMenu.tscn | scripts/ui/main_menu.gd | Entry point: Story, Quick Match, Practice, Online, Settings, Exit |
| scenes/menus/story_mode.tscn | scripts/ui/story_mode.gd | Tournament selection, match start |
| scenes/menus/quick_match_setup.tscn | scripts/ui/quick_match_setup.gd | Character, difficulty, opponent selection |
| scenes/menus/practice_mode.tscn | scripts/ui/practice_mode.gd | Practice without full match |
| scenes/menus/character_selection.tscn | scripts/ui/character_selection.gd | View/unlock/select characters |
| scenes/menus/settings.tscn | scripts/ui/settings.gd | Music/SFX volume, save reset |
| scenes/menus/online_lobby.tscn | scripts/ui/online_lobby.gd | Host/join LAN match |
| scenes/ui/GameplayHUD.tscn | scripts/ui/gameplay_hud.gd | Score, phase, timing feedback, touch count |
| scenes/ui/MobileControls.tscn | scripts/ui/mobile_controls.gd | Touch buttons: move, jump, spike, aim, pause |
| scenes/results/match_result.tscn | scripts/ui/match_result.gd | Victory/defeat, coins earned |

## Animation & Effects

| Scene | Purpose |
|---|---|
| scenes/animations/*.tscn | 8 character animations (idle, run, jump, spike, land, receive, set, block) |
| scenes/effects/spike_impact_particles.tscn | CPUParticles2D spike impact |
| scenes/effects/perfect_flash.tscn | Full-screen flash for PERFECT timing |
| scripts/ui/character_animation_controller.gd | Tween-based character animator |

## Network Architecture (Host-Authoritative)

- Host runs full physics, AI for all teammates, scoring, match state
- Clients send input (move, jump, spike, aim) to host via RPC
- Host syncs ball state, player positions, scores, phases to clients (~20Hz)
- RPCs: rpc_player_input (client→host), rpc_sync_ball_state / rpc_sync_player_state / rpc_sync_score / rpc_sync_phase / rpc_match_ended (host→clients)
- ENet works on LAN/same Wi-Fi; internet requires UDP port 7000 port forwarding

## Key Rules

- **No god-script.** Each script has one responsibility.
- **Resources for data.** Characters, tournaments are `.tres` Resource files, not hardcoded.
- **Signals for communication.** Independent systems never reference each other directly.
- **Typed GDScript** where practical.
- **Autoloads only when genuinely necessary** (GameManager, SaveManager, CharacterManager, TournamentManager, ProgressionManager, AudioManager, NetworkManager).
- **Modular scenes.** Each screen and gameplay element is a separate `.tscn`.

## Input Map (project.godot)

- move_left = A | move_right = D | jump = SPACE | pause = ESCAPE
- spike = S | aim_left = Q | aim_right = E

## Milestones (all 10 complete)

| Milestone | Focus | Status |
|---|---|---|
| M1 | Project Setup | ✅ |
| M2 | Main Attacker + Mobile Controls | ✅ |
| M3 | Ball Physics | ✅ |
| M4 | Attack Mechanics | ✅ |
| M5 | Automatic Teammates | ✅ |
| M6 | Complete Match | ✅ |
| M7 | Offline Game | ✅ |
| M8 | UI and Presentation | ✅ |
| M9 | Online Multiplayer | ✅ |
| M10 | Finalization | ✅ |

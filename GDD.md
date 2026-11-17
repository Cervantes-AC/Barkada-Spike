# BARKADA SPIKE — Game Design Document (condensed)

## Title
BARKADA SPIKE — 2D anime-inspired volleyball mobile game.

## Genre / Platform
Volleyball sports arcade. Android first (landscape). Godot 4.7, GDScript.

## Core loop
Player controls ONE main attacker (move, jump, spike, timing). Two teammates (setter, defender)
are AI-controlled. Opponents are AI in offline mode. Win rallies by landing the ball on the
opponent's floor or forcing an error. First to 15 (win by 2, max 21).

## Characters (original)
Kai (Rising Ace, main attacker), Ren (Playmaker, setter), Jiro (The Wall, defender),
Mika (Quick Ace), Dax (Powerhouse), Yuna (The Strategist). Kai unlocked at start.
Stats: spike power, jump, speed, control, stamina, defense.

## Modes
Story (5 tournaments x 3 matches, sequential), Quick Match, Practice, Online 1v1 (later).

## Controls
A/D or joystick to move, SPACE/jump button to jump, spike button, attack direction.
Input Map used (no hardcoded keys in gameplay code).

## Economy (configurable)
Win 50, lose 15, tournament completion 150, perfect-spike challenge 25. Barkada Coins.
No gacha, no real-money purchases.

## Save
JSON in user://. Profile, coins, unlocks, levels, XP, progression, stats, settings.
Backup + version migration.

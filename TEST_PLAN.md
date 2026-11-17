# BARKADA SPIKE — Test Plan

## Milestone 1 — playable prototype tests

### Player movement
- [ ] Pressing A moves the character left; releasing stops it.
- [ ] Pressing D moves the character right; releasing stops it.
- [ ] Pressing A + D together cancels (no movement).
- [ ] Character cannot move through the floor.

### Jumping
- [ ] SPACE makes the character jump only when on the floor.
- [ ] SPACE in mid-air does nothing (no double jump yet).
- [ ] Character rises, reaches apex, falls back to the floor under gravity.
- [ ] Landing is detected (one-frame `just_landed`).

### Ball collision (deferred to M3)
- [ ] Ball bounces off floor.
- [ ] Ball collides with net.
- [ ] Ball collides with player.

### Ball trajectory (deferred to M3)
- [ ] Ball arcs under gravity.
- [ ] Ball rotation updates while moving.

### Scoring / match completion (deferred to M6)
- [ ] Ball landing on opponent side awards point.
- [ ] Out-of-bounds awards point to opposing team.
- [ ] First to 15, win by 2, max 21.

### Tournament progression / character unlocks / save/load (deferred to M7)
- [ ] Match victory = 50 coins, defeat = 15 coins.
- [ ] Save after match; load on start; validate; handle missing/corrupt saves.

### Offline gameplay (deferred to M7)
- [ ] Full rally: serve → receive → set → attack → defend → point.
- [ ] AI teammates (setter/defender) act automatically.
- [ ] Opponent AI receives/sets/attacks/blocks.

### Online connections (deferred to M9)
- [ ] Host / join match.
- [ ] Input, ball, score, phase synchronization.
- [ ] Disconnect handling.

### Android performance (Milestone 10)
- [ ] Test on real Android device; target 60 FPS sustained
- [ ] Verify touch controls respond correctly (< 50ms input-to-action)
- [ ] Verify APK installs and launches without crashes
- [ ] Verify online LAN play works over Wi-Fi on device
- [ ] Check battery drain during extended play sessions
- [ ] Check memory usage stays under 200 MB

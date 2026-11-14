# City Life India

3D open-world driving / adventure / simulation game for Android, set in a fictional Indian city.
Built with **Godot 4.4 (GDScript)**, Mobile renderer, landscape, offline single-player first.

**Status: Phase 1 - Foundation** (v0.1.0). See `docs/ROADMAP.md`.

## What works in Phase 1
- Project architecture + autoload managers (`SaveManager`, `AuthManager`, `Game`)
- Login screen: Continue as Guest (real), Email login / Create account (**DEV MODE, local to the device**),
  Google sign-in and password reset (shown honestly as unavailable until Firebase, Phase 5)
- Main menu: Play (new game), Continue, Profile, Settings (graphics quality, sensitivities, privacy, logout), Exit.
  Garage / Missions / Store are shown disabled with the phase that adds them.
- Playable city: 5x5 block grid (park in the centre, tall "modern" ring, low shop ring with signboards),
  roads with dashed lines, boundaries, day/night cycle, fog, shadows
- Third-person player: walk / run / jump, collision-aware camera, multi-touch controls
  (left stick, right-side camera drag, JUMP, RUN, pause) + WASD/Space/Shift on desktop
- Pause menu (Resume, Settings, Save & Exit); Android Back / Esc toggles pause
- Crash-safe versioned local saves with automatic recovery, autosave every 20-30 s
- Graphics presets Low / Medium / High / Ultra (Ultra only on capable devices)

All 3D art is **placeholder** (boxes, capsules). Real Blender assets arrive in later phases.

## Run it
1. Install Godot 4.4+ (standard build, not .NET): https://godotengine.org/download
2. Open Godot -> Import -> select `project.godot` -> Run (F5).
   On desktop the mouse emulates touch: drag the on-screen stick or use WASD; drag the right side to look.
3. Headless tests: `godot --headless --path . -s tests/smoke_test.gd` (exits non-zero on failure).

## Build for Android (needed before Phase 6 testing)
1. Install JDK 17 and Android SDK (platform-tools, build-tools 34, platform 34, cmdline-tools, NDK r23c).
2. Godot: Editor Settings -> Export -> Android -> set SDK path and debug keystore.
3. Project -> Install Android Build Template, then Project -> Export -> Add "Android". Set a unique package name
   (e.g. `com.yourname.citylifeindia`), orientation landscape, ARM64 enabled.
4. Plug in a phone with USB debugging and use the one-click deploy button.
Never commit keystores or `export_presets.cfg` (already in `.gitignore`).

## Folder structure
```
autoload/   save_manager.gd  auth_manager.gd  game.gd      (global singletons)
scenes/     boot / login / menu / world (city) / player
ui/         ui_theme  overlay  settings_panel  pause_menu  hud
tests/      smoke_test.gd
docs/       ROADMAP.md  ASSET_CREDITS.md
```
Later phases add: `vehicles/`, `traffic/`, `npc/`, `missions/`, `economy/`, `audio/`, `assets/`.

## Security notes
- No secrets in the repo. Firebase config (`google-services.json`) and signing keys are git-ignored.
- Local saves are checksummed for corruption only; local files can be edited by the player. Cloud accounts
  will keep currency/purchases server-authoritative with Firebase security rules (Phase 5).
- Dev-mode passwords are salted + iterated SHA-256, never plaintext. Production auth is Firebase.

## License
To be chosen by the project owner before publishing (code). Asset licences are tracked in `docs/ASSET_CREDITS.md`.

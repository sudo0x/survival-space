# Survival Space

A Godot 4.7 2D pixel-art action platformer focused on one arena and an endless, editable terrain route.

## Start the game

Open this folder in Godot and press **F5** to run the project. It starts at `scense/main_menu.tscn`; `scense/game.tscn` is the playable run scene and can be run directly with **F6**.

## Project map

- `scense/` — playable arena, player, enemies, pickups, menus, effects, and reusable terrain chunks.
- `scripts/` — gameplay, enemy behavior, player abilities, upgrade choices, UI, and terrain generation.
- `scripts/game_events.gd` — typed global gameplay notifications. Scenes emit events here instead of depending on the Game node's method names.
- `scripts/swarm_director.gd` — survival-wave timing, spawn limits, and off-screen enemy entry. Tune its exports on the `SwarmDirector` node in `scense/game.tscn`.
- `assests/` — sprites, tileset, fonts, music, sound effects, shaders, and touch-button art. These folder names are already used by Godot resource paths; keep them as written.
- `ANIMATION_LEARNING_GUIDE.md` — where to find and edit animations in the Godot editor.
- `TERRAIN_CHUNKS_GUIDE.md` — how to edit and tune the generated terrain.
- `scense/upgrade_panel.tscn` — the level-up choice screen; the run pauses until one perk is selected.
- `android/` — existing Android build output; Godot regenerates these files when exporting.

## Gameplay code ownership

- `game.gd` owns run state, HUD updates, progression, and coordination between systems.
- `player.gd` owns player movement and combat input; reusable ability behavior is split into child nodes and focused scripts.
- Enemy and pickup scenes own their behavior and emit `GameEvents` notifications for run-level rewards and counters.
- `SwarmDirector` owns enemy-wave scheduling and spawning. It resets at the start of each run and stops when the Guardian encounter begins.

The normal run lasts eight minutes before the Guardian encounter. Adjust `run_duration_seconds` on the Game node in `scense/game.tscn` when tuning the run length.

## Editing terrain

Open `scense/space_arena.tscn` to edit the starting area. For generated terrain, open a `scense/terrain_chunk_*.tscn` scene and edit its `Tiles` layer or `surface_profile` in the Inspector. The generator settings are on `SpaceArena/TerrainGenerator` in `scense/game.tscn`'s instantiated arena.

## Keep the project tidy

`.godot/` is a generated editor/import cache and is ignored by Git. `android/` contains generated build output and is also ignored. Don’t delete the `.import` sidecars for assets that remain in `assests/`; Godot uses them to manage imported resources.

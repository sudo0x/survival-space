# Learning the Godot editor

You can inspect and edit the main sprite and visual animations in the Godot editor. Game rules such as enemy movement, attacks, collision, and dash timing stay in GDScript because they respond to what happens during play.

## Player sprite animations

1. In the FileSystem dock, open `scense/player.tscn`.
2. Select `AnimatedSprite2D` in the Scene tree.
3. In the Inspector, click the `SpriteFrames` resource to open the SpriteFrames editor at the bottom.
4. Select `idle`, `run`, `jump`, `double_jump`, or `attack` in the animation list. The frames and playback speed are editable there.
5. Select `AnimationPlayer` in the Scene tree to edit the separate `takeoff`, `double_jump_pop`, `landing_squash`, and `hit_flash` effects in the bottom Animation panel.

## Enemy animations and hit effects

1. Open `scense/slime.tscn` or `scense/guardian.tscn`.
2. Select `AnimatedSprite2D` to inspect the SpriteFrames animation assigned to that enemy.
3. Select `AnimationPlayer` to edit the `hit_flash` effect (and the guardian's `fade_out`).
4. Enemy movement and decision-making are in `scripts/slime.gd` and `scripts/guardian.gd`; sprite playback and hit/fade visuals are configured in the scenes.

Enemy sprite sheets are collected in `assests/sprites/enemy_sprite_frames.tres`. The Rift Guardian has its own pixel sheet at `assests/sprites/rift_guardian_sheet.png` and editable `idle`, `glide`, and `attack` SpriteFrames in `assests/sprites/rift_guardian_frames.tres`. Pickups use `assests/sprites/pickup_sprite_frames.tres`.

## Editing the arena and generated terrain

The project currently focuses on one playable arena. Open `scense/space_arena.tscn` and select `Ground` to paint its hand-built opening with the TileMapLayer tools. Decorations and spawn markers are children of the arena, so you can move them in the 2D view.

After the opening, `TerrainGenerator` adds editable terrain chunks. See `TERRAIN_CHUNKS_GUIDE.md` for how to adjust those scenes and their generation settings. The old multi-island selector and island scenes were removed while the game focuses on this single arena.

## Pickups, projectiles, and scenery

- Open `scense/pickup.tscn`; `AnimatedSprite2D` shows the coin/fruit frames and `AnimationPlayer` edits the `float` animation.
- Open `scense/relic.tscn`; its `AnimatedSprite2D` reuses your coin frames with a cyan/gold tint, and `AnimationPlayer` edits the looping `shimmer`. The arena relic is placed in `scripts/game.gd`.
- Open `scense/enemy_projectile.tscn`; `AnimatedSprite2D` selects the wisp frames and `AnimationPlayer` edits the `spin` loop.
- Open `scense/magic_bolt.tscn` to inspect the knight's original arcane projectile. It uses `assests/sprites/arcane_bolt.png` (separate from enemy sprites); select its `AnimationPlayer` and edit `arcane_orbit` in Godot's Animation panel to adjust the spell's spin and pulse. `scripts/magic_bolt.gd` moves the bolt and applies damage on collision. In `scense/player.tscn`, select `MagicAbility` to edit the spell cooldown, ward duration, speed, and launch offset in the Inspector; the ability behavior is in `scripts/player_magic.gd`. Press **L** or tap **MAGIC**.
- Open `scense/ambient_prop.tscn`; its `AnimationPlayer` contains `tree_sway` and `plant_sway`.
- Open `scense/distant_backdrop.tscn`; its `AnimationPlayer` contains the slow `drift` loop.
- Open `scense/game.tscn`, select `HUD/ComboLabel/ComboAnimationPlayer`, and edit `combo_pop` to change the stomp-combo popup.

## Editing an animation safely

Select the `AnimationPlayer` node first. In the bottom Animation panel, choose an animation, move the playhead, and edit its keyed properties in the Inspector or add keys with the key button. Press Play in that panel to preview. Keep the animated node names the same unless you also update the animation track paths.

The same SpriteFrames and AnimationPlayer editors are used for animation throughout Godot; scripts call the named animations when gameplay triggers them.

## Mobile controls and HUD

Open `scense/touch_controls.tscn` to edit the mobile controls in the 2D editor. The move joystick sits at the lower left. Dash, Magic, Hit, and Jump sit at the lower right; Anchor and Pause are above them. There is no in-game Hero button. Each action button uses the dark stone PNG plate with editable text drawn by the Godot Button node. Select a button in the Scene tree to change its text, font, color, or size in the Inspector. `scripts/touch_controls.gd` forwards touch input to the same actions used by keyboard and mouse. Mouse-to-touch emulation is enabled in Project Settings for desktop click testing. The project uses a landscape 1152×648 reference size and lays the controls out again when the viewport changes.

## Inventory

There is currently no in-run inventory shortcut or Hero button. Character color styles are selected from the Armory in the main menu. The recolor shader changes the tunic and plume while keeping the knight spritesheets and animations. Run rewards and the selected style are stored in the local player profile by `scripts/game.gd`.

## Run waves, upgrades, and the final encounter

`scense/game.tscn` contains the `HUD/UpgradePanel` and `HUD/BossHealth` interfaces. Open `scense/upgrade_panel.tscn` to edit the three level-up choice buttons. Their effects are applied in `scripts/game.gd` in `_on_upgrade_selected()`. The survival duration is the `run_duration_seconds` setting on the Game node; when it ends, the Rift Guardian appears and the run is won when its health reaches zero. The guardian scene and its behavior stay editable in `scense/guardian.tscn` and `scripts/guardian.gd`.

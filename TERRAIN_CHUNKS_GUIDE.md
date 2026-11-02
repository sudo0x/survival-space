# Terrain chunks

The original opening area remains hand-painted in `scense/space_arena.tscn` on its `Ground` TileMapLayer. The endless section is made from small, reusable scenes that use the same world tileset.

## Chunk scenes

Open these files from the FileSystem dock to see and edit their preview in the 2D view:

- `scense/terrain_chunk_flat.tscn` — a calm, flat section.
- `scense/terrain_chunk_rise.tscn` — gentle steps upward and back down.
- `scense/terrain_chunk_drop.tscn` — a shallow dip and rise.
- `scense/terrain_chunk_bridge.tscn` — a tiny two-tile jump gap with a safe landing.
- `scense/terrain_chunk_rolling.tscn` — small rolling steps.

Each scene inherits `terrain_chunk_base.tscn`. Its `Tiles` child uses the normal TileMapLayer editor and the project tileset. The `surface_profile` property on the root describes the top of the ground from left to right: `0` is level, `-1` is one tile higher, `1` is one tile lower, and `99` leaves that column empty. The tool script previews those values as real tiles in the 2D editor. Change the profile in the Inspector or paint the `Tiles` layer directly; the generator uses the scene's resulting tiles.

## Runtime behavior

`TerrainGenerator` starts after the hand-built arena ends, adds four chunks as a buffer, and builds more when the player approaches. It randomizes the order, avoids placing two bridge gaps back-to-back, and shifts the terrain palette every four chunks. New terrain is painted into the arena's existing `Ground` TileMapLayer so its collision and ground checks continue to work.

The generator settings are on `SpaceArena/TerrainGenerator` in the Inspector: `initial_chunks`, `generation_ahead_pixels`, `max_generated_chunks`, and `random_seed`. Leave `random_seed` at `0` for a different layout each run; set a nonzero seed to reproduce a layout while tuning it.

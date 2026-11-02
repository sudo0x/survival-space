@tool
extends Node2D
## A small, editor-previewable piece of tile terrain used by the endless arena.

const TILE_SOURCE_ID := 0
const GAP_COLUMN := 99

@export var surface_profile: PackedInt32Array = PackedInt32Array([
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
]):
	set(value):
		surface_profile = value
		_rebuild_tiles()

@export_range(0, 8, 1) var surface_atlas_x := 0:
	set(value):
		surface_atlas_x = value
		_rebuild_tiles()

@export_range(2, 5, 1) var ground_depth := 3:
	set(value):
		ground_depth = value
		_rebuild_tiles()

func _ready() -> void:
	var tiles := get_node_or_null("Tiles") as TileMapLayer
	if tiles != null and tiles.get_used_cells().is_empty():
		_rebuild_tiles()

func _rebuild_tiles() -> void:
	if not is_inside_tree():
		return
	var tiles := get_node_or_null("Tiles") as TileMapLayer
	if tiles == null or tiles.tile_set == null:
		return
	tiles.clear()
	for column in range(surface_profile.size()):
		var surface_offset := surface_profile[column]
		if surface_offset == GAP_COLUMN:
			continue
		tiles.set_cell(Vector2i(column, surface_offset), TILE_SOURCE_ID, Vector2i(surface_atlas_x, 0))
		for depth in range(1, ground_depth):
			var atlas_y := mini(depth, 2)
			tiles.set_cell(Vector2i(column, surface_offset + depth), TILE_SOURCE_ID, Vector2i(surface_atlas_x, atlas_y))

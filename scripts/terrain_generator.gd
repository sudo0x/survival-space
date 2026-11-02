extends Node2D
## Selects hand-authored terrain chunks and paints them into the arena TileMapLayer.

const TILE_SIZE := Vector2i(16, 16)
const PALETTE_ATLAS_COLUMNS: Array[int] = [0, 6, 8, 5]
const CHUNK_SCENES: Array[PackedScene] = [
	preload("res://scense/terrain_chunk_flat.tscn"),
	preload("res://scense/terrain_chunk_rise.tscn"),
	preload("res://scense/terrain_chunk_drop.tscn"),
	preload("res://scense/terrain_chunk_bridge.tscn"),
	preload("res://scense/terrain_chunk_rolling.tscn"),
]

@export_group("Generation")
@export_range(0, 12, 1) var initial_chunks := 4
@export_range(256.0, 2400.0, 64.0) var generation_ahead_pixels := 1200.0
@export_range(32, 1024, 32) var max_generated_chunks := 512
@export var random_seed := 0

var _random := RandomNumberGenerator.new()
var _ground: TileMapLayer
var _player: Node2D
var _next_cell_x := 0
var _base_surface_y := 0
var _chunks_generated := 0
var _last_chunk_was_bridge := false
var _is_generating := false

func begin(player: Node2D) -> void:
	if _is_generating or not is_instance_valid(player):
		return
	_ground = get_parent().get_node_or_null("Ground") as TileMapLayer
	if _ground == null:
		push_warning("Terrain generator needs the SpaceArena/Ground TileMapLayer.")
		return
	_player = player
	if random_seed == 0:
		_random.randomize()
	else:
		_random.seed = random_seed
	var edge_surface := _find_right_edge_surface()
	if edge_surface.x < 0:
		push_warning("Terrain generator could not find a supported terrain surface at the arena edge.")
		return
	_next_cell_x = edge_surface.x + 1
	_base_surface_y = edge_surface.y
	_is_generating = true
	for index in range(initial_chunks):
		_append_chunk()

func _process(_delta: float) -> void:
	if not _is_generating or not is_instance_valid(_player):
		return
	var player_local_x := _ground.to_local(_player.global_position).x
	var generation_limit_x := player_local_x + generation_ahead_pixels
	while _chunks_generated < max_generated_chunks and float(_next_cell_x * TILE_SIZE.x) < generation_limit_x:
		_append_chunk()
		if not _is_generating:
			break

func _find_right_edge_surface() -> Vector2i:
	var used := _ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Vector2i(-1, -1)
	var rightmost_x := used.position.x + used.size.x - 1
	var surface := _surface_in_column(rightmost_x, used)
	if surface.y >= 0:
		return surface
	for cell_x in range(rightmost_x - 1, used.position.x - 1, -1):
		surface = _surface_in_column(cell_x, used)
		if surface.y >= 0:
			return surface
	return Vector2i(-1, -1)

func _surface_in_column(cell_x: int, used: Rect2i) -> Vector2i:
	for cell_y in range(used.position.y, used.position.y + used.size.y - 1):
		var cell := Vector2i(cell_x, cell_y)
		if _ground.get_cell_source_id(cell) < 0 or _ground.get_cell_atlas_coords(cell).y != 0:
			continue
		if _ground.get_cell_source_id(cell + Vector2i.DOWN) >= 0:
			return cell
	return Vector2i(-1, -1)

func _append_chunk() -> void:
	if not _is_generating:
		return
	var chunk_index := _choose_chunk_index()
	var palette_x := _palette_for_chunk(_chunks_generated)
	var chunk := CHUNK_SCENES[chunk_index].instantiate() as Node2D
	chunk.set("surface_atlas_x", palette_x)
	add_child(chunk)
	var source_layer := chunk.get_node_or_null("Tiles") as TileMapLayer
	if source_layer == null:
		push_warning("Terrain chunk is missing its Tiles TileMapLayer.")
		chunk.queue_free()
		_is_generating = false
		return
	var chunk_width := source_layer.get_used_rect().size.x
	if chunk_width <= 0:
		push_warning("Terrain chunk has no tile cells; add a surface profile or paint its Tiles layer.")
		chunk.queue_free()
		_is_generating = false
		return
	for local_cell in source_layer.get_used_cells():
		var target_cell := Vector2i(_next_cell_x + local_cell.x, _base_surface_y + local_cell.y)
		var atlas_coords := source_layer.get_cell_atlas_coords(local_cell)
		atlas_coords.x = palette_x
		_ground.set_cell(
			target_cell,
			source_layer.get_cell_source_id(local_cell),
			atlas_coords,
			source_layer.get_cell_alternative_tile(local_cell)
		)
	_last_chunk_was_bridge = String(chunk.name) == "SafeBridge"
	_next_cell_x += chunk_width
	_chunks_generated += 1
	chunk.free()

func _choose_chunk_index() -> int:
	if _chunks_generated == 0:
		return 0
	var selected := _random.randi_range(0, CHUNK_SCENES.size() - 1)
	while String(CHUNK_SCENES[selected].resource_path).ends_with("terrain_chunk_bridge.tscn") and _last_chunk_was_bridge:
		selected = _random.randi_range(0, CHUNK_SCENES.size() - 1)
	return selected

func _palette_for_chunk(chunk_index: int) -> int:
	var palette_index := int(chunk_index / 4) % PALETTE_ATLAS_COLUMNS.size()
	return PALETTE_ATLAS_COLUMNS[palette_index]

extends Marker2D
class_name StageSpawnMarker

enum SpawnKind { SLIME, PURPLE_SLIME, BAT, BEETLE, WISP, COIN, FRUIT, POWERUP, CHECKPOINT, MOVING_PLATFORM, RELIC, ISLAND_RAIDER, RUNE_TORTOISE }

@export var spawn_kind: SpawnKind = SpawnKind.SLIME
@export var movement_speed := 36.0
@export var patrol_distance := 36.0
@export var treasure_points := 1
@export var platform_end_offset := Vector2(24, -18)
@export var platform_travel_time := 3.0
@export var relic_id := ""

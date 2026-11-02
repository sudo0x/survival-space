extends RefCounted
## Spawns the hand-authored sprite-sheet effects used by combat.

const EFFECT_SCENE: PackedScene = preload("res://scense/combat_effect.tscn")

static func spawn_slash(parent: Node, world_position: Vector2, facing: float) -> void:
	_spawn(parent, world_position, &"slash", facing)


static func spawn_directional_slash(parent: Node, world_position: Vector2, direction: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	var effect := EFFECT_SCENE.instantiate() as Node2D
	parent.add_child(effect)
	effect.global_position = world_position
	effect.rotation = direction.angle()
	effect.call("play_effect", &"slash")


static func spawn_impact(parent: Node, world_position: Vector2, _tint: Color = Color.WHITE) -> void:
	_spawn(parent, world_position, &"impact")


static func spawn_armor_hit(parent: Node, world_position: Vector2) -> void:
	_spawn(parent, world_position, &"armor_hit")


static func _spawn(parent: Node, world_position: Vector2, animation_name: StringName, facing: float = 1.0) -> void:
	if not is_instance_valid(parent):
		return
	var effect := EFFECT_SCENE.instantiate() as Node2D
	parent.add_child(effect)
	effect.global_position = world_position
	effect.call("play_effect", animation_name, facing)

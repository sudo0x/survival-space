extends Node
class_name PlayerMagicAbility
## Tap Magic for the equipped bolt. Hold it to launch a directional wind slash.

const MAGIC_BOLT_SCENE: PackedScene = preload("res://scense/magic_bolt.tscn")
const WIND_SLASH_SCENE: PackedScene = preload("res://scense/wind_slash.tscn")
const RIFT_LIGHTNING_FRAMES: SpriteFrames = preload("res://assests/sprites/rift_lightning_frames.tres")
const STAR_BOLT_FRAMES: SpriteFrames = preload("res://assests/sprites/star_bolt_frames.tres")
const FROST_FRAMES: SpriteFrames = preload("res://assests/sprites/frost_spell_frames.tres")

const HOLD_TO_WIND_SECONDS := 0.24
const WIND_COOLDOWN_SECONDS := 2.5
const SPELL_COLORS: Array[Color] = [
	Color(0.48, 0.84, 1.0),
	Color(1.0, 0.66, 0.24),
	Color(0.42, 0.86, 1.0),
]

@export_range(0.12, 1.0, 0.04) var quick_cooldown_seconds := 0.28
@export_range(1, 5, 1) var chained_enemies := 2
@export_range(80.0, 260.0, 10.0) var chain_radius := 150.0

var magic_element := -1 # -1 is the always-available Arcane bolt; enemy drops equip 0..2.
var _quick_cooldown := 0.0
var _wind_cooldown := 0.0
var _magic_was_pressed := false
var _magic_hold_time := 0.0
var _wind_fired_this_press := false
var _active_wind: Node2D


func handle_input(aim_direction: Vector2, delta: float) -> void:
	_quick_cooldown = maxf(_quick_cooldown - delta, 0.0)
	_wind_cooldown = maxf(_wind_cooldown - delta, 0.0)

	if Input.is_action_just_pressed("magic"):
		_magic_was_pressed = true
		_magic_hold_time = 0.0
		_wind_fired_this_press = false

	if _magic_was_pressed and Input.is_action_pressed("magic"):
		_magic_hold_time += delta
		if _magic_hold_time >= HOLD_TO_WIND_SECONDS and _wind_cooldown <= 0.0 and not _wind_fired_this_press:
			_cast_wind(aim_direction)
			_wind_fired_this_press = true
			_wind_cooldown = WIND_COOLDOWN_SECONDS

	if Input.is_action_just_released("magic"):
		if _magic_was_pressed and not _wind_fired_this_press and _magic_hold_time < HOLD_TO_WIND_SECONDS:
			_cast_quick_spell(aim_direction)
		_magic_was_pressed = false
		_magic_hold_time = 0.0
		_wind_fired_this_press = false


func _cast_quick_spell(aim_direction: Vector2) -> void:
	if _quick_cooldown > 0.0:
		return
	_quick_cooldown = quick_cooldown_seconds
	var caster := get_parent() as Node2D
	var scene := get_tree().current_scene
	if caster == null or scene == null:
		return
	var target := _find_auto_target(caster)
	var direction := _auto_aim_direction(caster, target, aim_direction)
	var bolt := MAGIC_BOLT_SCENE.instantiate() as MagicBolt
	if bolt == null:
		return
	bolt.direction = -1.0 if direction.x < 0.0 else 1.0
	bolt.set_spell_color(_spell_color())
	if target != null:
		bolt.set_homing_target(target)
	if magic_element == 0:
		bolt.set_spell_frames(RIFT_LIGHTNING_FRAMES)
		bolt.configure_chain(chained_enemies, chain_radius, 0.16)
	elif magic_element == 1:
		bolt.set_spell_frames(STAR_BOLT_FRAMES)
		bolt.configure_piercing(3)
	elif magic_element == 2:
		bolt.set_spell_frames(FROST_FRAMES)
		bolt.configure_piercing(3)
		bolt.configure_freeze(1.55)
	var spawn_direction := direction if direction.length_squared() > 0.001 else Vector2.RIGHT
	scene.add_child(bolt)
	bolt.launch_from(caster.global_position + Vector2(0.0, -12.0) + spawn_direction * 12.0, direction, target)
	_play_cast_sound()


func _cast_wind(aim_direction: Vector2) -> void:
	var caster := get_parent() as Node2D
	var scene := get_tree().current_scene
	if caster == null or scene == null:
		return
	var wind := WIND_SLASH_SCENE.instantiate() as Node2D
	if wind == null:
		return
	var direction_x := signf(aim_direction.x)
	if is_zero_approx(direction_x):
		var player_sprite := caster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		direction_x = -1.0 if player_sprite != null and player_sprite.flip_h else 1.0
	wind.set("sweep_direction", direction_x)
	scene.add_child(wind)
	wind.call("begin_sweep", direction_x)
	_active_wind = wind
	_play_cast_sound()


func _find_auto_target(caster: Node2D) -> Node2D:
	var nearest: Node2D
	var nearest_distance := 560.0
	for candidate in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var enemy := candidate as Node2D
		if enemy == null or not _is_enemy_on_camera(enemy):
			continue
		var collision_object := enemy as CollisionObject2D
		if collision_object != null and collision_object.collision_layer == 0:
			continue
		var distance := caster.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _auto_aim_direction(caster: Node2D, target: Node2D, requested_direction: Vector2) -> Vector2:
	if target != null:
		var to_target := target.global_position - (caster.global_position + Vector2(0.0, -12.0))
		if to_target.length_squared() > 0.001:
			return to_target.normalized()
	if requested_direction.length_squared() > 0.001:
		return requested_direction.normalized()
	var player_sprite := caster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	return Vector2.LEFT if player_sprite != null and player_sprite.flip_h else Vector2.RIGHT


func _is_enemy_on_camera(enemy: Node2D) -> bool:
	var viewport := get_viewport()
	var screen_position := viewport.get_canvas_transform() * enemy.global_position
	return Rect2(Vector2.ZERO, viewport.get_visible_rect().size).has_point(screen_position)


func _spell_color() -> Color:
	return SPELL_COLORS[magic_element] if magic_element >= 0 and magic_element < SPELL_COLORS.size() else SPELL_COLORS[0]


func _play_cast_sound() -> void:
	var sound := get_parent().get_node_or_null("MagicSound") as AudioStreamPlayer2D
	if sound != null:
		sound.play()


func grant_magic_style(element: int) -> void:
	if element >= 0 and element < SPELL_COLORS.size():
		magic_element = element


func get_spell_style_label() -> String:
	match magic_element:
		0:
			return "SPELL: RIFT LIGHTNING"
		1:
			return "SPELL: STAR BOLT"
		2:
			return "SPELL: FROST SHARD"
		_:
			return "SPELL: ARCANE"


func get_spell_style_color() -> Color:
	return _spell_color()


func get_wind_status_label() -> String:
	return "WIND READY" if _wind_cooldown <= 0.0 else "WIND %.1fs" % _wind_cooldown


func is_warded() -> bool:
	return false


func reset() -> void:
	_quick_cooldown = 0.0
	_wind_cooldown = 0.0
	_magic_was_pressed = false
	_magic_hold_time = 0.0
	_wind_fired_this_press = false
	if is_instance_valid(_active_wind):
		_active_wind.queue_free()
	_active_wind = null

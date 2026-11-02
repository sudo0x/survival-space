extends Area2D
class_name MagicBolt

const IMPACT_SCENE: PackedScene = preload("res://scense/magic_impact.tscn")
const FROST_HIT_SCENE: PackedScene = preload("res://scense/frost_hit_effect.tscn")
const CHAIN_LINK_SCENE: PackedScene = preload("res://scense/magic_chain_link.tscn")
const FREEZE_EFFECT_SCENE: PackedScene = preload("res://scense/frost_freeze_effect.tscn")

@export_group("Flight")
@export_range(-1.0, 1.0, 1.0) var direction := 1.0
@export_range(50.0, 600.0, 10.0) var speed := 230.0
@export_range(0.2, 5.0, 0.1) var lifetime := 1.6
@export_range(90.0, 900.0, 30.0) var homing_turn_rate := 420.0

@onready var sprite: AnimatedSprite2D = $MagicSprite
@onready var arcane_light: PointLight2D = $ArcaneLight

var _chain_target_count := 0
var _chain_radius := 0.0
var _stun_seconds := 0.0
var _freeze_seconds := 0.0
var _piercing_targets := 0
var _hit_enemy_ids: Array[int] = []
var spell_color := Color(0.32, 0.82, 1.0)
var spell_frames: SpriteFrames
var travel_direction := Vector2.ZERO
var homing_target: Node2D
var _homing_enabled := false


func configure_chain(target_count: int, radius: float, stun_duration: float) -> void:
	_chain_target_count = maxi(target_count, 0)
	_chain_radius = maxf(radius, 0.0)
	_stun_seconds = maxf(stun_duration, 0.0)


func configure_piercing(target_count: int) -> void:
	_piercing_targets = maxi(target_count, 1)


func configure_freeze(duration: float) -> void:
	_freeze_seconds = maxf(duration, 0.0)


func set_homing_target(target: Node2D) -> void:
	homing_target = target
	_homing_enabled = is_instance_valid(target)


func launch_from(world_position: Vector2, aim_direction: Vector2, target: Node2D = null) -> void:
	# Bolts live in world space. They must never inherit movement from the hero
	# or from a transformed scene parent after the cast is released.
	top_level = true
	global_position = world_position
	travel_direction = aim_direction.normalized() if aim_direction.length_squared() > 0.001 else Vector2.RIGHT
	set_homing_target(target)
	_apply_direction()


func set_spell_color(color: Color) -> void:
	spell_color = color
	if is_node_ready():
		_apply_spell_color()


func set_spell_frames(frames: SpriteFrames) -> void:
	spell_frames = frames
	if is_node_ready() and spell_frames != null:
		sprite.sprite_frames = spell_frames
		_fit_small_spell_frames()
		_apply_direction()
		sprite.play("flight")
		_apply_spell_color()

func _ready() -> void:
	# Keep animated spell sprites visible when they pass in front of platforms.
	z_index = 12
	if spell_frames != null:
		sprite.sprite_frames = spell_frames
	_apply_spell_color()
	_apply_direction()
	if _chain_target_count > 0:
		sprite.scale = Vector2(0.06, 0.06)
		arcane_light.energy = 1.7
		arcane_light.texture_scale = 0.46
	elif _piercing_targets > 0:
		sprite.scale = Vector2(0.058, 0.058)
		arcane_light.energy = 1.6
		arcane_light.texture_scale = 0.44
	_fit_small_spell_frames()
	sprite.play("flight")
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	_update_homing(delta)
	global_position += travel_direction * speed * delta
	arcane_light.energy = 1.2 + sin(Time.get_ticks_msec() / 70.0) * 0.18


func _update_homing(delta: float) -> void:
	if not _homing_enabled:
		return
	if not is_instance_valid(homing_target) or homing_target.is_queued_for_deletion() or _hit_enemy_ids.has(int(homing_target.get_instance_id())) or not _is_on_camera(homing_target):
		# Keep the cast locked to its original, visible target. Reacquiring another
		# foe mid-flight can make the bolt curve back across the player and look
		# like it is following the hero. If the target is gone, preserve trajectory.
		homing_target = null
		_homing_enabled = false
		return
	var desired_direction := homing_target.global_position - global_position
	if desired_direction.length_squared() <= 0.001:
		return
	desired_direction = desired_direction.normalized()
	var max_turn := deg_to_rad(homing_turn_rate) * delta
	var angle_difference := travel_direction.angle_to(desired_direction)
	travel_direction = travel_direction.rotated(clampf(angle_difference, -max_turn, max_turn)).normalized()
	_apply_direction()


func _is_on_camera(enemy: Node2D) -> bool:
	var viewport := get_viewport()
	var enemy_screen_position := viewport.get_canvas_transform() * enemy.global_position
	return Rect2(Vector2.ZERO, viewport.get_visible_rect().size).has_point(enemy_screen_position)


func _apply_direction() -> void:
	if travel_direction.length_squared() <= 0.0001:
		travel_direction = Vector2.LEFT if direction < 0.0 else Vector2.RIGHT
	travel_direction = travel_direction.normalized()
	sprite.flip_h = false
	sprite.rotation = travel_direction.angle()
	arcane_light.rotation = travel_direction.angle()


func _apply_spell_color() -> void:
	sprite.modulate = Color.WHITE if spell_frames != null else spell_color
	arcane_light.color = spell_color


func _fit_small_spell_frames() -> void:
	if spell_frames == null or not spell_frames.has_animation("flight"):
		return
	var frame_texture := spell_frames.get_frame_texture("flight", 0)
	if frame_texture != null and frame_texture.get_width() <= 64:
		# The Frost sheet is already authored as compact 32 px pixel art.
		sprite.scale = Vector2(1.1, 1.1)

func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion() or not body.is_in_group("enemy") or _hit_enemy_ids.has(int(body.get_instance_id())):
		return
	_hit_enemy_ids.append(int(body.get_instance_id()))
	if homing_target == body:
		homing_target = null
	if _piercing_targets <= 0:
		set_deferred("monitoring", false)
		set_physics_process(false)
		speed = 0.0
	_apply_hit(body)
	if _piercing_targets > 0:
		_piercing_targets -= 1
		if _piercing_targets <= 0:
			queue_free()
		return
	if _chain_target_count > 0:
		await _chain_to_nearby_enemies(body)
	queue_free()


func _apply_hit(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	_spawn_impact(enemy.global_position)
	if enemy.has_method("take_hit"):
		enemy.call("take_hit", true)
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.has_method("apply_magic_stun"):
		var control_duration := _freeze_seconds if _freeze_seconds > 0.0 else _stun_seconds
		if control_duration > 0.0:
			enemy.call("apply_magic_stun", control_duration)
			if _freeze_seconds > 0.0:
				_show_freeze_shell(enemy, _freeze_seconds)


func _show_freeze_shell(enemy: Node2D, duration: float) -> void:
	var existing := enemy.get_node_or_null("FrostFreezeEffect")
	if existing != null:
		existing.call("refresh", duration)
		return
	var effect := FREEZE_EFFECT_SCENE.instantiate() as AnimatedSprite2D
	if effect == null:
		return
	var enemy_sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var enemy_size := Vector2(24.0, 28.0)
	if enemy_sprite != null and enemy_sprite.sprite_frames != null and enemy_sprite.sprite_frames.has_animation(enemy_sprite.animation):
		var frame_texture := enemy_sprite.sprite_frames.get_frame_texture(enemy_sprite.animation, enemy_sprite.frame)
		if frame_texture != null:
			enemy_size = frame_texture.get_size() * Vector2(absf(enemy_sprite.scale.x), absf(enemy_sprite.scale.y))
		effect.position = enemy_sprite.position
	var shell_frame := effect.sprite_frames.get_frame_texture("freeze_shell", 1)
	if shell_frame != null:
		var shell_size := shell_frame.get_size()
		# Fit the ice art close to the visible enemy; this is visual sizing, not collision sizing.
		var fit_x := enemy_size.x * 1.2 / shell_size.x
		var fit_y := enemy_size.y * 1.2 / shell_size.y
		effect.scale = Vector2.ONE * clampf(minf(fit_x, fit_y), 0.025, 0.14)
	effect.configure(duration)
	enemy.add_child(effect)


func _chain_to_nearby_enemies(first_target: Node2D) -> void:
	var current_target := first_target
	for _chain_index in range(_chain_target_count):
		if not is_instance_valid(current_target) or current_target.is_queued_for_deletion():
			break
		var start_position := current_target.global_position
		var next_target := _find_next_target(start_position, current_target)
		if next_target == null:
			break
		await get_tree().create_timer(0.075).timeout
		if not is_instance_valid(next_target) or next_target.is_queued_for_deletion():
			continue
		var chain_link := CHAIN_LINK_SCENE.instantiate() as Node2D
		get_tree().current_scene.add_child(chain_link)
		chain_link.call("play_between", start_position, next_target.global_position, spell_color)
		_hit_enemy_ids.append(int(next_target.get_instance_id()))
		_apply_hit(next_target)
		current_target = next_target


func _find_next_target(from_position: Vector2, previous_target: Node2D) -> Node2D:
	var nearest: Node2D
	var nearest_distance := _chain_radius
	for candidate in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(candidate) or candidate == previous_target or candidate.is_queued_for_deletion():
			continue
		var collision_object := candidate as CollisionObject2D
		if collision_object != null and collision_object.collision_layer == 0:
			continue
		if _hit_enemy_ids.has(int(candidate.get_instance_id())):
			continue
		var enemy := candidate as Node2D
		if enemy == null:
			continue
		var distance := from_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _spawn_impact(world_position: Vector2) -> void:
	if _freeze_seconds > 0.0:
		var frost_hit := FROST_HIT_SCENE.instantiate() as Node2D
		get_tree().current_scene.add_child(frost_hit)
		frost_hit.global_position = world_position
		return
	var impact := IMPACT_SCENE.instantiate() as Node2D
	impact.call("set_spell_color", spell_color)
	if spell_frames != null:
		impact.call("set_spell_frames", spell_frames)
	get_tree().current_scene.add_child(impact)
	impact.global_position = world_position

extends Area2D
class_name WindSlashAttack
## A screen-height wind attack that sweeps horizontally across the camera view.

@export_range(320.0, 900.0, 20.0) var sweep_speed_screen := 520.0
@export_range(140.0, 300.0, 10.0) var collision_width_screen := 220.0
@export_range(200.0, 360.0, 10.0) var ribbon_width_screen := 280.0
@export_range(110.0, 180.0, 5.0) var ribbon_height_screen := 145.0
@export_range(60.0, 120.0, 4.0) var ribbon_spacing_screen := 82.0
@export_range(0.14, 0.4, 0.01) var hit_interval := 0.24
@export_range(1, 4, 1) var hits_per_enemy := 3

@onready var wind_sprite: AnimatedSprite2D = $WindVisuals/WindSprite
@onready var hit_shape: CollisionShape2D = $CollisionShape2D
@onready var wind_sound: AudioStreamPlayer = $WindSound

var _wind_sprites: Array[AnimatedSprite2D] = []
var sweep_direction := 1.0
var _screen_x := 0.0
var _has_started := false
var _hit_state: Dictionary = {}
var _canvas_inverse := Transform2D.IDENTITY
var _viewport_size := Vector2.ZERO
var _last_world_size := Vector2.ZERO
var _last_layout_viewport := Vector2.ZERO


func _ready() -> void:
	z_index = 9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if hit_shape.shape != null:
		hit_shape.shape = hit_shape.shape.duplicate()
	wind_sprite.play("wind_slash")
	_wind_sprites.append(wind_sprite)


func begin_sweep(direction_x: float) -> void:
	sweep_direction = -1.0 if direction_x < 0.0 else 1.0
	_refresh_screen_metrics()
	_screen_x = -collision_width_screen * 0.5 if sweep_direction > 0.0 else _viewport_size.x + collision_width_screen * 0.5
	_has_started = true
	if wind_sound.stream != null:
		wind_sound.play()
	_update_world_shape_and_position()


func _physics_process(delta: float) -> void:
	if not _has_started:
		begin_sweep(sweep_direction)
	_refresh_screen_metrics()
	_screen_x += sweep_direction * sweep_speed_screen * delta
	_update_world_shape_and_position()
	_damage_overlapping_enemies(delta)
	if sweep_direction > 0.0 and _screen_x > _viewport_size.x + collision_width_screen:
		queue_free()
	elif sweep_direction < 0.0 and _screen_x < -collision_width_screen:
		queue_free()


func _refresh_screen_metrics() -> void:
	_viewport_size = get_viewport().get_visible_rect().size
	_canvas_inverse = get_viewport().get_canvas_transform().affine_inverse()


func _update_world_shape_and_position() -> void:
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return
	var top_left := _canvas_inverse * Vector2(_screen_x - collision_width_screen * 0.5, 0.0)
	var bottom_right := _canvas_inverse * Vector2(_screen_x + collision_width_screen * 0.5, _viewport_size.y)
	var top_right := _canvas_inverse * Vector2(_screen_x + collision_width_screen * 0.5, 0.0)
	var bottom_left := _canvas_inverse * Vector2(_screen_x - collision_width_screen * 0.5, _viewport_size.y)
	var world_width := top_right.x - top_left.x
	var world_height := bottom_left.y - top_left.y
	global_position = (top_left + bottom_right) * 0.5
	var world_size := Vector2(absf(world_width), absf(world_height))
	var world_size_changed := not world_size.is_equal_approx(_last_world_size)
	if world_size_changed:
		var rectangle := hit_shape.shape as RectangleShape2D
		if rectangle != null:
			rectangle.size = world_size
		_last_world_size = world_size
	if world_size_changed or not _viewport_size.is_equal_approx(_last_layout_viewport):
		_layout_wind_ribbons(world_size.y)
		_last_layout_viewport = _viewport_size


func _layout_wind_ribbons(world_height: float) -> void:
	var frame_texture := wind_sprite.sprite_frames.get_frame_texture("wind_slash", 0)
	if frame_texture == null:
		return
	# Keep the gust artwork horizontal. A fixed, small stack fills the camera
	# height and moves as one sweep; it avoids stretching one sprite into a column.
	var ribbon_count := maxi(1, ceili(_viewport_size.y / ribbon_spacing_screen))
	_ensure_ribbon_count(ribbon_count)
	var world_step := absf(world_height) / ribbon_count
	var ribbon_world_width := absf(_canvas_inverse.basis_xform(Vector2(ribbon_width_screen, 0.0)).x)
	var ribbon_world_height := absf(_canvas_inverse.basis_xform(Vector2(0.0, ribbon_height_screen)).y)
	for index in range(_wind_sprites.size()):
		var ribbon := _wind_sprites[index]
		ribbon.position = Vector2(0.0, -absf(world_height) * 0.5 + world_step * (float(index) + 0.5))
		ribbon.scale = Vector2(ribbon_world_width / frame_texture.get_width(), ribbon_world_height / frame_texture.get_height())


func _ensure_ribbon_count(count: int) -> void:
	while _wind_sprites.size() < count:
		var ribbon := wind_sprite.duplicate() as AnimatedSprite2D
		if ribbon == null:
			return
		$WindVisuals.add_child(ribbon)
		ribbon.frame = _wind_sprites.size() % maxi(1, ribbon.sprite_frames.get_frame_count("wind_slash"))
		ribbon.play("wind_slash")
		_wind_sprites.append(ribbon)
	while _wind_sprites.size() > count:
		var ribbon: AnimatedSprite2D = _wind_sprites.pop_back() as AnimatedSprite2D
		if ribbon != wind_sprite and is_instance_valid(ribbon):
			ribbon.queue_free()


func _damage_overlapping_enemies(delta: float) -> void:
	for body in get_overlapping_bodies():
		if not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_in_group("enemy"):
			continue
		var collision_body := body as CollisionObject2D
		if collision_body != null and collision_body.collision_layer == 0:
			continue
		var instance_id := int(body.get_instance_id())
		if not _hit_state.has(instance_id):
			# Keep an instance ID rather than a Node reference: an enemy can be
			# queue_freed by the hit and the reference is no longer safe to cast.
			_hit_state[instance_id] = {"timer": 0.0, "hits": 0}
			_damage_enemy(instance_id)
			continue
		var state: Dictionary = _hit_state[instance_id]
		state["timer"] = float(state["timer"]) + delta
		if float(state["timer"]) >= hit_interval and int(state["hits"]) < hits_per_enemy:
			state["timer"] = 0.0
			_damage_enemy(instance_id)
	for tracked_id in _hit_state.keys():
		var tracked_enemy := instance_from_id(int(tracked_id))
		if tracked_enemy == null or not is_instance_valid(tracked_enemy):
			_hit_state.erase(tracked_id)
			continue
		if tracked_enemy is Node and (tracked_enemy as Node).is_queued_for_deletion():
			_hit_state.erase(tracked_id)


func _damage_enemy(instance_id: int) -> void:
	if not _hit_state.has(instance_id):
		return
	var state: Dictionary = _hit_state[instance_id]
	var enemy_object := instance_from_id(instance_id)
	if enemy_object == null or not is_instance_valid(enemy_object) or not (enemy_object is Node2D):
		_hit_state.erase(instance_id)
		return
	var enemy := enemy_object as Node2D
	if enemy.is_queued_for_deletion():
		_hit_state.erase(instance_id)
		return
	var is_first_hit := int(state["hits"]) == 0
	if enemy.has_method("take_hit"):
		enemy.call("take_hit", true)
	if is_first_hit and is_instance_valid(enemy) and not enemy.is_queued_for_deletion() \
		and enemy.has_method("apply_wind_carry"):
		var mass := 1.0
		if enemy.has_method("get_wind_mass"):
			mass = maxf(float(enemy.call("get_wind_mass")), 0.5)
		var sweep_speed_world := _canvas_inverse.basis_xform(Vector2(sweep_speed_screen, 0.0)).length()
		enemy.call("apply_wind_carry", sweep_direction, mass, sweep_speed_world)
	state["hits"] = int(state["hits"]) + 1

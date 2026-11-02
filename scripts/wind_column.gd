extends Area2D
class_name WindColumnAttack
## A tall, lightweight wind spell that sweeps across the current camera view.

@export_range(320.0, 900.0, 20.0) var sweep_speed_screen := 520.0
@export_range(120.0, 320.0, 10.0) var collision_width_screen := 240.0
@export_range(56.0, 144.0, 4.0) var visual_width_screen := 94.0
@export_range(0.14, 0.4, 0.01) var hit_interval := 0.24
@export_range(1, 4, 1) var hits_per_enemy := 3

@onready var wind_sprite: AnimatedSprite2D = $WindSprite
@onready var hit_shape: CollisionShape2D = $CollisionShape2D

var sweep_direction := 1.0
var _screen_x := 0.0
var _has_started := false
var _hit_state: Dictionary = {}
var _canvas_inverse := Transform2D.IDENTITY
var _viewport_size := Vector2.ZERO


func _ready() -> void:
	z_index = 9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monitoring = true
	if hit_shape.shape != null:
		hit_shape.shape = hit_shape.shape.duplicate()
	wind_sprite.play("wind")


func begin_sweep() -> void:
	_refresh_screen_metrics()
	_screen_x = -collision_width_screen * 0.5 if sweep_direction >= 0.0 else _viewport_size.x + collision_width_screen * 0.5
	_has_started = true
	_update_world_shape_and_position()


func _physics_process(delta: float) -> void:
	if not _has_started:
		begin_sweep()
	_refresh_screen_metrics()
	_screen_x += signf(sweep_direction) * sweep_speed_screen * delta
	_update_world_shape_and_position()
	_damage_overlapping_enemies(delta)
	if sweep_direction >= 0.0 and _screen_x > _viewport_size.x + collision_width_screen:
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
	var rectangle := hit_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(absf(world_width), absf(world_height))
	wind_sprite.scale = Vector2(visual_width_screen / 64.0 * absf(world_width / collision_width_screen), absf(world_height) / 64.0)


func _damage_overlapping_enemies(delta: float) -> void:
	var overlapping_ids: Dictionary = {}
	for body in get_overlapping_bodies():
		if not is_instance_valid(body) or body.is_queued_for_deletion() or not body.is_in_group("enemy"):
			continue
		var collision_body := body as CollisionObject2D
		if collision_body != null and collision_body.collision_layer == 0:
			continue
		var instance_id := int(body.get_instance_id())
		overlapping_ids[instance_id] = true
		if not _hit_state.has(instance_id):
			_hit_state[instance_id] = {"enemy": body, "timer": 0.0, "hits": 0}
			_damage_enemy(instance_id)
			continue
		var state: Dictionary = _hit_state[instance_id]
		state["timer"] = float(state["timer"]) + delta
		if float(state["timer"]) >= hit_interval and int(state["hits"]) < hits_per_enemy:
			state["timer"] = 0.0
			_damage_enemy(instance_id)
	for tracked_id in _hit_state.keys():
		if not overlapping_ids.has(tracked_id):
			_hit_state.erase(tracked_id)


func _damage_enemy(instance_id: int) -> void:
	if not _hit_state.has(instance_id):
		return
	var state: Dictionary = _hit_state[instance_id]
	var enemy := state["enemy"] as Node2D
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		_hit_state.erase(instance_id)
		return
	if enemy.has_method("apply_magic_stun"):
		enemy.call("apply_magic_stun", 0.18)
	if enemy.has_method("take_hit"):
		enemy.call("take_hit", true)
	state["hits"] = int(state["hits"]) + 1

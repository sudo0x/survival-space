extends CharacterBody2D

## Slow armored patrol. A stomp opens the rune shell for follow-up attacks.
@export var speed := 23.0
@export var patrol_distance := 52.0
@export var shell_open_duration := 2.4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var floor_probe: RayCast2D = $FloorProbe
const COMBAT_EFFECTS := preload("res://scripts/combat_effects.gd")
const WIND_CARRY := preload("res://scripts/wind_carry.gd")

var _home_x := 0.0
var _direction := -1.0
var _open_timer := 0.0
var _hurt_cooldown := 0.0
var _magic_stun_timer := 0.0
var _is_defeated := false


func _ready() -> void:
	_home_x = global_position.x
	add_to_group("enemy")
	sprite.play("walk")
	_update_facing()


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	if WIND_CARRY.move_if_active(self, delta):
		return
	if _magic_stun_timer > 0.0:
		_magic_stun_timer = maxf(_magic_stun_timer - delta, 0.0)
		velocity = Vector2.ZERO
		move_and_slide()
		if _magic_stun_timer == 0.0:
			sprite.modulate = Color.WHITE
		return
	_open_timer = maxf(_open_timer - delta, 0.0)
	_hurt_cooldown = maxf(_hurt_cooldown - delta, 0.0)
	if _open_timer > 0.0:
		sprite.modulate = Color(0.48, 1.0, 1.0)
	else:
		sprite.modulate = Color.WHITE
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	if is_on_floor():
		floor_probe.target_position = Vector2(_direction * 16.0, 24.0)
		floor_probe.force_raycast_update()
		if is_on_wall() or not floor_probe.is_colliding() or absf(global_position.x - _home_x) >= patrol_distance:
			_direction *= -1.0
			_update_facing()
	velocity.x = _direction * speed
	move_and_slide()
	if is_on_wall():
		_direction *= -1.0
		_update_facing()
	if absf(velocity.x) <= 1.0:
		sprite.stop()
	else:
		sprite.play("walk")


func _update_facing() -> void:
	sprite.flip_h = _direction < 0.0


func stomp() -> void:
	if _open_timer > 0.0:
		_defeat()
	else:
		_open_timer = shell_open_duration
		_hurt_cooldown = 0.16
		sprite.modulate = Color(0.48, 1.0, 1.0)


func take_hit(suppress_impact: bool = false) -> void:
	if _is_defeated or _hurt_cooldown > 0.0:
		return
	if not suppress_impact:
		COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, global_position + Vector2(0.0, -8.0), Color(0.48, 0.94, 1.0))
	if _open_timer > 0.0:
		_defeat()
	else:
		_hurt_cooldown = 0.22
		sprite.modulate = Color(1.0, 0.62, 0.3)
		var flash := create_tween()
		flash.tween_interval(0.12)
		flash.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func apply_magic_stun(duration: float) -> void:
	WIND_CARRY.freeze(self, duration)
	_magic_stun_timer = maxf(_magic_stun_timer, duration)
	sprite.modulate = Color(0.52, 0.86, 1.0)


func get_wind_mass() -> float:
	return 3.6


func apply_wind_carry(direction_x: float, mass: float, sweep_speed_world: float) -> void:
	_magic_stun_timer = 0.0
	WIND_CARRY.start(self, direction_x, mass, sweep_speed_world, false)


func _defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	GameEvents.enemy_defeated.emit(global_position)
	var death_tween := create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(sprite, "scale", Vector2.ZERO, 0.22)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.22)
	death_tween.finished.connect(queue_free)

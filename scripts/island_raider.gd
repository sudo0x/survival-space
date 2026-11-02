extends CharacterBody2D

## A sword fighter that patrols, closes in, and leaps toward the player when
## they take a lower route. Its melee strike has a visible wind-up.
@export var speed := 42.0
@export var patrol_distance := 72.0
@export var max_health := 3
@export var notice_distance := 220.0
@export var attack_range := 31.0

@export_group("Drop Ambush")
@export_range(64.0, 240.0, 8.0) var drop_ambush_range := 156.0
@export_range(0.1, 0.8, 0.02) var drop_ambush_windup := 0.36
@export_range(0.8, 5.0, 0.1) var drop_ambush_cooldown := 2.4
@export_range(1.0, 3.0, 0.1) var drop_ambush_horizontal_multiplier := 1.9
@export_range(-220.0, -40.0, 4.0) var drop_ambush_hop_velocity := -92.0

const WINDUP_TIME := 0.48
const ATTACK_COOLDOWN := 1.35
const COMBAT_EFFECTS := preload("res://scripts/combat_effects.gd")
const WIND_CARRY := preload("res://scripts/wind_carry.gd")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_arc: Polygon2D = $AttackArc
@onready var floor_probe: RayCast2D = $FloorProbe

var health := 2
var _home_x := 0.0
var _direction := -1.0
var _windup := 0.0
var _attack_cooldown := 0.7
var _hurt_cooldown := 0.0
var _magic_stun_timer := 0.0
var _is_defeated := false
var _drop_windup := 0.0
var _drop_cooldown := 0.8
var _is_dropping := false


func _ready() -> void:
	_home_x = global_position.x
	health = max_health
	add_to_group("enemy")
	sprite.play("walk")
	_update_facing()


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	if WIND_CARRY.move_if_active(self, delta):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _magic_stun_timer > 0.0:
		_magic_stun_timer = maxf(_magic_stun_timer - delta, 0.0)
		velocity = Vector2.ZERO
		move_and_slide()
		if _magic_stun_timer == 0.0:
			sprite.modulate = Color.WHITE
		return
	if player != null and player.has_method("is_camouflaged") and bool(player.call("is_camouflaged")):
		_windup = 0.0
		_drop_windup = 0.0
		_is_dropping = false
		attack_arc.visible = false
		sprite.modulate = Color.WHITE
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += get_gravity().y * delta
		move_and_slide()
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_hurt_cooldown = maxf(_hurt_cooldown - delta, 0.0)
	_drop_cooldown = maxf(_drop_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	var target_is_near := player != null \
		and absf(player.global_position.x - global_position.x) <= notice_distance \
		and absf(player.global_position.y - global_position.y) <= 58.0
	var target_is_below := player != null \
		and player.global_position.y > global_position.y + 40.0 \
		and absf(player.global_position.x - global_position.x) <= drop_ambush_range
	var left_limit := _home_x - patrol_distance
	var right_limit := _home_x + patrol_distance

	if _drop_windup > 0.0:
		_drop_windup = maxf(_drop_windup - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		if _drop_windup == 0.0 and is_instance_valid(player):
			_direction = signf(player.global_position.x - global_position.x)
			if is_zero_approx(_direction):
				_direction = 1.0
			_update_facing()
			_is_dropping = true
			_drop_cooldown = drop_ambush_cooldown
			velocity.x = _direction * speed * drop_ambush_horizontal_multiplier
			velocity.y = drop_ambush_hop_velocity
			sprite.modulate = Color.WHITE
	elif _is_dropping:
		velocity.x = _direction * speed * 1.9
	elif target_is_below and is_on_floor() and _drop_cooldown <= 0.0 and _windup <= 0.0:
		_direction = signf(player.global_position.x - global_position.x)
		if is_zero_approx(_direction):
			_direction = 1.0
		_update_facing()
		_drop_windup = drop_ambush_windup
		velocity.x = 0.0
		sprite.modulate = Color(1.0, 0.72, 0.38)
	elif _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		if _windup == 0.0:
			attack_arc.visible = true
			attack_arc.scale = Vector2.ZERO
			var slash_tween := create_tween()
			slash_tween.tween_property(attack_arc, "scale", Vector2.ONE, 0.09)
			slash_tween.tween_interval(0.1)
			slash_tween.tween_property(attack_arc, "scale", Vector2.ZERO, 0.1)
			slash_tween.finished.connect(func() -> void: attack_arc.visible = false)
			if player != null and absf(player.global_position.x - global_position.x) <= attack_range \
				and absf(player.global_position.y - global_position.y) <= 36.0:
				player.call("take_damage")
			_attack_cooldown = ATTACK_COOLDOWN
			sprite.modulate = Color.WHITE
	elif target_is_near and absf(player.global_position.x - global_position.x) <= attack_range \
		and _attack_cooldown <= 0.0:
		_direction = signf(player.global_position.x - global_position.x)
		if is_zero_approx(_direction):
			_direction = 1.0
		_update_facing()
		_windup = WINDUP_TIME
		velocity.x = 0.0
		sprite.modulate = Color(1.0, 0.72, 0.38)
	elif target_is_near:
		_direction = signf(player.global_position.x - global_position.x)
		if is_zero_approx(_direction):
			_direction = 1.0
		velocity.x = _direction * speed * 1.18
	else:
		velocity.x = _direction * speed

	# Keep it grounded and within its encounter zone so it cannot walk off a
	# platform and fall into the island gap.
	if is_on_floor() and not _is_dropping:
		floor_probe.target_position = Vector2(_direction * 16.0, 24.0)
		floor_probe.force_raycast_update()
		if not floor_probe.is_colliding() or global_position.x <= left_limit or global_position.x >= right_limit:
			velocity.x = 0.0
			if not target_is_near:
				_direction *= -1.0
				_update_facing()
	move_and_slide()
	if _is_dropping and is_on_floor() and velocity.y >= 0.0:
		_is_dropping = false
		velocity.x = 0.0
		sprite.modulate = Color.WHITE

	if absf(velocity.x) > 2.0:
		if not sprite.is_playing():
			sprite.play("walk")
	else:
		sprite.stop()
		sprite.frame = 0


func _update_facing() -> void:
	sprite.flip_h = _direction < 0.0
	attack_arc.position.x = 17.0 * _direction
	attack_arc.rotation = 0.0 if _direction > 0.0 else PI


func stomp() -> void:
	take_hit()


func take_hit(suppress_impact: bool = false) -> void:
	if _is_defeated or _hurt_cooldown > 0.0:
		return
	if not suppress_impact:
		COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, global_position + Vector2(0.0, -12.0), Color(1.0, 0.48, 0.3))
	_hurt_cooldown = 0.2
	health -= 1
	sprite.modulate = Color(1.0, 0.38, 0.32)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_direction = signf(global_position.x - player.global_position.x)
		if is_zero_approx(_direction):
			_direction = 1.0
		velocity.x = _direction * 62.0
		velocity.y = -42.0
		_update_facing()
	if health <= 0:
		_is_defeated = true
		velocity = Vector2.ZERO
		collision_layer = 0
		collision_mask = 0
		GameEvents.enemy_defeated.emit(global_position)
		var death_tween := create_tween()
		death_tween.set_parallel(true)
		death_tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
		death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		death_tween.finished.connect(queue_free)
	else:
		var flash := create_tween()
		flash.tween_interval(0.12)
		flash.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func apply_magic_stun(duration: float) -> void:
	WIND_CARRY.freeze(self, duration)
	_magic_stun_timer = maxf(_magic_stun_timer, duration)
	sprite.modulate = Color(0.52, 0.86, 1.0)


func get_wind_mass() -> float:
	return 1.6


func apply_wind_carry(direction_x: float, mass: float, sweep_speed_world: float) -> void:
	_magic_stun_timer = 0.0
	_windup = 0.0
	_drop_windup = 0.0
	_is_dropping = false
	WIND_CARRY.start(self, direction_x, mass, sweep_speed_world, false)

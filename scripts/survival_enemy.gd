extends CharacterBody2D
class_name SurvivalEnemy

enum Kind { RIFT_MOTH, COMET_HOUND, PRISM_SENTRY, STAR_SCYTHE, RIFT_EEL, SOLAR_WASP }

@export_enum("Rift Moth", "Comet Hound", "Prism Sentry", "Star Scythe", "Rift Eel", "Solar Wasp") var enemy_kind: int = Kind.RIFT_MOTH
@export var chase_speed := 64.0
@export var projectile_scene: PackedScene

const WIND_CARRY := preload("res://scripts/wind_carry.gd")
const COMBAT_EFFECTS := preload("res://scripts/combat_effects.gd")
const MAX_HEALTH_BY_KIND: Array[int] = [3, 4, 6, 4, 5, 3]
const WIND_MASS_BY_KIND: Array[float] = [0.72, 1.45, 3.8, 0.88, 1.1, 0.62]
const ATTACK_NOTICE_RANGE := 420.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var health := 3
var _player: Node2D
var _facing := -1.0
var _attack_cooldown := 1.0
var _windup := 0.0
var _lunge_timer := 0.0
var _dive_timer := 0.0
var _stun_timer := 0.0
var _hurt_cooldown := 0.0
var _defeated := false
var _shot_windup := false
var _home_y := 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("space_swarm")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	health = MAX_HEALTH_BY_KIND[enemy_kind]
	_home_y = global_position.y
	match enemy_kind:
		Kind.RIFT_MOTH:
			collision_mask = 0
			body_shape.shape = CircleShape2D.new()
			(body_shape.shape as CircleShape2D).radius = 10.0
			body_shape.position.y = -24.0
			sprite.play("rift_moth_fly")
		Kind.COMET_HOUND:
			body_shape.shape = RectangleShape2D.new()
			(body_shape.shape as RectangleShape2D).size = Vector2(28.0, 16.0)
			body_shape.position.y = -8.0
			sprite.play("comet_hound_run")
		Kind.PRISM_SENTRY:
			body_shape.shape = RectangleShape2D.new()
			(body_shape.shape as RectangleShape2D).size = Vector2(24.0, 30.0)
			body_shape.position.y = -15.0
			sprite.play("prism_sentry_idle")
		Kind.STAR_SCYTHE:
			collision_mask = 0
			body_shape.shape = CircleShape2D.new()
			(body_shape.shape as CircleShape2D).radius = 11.0
			body_shape.position.y = -24.0
			sprite.play("star_scythe_fly")
		Kind.RIFT_EEL:
			collision_mask = 0
			body_shape.shape = RectangleShape2D.new()
			(body_shape.shape as RectangleShape2D).size = Vector2(30.0, 13.0)
			body_shape.position.y = -24.0
			sprite.play("rift_eel_fly")
		Kind.SOLAR_WASP:
			collision_mask = 0
			body_shape.shape = CircleShape2D.new()
			(body_shape.shape as CircleShape2D).radius = 9.0
			body_shape.position.y = -24.0
			sprite.play("solar_wasp_fly")
	
	if _player != null:
		_facing = signf(_player.global_position.x - global_position.x)
		if is_zero_approx(_facing):
			_facing = 1.0
		sprite.flip_h = _facing < 0.0


func configure_swarm_entry(target_position: Vector2) -> void:
	_home_y = global_position.y
	_facing = signf(target_position.x - global_position.x)
	if is_zero_approx(_facing):
		_facing = 1.0
	sprite.flip_h = _facing < 0.0


func _physics_process(delta: float) -> void:
	if _defeated:
		return
	if get_meta("offscreen_reinforcement", false) and _player != null:
		if global_position.distance_to(_player.global_position) > 1150.0:
			queue_free()
			return
	if WIND_CARRY.move_if_active(self, delta):
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_hurt_cooldown = maxf(_hurt_cooldown - delta, 0.0)
	if _stun_timer > 0.0:
		_stun_timer = maxf(_stun_timer - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)
		if not _is_flying_kind():
			velocity.y += get_gravity().y * delta
		move_and_slide()
		return
	if sprite.modulate != Color.WHITE:
		sprite.modulate = Color.WHITE
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	if _player.has_method("is_camouflaged") and bool(_player.call("is_camouflaged")):
		# Losing sight cancels both committed attacks and aim; wait instead of
		# orbiting, chasing, or firing at the hidden hero.
		_windup = 0.0
		_lunge_timer = 0.0
		_dive_timer = 0.0
		_shot_windup = false
		sprite.modulate = Color.WHITE
		velocity = velocity.move_toward(Vector2.ZERO, 520.0 * delta)
		if not _is_flying_kind() and not is_on_floor():
			velocity.y += get_gravity().y * delta
		move_and_slide()
		return
	match enemy_kind:
		Kind.RIFT_MOTH:
			_process_moth(delta)
		Kind.STAR_SCYTHE:
			_process_scythe(delta)
		Kind.RIFT_EEL:
			_process_eel(delta)
		Kind.SOLAR_WASP:
			_process_wasp(delta)
		Kind.COMET_HOUND:
			_process_hound(delta)
		Kind.PRISM_SENTRY:
			_process_sentry(delta)


func _is_flying_kind() -> bool:
	match enemy_kind:
		Kind.RIFT_MOTH, Kind.STAR_SCYTHE, Kind.RIFT_EEL, Kind.SOLAR_WASP:
			return true
		_:
			return false


func _process_moth(delta: float) -> void:
	var offset := _player.global_position - global_position
	var distance := offset.length()
	if _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		sprite.modulate = Color(1.0, 0.68, 0.55) if fmod(_windup, 0.12) < 0.06 else Color.WHITE
		if _windup == 0.0:
			var predicted_position := _player.global_position
			var player_body := _player as CharacterBody2D
			if player_body != null:
				predicted_position += player_body.velocity * 0.18
			var aim := (predicted_position - global_position).normalized()
			velocity = aim * 155.0
			_dive_timer = 0.48
			_attack_cooldown = 2.0
			sprite.modulate = Color.WHITE
	elif _dive_timer > 0.0:
		_dive_timer = maxf(_dive_timer - delta, 0.0)
		if _dive_timer == 0.0:
			_attack_cooldown = 1.4
	else:
		var hover_target := _player.global_position + Vector2(-_facing * 90.0, -78.0 + sin(Time.get_ticks_msec() * 0.004) * 10.0)
		velocity = velocity.move_toward((hover_target - global_position).normalized() * chase_speed, 230.0 * delta)
		if distance < 300.0 and _attack_cooldown <= 0.0:
			_facing = signf(offset.x) if not is_zero_approx(offset.x) else _facing
			sprite.flip_h = _facing < 0.0
			_windup = 0.36
	move_and_slide()


func _process_hound(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	var dx := _player.global_position.x - global_position.x
	_facing = signf(dx) if not is_zero_approx(dx) else _facing
	sprite.flip_h = _facing < 0.0
	if _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		sprite.modulate = Color(1.0, 0.58, 0.35) if fmod(_windup, 0.12) < 0.06 else Color.WHITE
		if _windup == 0.0:
			_lunge_timer = 0.34
			_attack_cooldown = 1.8
			velocity.x = _facing * 178.0
			sprite.modulate = Color.WHITE
	elif _lunge_timer > 0.0:
		_lunge_timer = maxf(_lunge_timer - delta, 0.0)
		if _lunge_timer == 0.0:
			velocity.x *= 0.35
	else:
		velocity.x = move_toward(velocity.x, _facing * chase_speed, 420.0 * delta)
		if _attack_cooldown <= 0.0 and absf(dx) < 190.0 and absf(_player.global_position.y - global_position.y) < 72.0:
			_windup = 0.38
			velocity.x = 0.0
	move_and_slide()


func _process_sentry(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	var offset := _player.global_position - global_position
	var distance := offset.length()
	_facing = signf(offset.x) if not is_zero_approx(offset.x) else _facing
	sprite.flip_h = _facing < 0.0
	if _shot_windup:
		_windup = maxf(_windup - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
		sprite.modulate = Color(0.58, 0.9, 1.0) if fmod(_windup, 0.14) < 0.07 else Color.WHITE
		if _windup == 0.0:
			_fire_shard(Color(0.48, 0.88, 1.0), 122.0)
			_shot_windup = false
			_attack_cooldown = 2.5
			sprite.modulate = Color.WHITE
	elif distance < ATTACK_NOTICE_RANGE and _attack_cooldown <= 0.0 and absf(offset.y) < 190.0:
		_shot_windup = true
		_windup = 0.5
		velocity.x = 0.0
	else:
		var desired_x := 0.0
		if distance > 230.0:
			desired_x = _facing * chase_speed * 0.42
		velocity.x = move_toward(velocity.x, desired_x, 180.0 * delta)
	move_and_slide()


func _process_scythe(delta: float) -> void:
	var offset := _player.global_position - global_position
	var distance := offset.length()
	_facing = signf(offset.x) if not is_zero_approx(offset.x) else _facing
	sprite.flip_h = _facing < 0.0
	if _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, 280.0 * delta)
		sprite.modulate = Color(0.82, 0.62, 1.0) if fmod(_windup, 0.1) < 0.05 else Color.WHITE
		if _windup == 0.0:
			var target_point := _player.global_position + Vector2(_facing * 54.0, 0.0)
			velocity = (target_point - global_position).normalized() * 188.0
			_dive_timer = 0.48
			_attack_cooldown = 2.2
			sprite.modulate = Color.WHITE
	elif _dive_timer > 0.0:
		_dive_timer = maxf(_dive_timer - delta, 0.0)
		if _dive_timer == 0.0:
			velocity *= 0.3
	else:
		var hover_point := _player.global_position + Vector2(-_facing * 112.0, -58.0 + sin(Time.get_ticks_msec() * 0.004) * 20.0)
		var desired_velocity := (hover_point - global_position).normalized() * chase_speed * 1.15
		velocity = velocity.move_toward(desired_velocity, 260.0 * delta)
		if distance < 270.0 and _attack_cooldown <= 0.0:
			_windup = 0.32
	move_and_slide()


func _process_eel(delta: float) -> void:
	var offset := _player.global_position - global_position
	var distance := offset.length()
	_facing = signf(offset.x) if not is_zero_approx(offset.x) else _facing
	sprite.flip_h = _facing < 0.0
	if _windup > 0.0:
		_windup = maxf(_windup - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		sprite.modulate = Color(0.48, 0.9, 1.0) if fmod(_windup, 0.14) < 0.07 else Color.WHITE
		if _windup == 0.0:
			var predicted_target := _player.global_position
			var player_body := _player as CharacterBody2D
			if player_body != null:
				predicted_target += player_body.velocity * 0.22
			var pass_point := predicted_target + Vector2(_facing * 104.0, 0.0)
			velocity = (pass_point - global_position).normalized() * 178.0
			_dive_timer = 0.66
			_attack_cooldown = 2.6
			sprite.modulate = Color.WHITE
	elif _dive_timer > 0.0:
		_dive_timer = maxf(_dive_timer - delta, 0.0)
		if _dive_timer == 0.0:
			velocity *= 0.28
	else:
		var wave := sin(Time.get_ticks_msec() * 0.0028) * 74.0
		var hover_point := _player.global_position + Vector2(-_facing * 154.0, wave - 24.0)
		var desired_velocity := (hover_point - global_position).normalized() * chase_speed
		velocity = velocity.move_toward(desired_velocity, 200.0 * delta)
		if distance < 390.0 and _attack_cooldown <= 0.0:
			_windup = 0.52
	move_and_slide()


func _process_wasp(delta: float) -> void:
	var offset := _player.global_position - global_position
	var distance := offset.length()
	_facing = signf(offset.x) if not is_zero_approx(offset.x) else _facing
	sprite.flip_h = _facing < 0.0
	if _shot_windup:
		_windup = maxf(_windup - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, 190.0 * delta)
		sprite.modulate = Color(1.0, 0.58, 0.28) if fmod(_windup, 0.12) < 0.06 else Color.WHITE
		if _windup == 0.0:
			_fire_shard(Color(1.0, 0.62, 0.28), 156.0)
			_shot_windup = false
			_attack_cooldown = 2.0
			sprite.modulate = Color.WHITE
	else:
		var away := offset.normalized()
		var hover_point := _player.global_position - away * 242.0 + Vector2(0.0, sin(Time.get_ticks_msec() * 0.004) * 24.0)
		var desired_velocity := (hover_point - global_position).normalized() * chase_speed * 1.05
		velocity = velocity.move_toward(desired_velocity, 220.0 * delta)
		if distance < 410.0 and absf(offset.y) < 300.0 and _attack_cooldown <= 0.0:
			_shot_windup = true
			_windup = 0.48
	move_and_slide()


func _fire_shard(tint: Color, shot_speed: float) -> void:
	if projectile_scene == null or _player == null:
		return
	var shot := projectile_scene.instantiate() as Node2D
	if shot == null:
		return
	shot.set("direction", (_player.global_position - global_position).normalized())
	shot.set("speed", shot_speed)
	shot.global_position = global_position + Vector2(_facing * 16.0, -24.0)
	var shard_visual := shot.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if shard_visual != null:
		shard_visual.modulate = tint
	get_tree().current_scene.add_child(shot)


func get_wind_mass() -> float:
	return WIND_MASS_BY_KIND[enemy_kind]


func apply_wind_carry(direction_x: float, mass: float, sweep_speed_world: float) -> void:
	_windup = 0.0
	_shot_windup = false
	_stun_timer = 0.0
	sprite.modulate = Color.WHITE
	WIND_CARRY.start(self, direction_x, mass, sweep_speed_world, _is_flying_kind())


func apply_magic_stun(duration: float) -> void:
	WIND_CARRY.freeze(self, duration)
	_stun_timer = maxf(_stun_timer, duration)
	_windup = 0.0
	_shot_windup = false
	sprite.modulate = Color(0.58, 0.88, 1.0)


func stomp(suppress_impact: bool = false) -> void:
	take_hit(suppress_impact)


func take_hit(suppress_impact: bool = false) -> void:
	if _defeated or _hurt_cooldown > 0.0:
		return
	if not suppress_impact:
		COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, global_position + Vector2(0.0, -20.0), Color(0.45, 0.88, 1.0))
	health -= 1
	_hurt_cooldown = 0.12
	if health <= 0:
		_defeated = true
		collision_layer = 0
		collision_mask = 0
		velocity = Vector2.ZERO
		GameEvents.enemy_defeated.emit(global_position)
		queue_free()
		return
	sprite.modulate = Color(1.0, 0.6, 0.48)
	var hit_timer := get_tree().create_timer(0.09)
	hit_timer.timeout.connect(func() -> void:
		if is_instance_valid(sprite) and not _defeated:
			sprite.modulate = Color.WHITE
	)

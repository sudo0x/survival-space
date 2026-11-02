extends CharacterBody2D
## Fast space predator that joins the swarm, chases the hero, and lunges after a tell.

@export_group("Movement")
@export_range(20.0, 180.0, 2.0) var chase_speed := 72.0
@export_range(100.0, 1000.0, 20.0) var acceleration := 420.0
@export_range(60.0, 500.0, 10.0) var notice_distance := 420.0

@export_group("Attack")
@export_range(12.0, 64.0, 2.0) var attack_range := 24.0
@export_range(0.1, 1.0, 0.05) var attack_windup := 0.34
@export_range(0.5, 3.0, 0.1) var attack_cooldown := 1.45
@export_range(1, 5, 1) var max_health := 3

const COMBAT_EFFECTS := preload("res://scripts/combat_effects.gd")
const WIND_CARRY := preload("res://scripts/wind_carry.gd")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var health := 2
var _player: Node2D
var _attack_timer := 0.0
var _windup_timer := 0.0
var _stun_timer := 0.0
var _hurt_timer := 0.0
var _is_defeated := false
var _is_recovering := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("space_swarm")
	health = max_health
	_rng.randomize()
	_attack_timer = _rng.randf_range(0.35, 1.0)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("fly")


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	if WIND_CARRY.move_if_active(self, delta):
		return
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		velocity = Vector2.ZERO
		return
	if _player.has_method("is_camouflaged") and bool(_player.call("is_camouflaged")):
		_windup_timer = 0.0
		_stun_timer = maxf(_stun_timer - delta, 0.0)
		_hurt_timer = maxf(_hurt_timer - delta, 0.0)
		_is_recovering = false
		_attack_timer = maxf(_attack_timer, 0.5)
		sprite.modulate = Color.WHITE
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _hurt_timer == 0.0 and _stun_timer == 0.0 and not _is_recovering:
		sprite.modulate = Color.WHITE

	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized() if distance > 0.001 else Vector2.ZERO
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0

	if _stun_timer > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return

	if _windup_timer > 0.0:
		_windup_timer = maxf(_windup_timer - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		if _windup_timer == 0.0:
			_attack_timer = attack_cooldown
			_is_recovering = true
			if distance <= attack_range + 14.0:
				COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, _player.global_position + Vector2(0.0, -8.0), Color(0.4, 0.9, 1.0))
				_player.call("take_damage")
				velocity = -direction * chase_speed * 1.2
			else:
				_is_recovering = false
				sprite.play("fly")
		move_and_slide()
		return

	if _is_recovering:
		velocity = velocity.move_toward(-direction * chase_speed * 0.65, acceleration * delta)
		if _attack_timer <= attack_cooldown - 0.24:
			_is_recovering = false
			sprite.modulate = Color.WHITE
			sprite.play("fly")
		move_and_slide()
		return

	if distance <= attack_range and _attack_timer <= 0.0:
		_windup_timer = attack_windup
		sprite.play("attack")
		sprite.modulate = Color(1.0, 0.78, 0.52)
		velocity = Vector2.ZERO
	elif distance <= notice_distance:
		var desired_velocity := direction * chase_speed
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)
		sprite.play("dash" if distance < attack_range * 2.2 else "fly")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 0.45 * delta)
		sprite.play("fly")
	move_and_slide()


func take_hit(suppress_impact: bool = false) -> void:
	if _is_defeated:
		return
	if not suppress_impact:
		COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, global_position, Color(0.42, 0.88, 1.0))
	health -= 1
	if health <= 0:
		_is_defeated = true
		_is_recovering = false
		_windup_timer = 0.0
		collision_layer = 0
		collision_mask = 0
		velocity = Vector2.ZERO
		GameEvents.enemy_defeated.emit(global_position)
		sprite.play("death")
		return
	_stun_timer = 0.2
	_hurt_timer = 0.2
	_is_recovering = false
	sprite.modulate = Color(1.0, 0.48, 0.42)
	sprite.play("hurt")
	var away := Vector2.LEFT if _player == null or global_position.x < _player.global_position.x else Vector2.RIGHT
	velocity = away * 88.0 + Vector2(0.0, -28.0)


func get_wind_mass() -> float:
	return 1.8


func apply_wind_carry(direction_x: float, mass: float, sweep_speed_world: float) -> void:
	_windup_timer = 0.0
	_stun_timer = 0.0
	_is_recovering = false
	WIND_CARRY.start(self, direction_x, mass, sweep_speed_world, true)


func stomp() -> void:
	take_hit()


func apply_magic_stun(duration: float) -> void:
	WIND_CARRY.freeze(self, duration)
	_stun_timer = maxf(_stun_timer, duration)
	_windup_timer = 0.0
	_is_recovering = false
	sprite.modulate = Color(0.52, 0.86, 1.0)



func _on_animation_finished() -> void:
	var animation_name: StringName = sprite.animation
	if animation_name == &"death":
		queue_free()
	elif animation_name == &"hurt" and not _is_defeated:
		sprite.play("fly")
	elif animation_name == &"attack" and _windup_timer > 0.0:
		sprite.play("attack")

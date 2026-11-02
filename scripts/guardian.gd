extends CharacterBody2D

const COMBAT_EFFECTS := preload("res://scripts/combat_effects.gd")
const RIFT_SHOT_SCENE: PackedScene = preload("res://scense/enemy_projectile.tscn")
const WIND_CARRY := preload("res://scripts/wind_carry.gd")

signal health_changed(current_health: int, total_health: int)
signal defeated

const GRAVITY_FALLBACK := 980.0
const PATROL_SPEED := 38.0
const POUNCE_SPEED := 140.0
const POUNCE_VELOCITY := -245.0
const WINDUP_TIME := 0.58
const POUNCE_COOLDOWN := 2.1
const RIFT_SHOT_COOLDOWN := 2.4
const RIFT_SHOT_WINDUP := 0.42
const RIFT_SHOT_RANGE := 420.0

@export var max_health := 5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var visual_animations: AnimationPlayer = $AnimationPlayer

var health := 5
var _direction := -1.0
var _windup_timer := 0.0
var _spell_windup_timer := 0.0
var _spell_cooldown := 1.1
var _pounce_cooldown := 1.0
var _pouncing := false
var _hit_cooldown := 0.0
var _magic_stun_timer := 0.0
var _is_defeated := false
var _base_sprite_scale := Vector2.ONE


func _ready() -> void:
	health = max_health
	_base_sprite_scale = sprite.scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play("idle")
	sprite.flip_h = _direction < 0.0
	add_to_group("enemy")
	health_changed.emit(health, max_health)
	visual_animations.animation_finished.connect(_on_animation_finished)


func set_encounter_origin() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_direction = signf(player.global_position.x - global_position.x)
	if is_zero_approx(_direction):
		_direction = -1.0
	sprite.flip_h = _direction < 0.0


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	var hidden_target := get_tree().get_first_node_in_group("player") as Node
	if hidden_target != null and hidden_target.has_method("is_camouflaged") \
		and bool(hidden_target.call("is_camouflaged")):
		_magic_stun_timer = maxf(_magic_stun_timer - delta, 0.0)
		_windup_timer = 0.0
		_spell_windup_timer = 0.0
		_pouncing = false
		sprite.modulate = Color.WHITE
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += get_gravity().y * delta
		move_and_slide()
		_update_sprite_animation()
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
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_pounce_cooldown = maxf(_pounce_cooldown - delta, 0.0)
	_spell_cooldown = maxf(_spell_cooldown - delta, 0.0)
	var grounded_before_move := is_on_floor()
	if not grounded_before_move:
		velocity.y += get_gravity().y * delta

	if _pouncing and grounded_before_move:
		_pouncing = false
		_pounce_cooldown = POUNCE_COOLDOWN
		sprite.scale = _base_sprite_scale

	if _windup_timer > 0.0:
		_windup_timer = maxf(_windup_timer - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * 8.0 * delta)
		if _windup_timer == 0.0:
			var target := get_tree().get_first_node_in_group("player") as Node2D
			if target != null:
				_direction = signf(target.global_position.x - global_position.x)
				if is_zero_approx(_direction):
					_direction = 1.0
			sprite.flip_h = _direction < 0.0
			velocity.x = _direction * POUNCE_SPEED
			velocity.y = POUNCE_VELOCITY
			_pouncing = true
			sprite.scale = _base_sprite_scale
	elif _spell_windup_timer > 0.0:
		_spell_windup_timer = maxf(_spell_windup_timer - delta, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * 8.0 * delta)
		if _spell_windup_timer == 0.0:
			var spell_target := get_tree().get_first_node_in_group("player") as Node2D
			if spell_target != null:
				_fire_rift_shot(spell_target)
	elif _pouncing:
		velocity.x = _direction * POUNCE_SPEED
	else:
		var target := get_tree().get_first_node_in_group("player") as Node2D
		var horizontal_distance := absf(target.global_position.x - global_position.x) if target != null else INF
		var vertical_distance := absf(target.global_position.y - global_position.y) if target != null else INF
		if target != null and horizontal_distance > 8.0:
			_direction = signf(target.global_position.x - global_position.x)
			sprite.flip_h = _direction < 0.0
		var can_cast := target != null \
			and grounded_before_move \
			and _spell_cooldown == 0.0 \
			and horizontal_distance > 190.0 \
			and horizontal_distance <= RIFT_SHOT_RANGE \
			and vertical_distance <= 160.0
		var can_pounce := target != null \
			and grounded_before_move \
			and _pounce_cooldown == 0.0 \
			and absf(target.global_position.x - global_position.x) <= 210.0 \
			and absf(target.global_position.y - global_position.y) <= 48.0
		if can_cast:
			_direction = signf(target.global_position.x - global_position.x)
			if is_zero_approx(_direction):
				_direction = -1.0
			sprite.flip_h = _direction < 0.0
			_spell_windup_timer = RIFT_SHOT_WINDUP
			velocity.x = 0.0
			sprite.play("attack")
		elif can_pounce:
			_windup_timer = WINDUP_TIME
			velocity.x = 0.0
			sprite.scale = _base_sprite_scale * Vector2(1.22, 0.72)
			sprite.play("attack")
		else:
			var stopping_distance := 34.0
			velocity.x = _direction * PATROL_SPEED * 1.5 if horizontal_distance > stopping_distance else 0.0

	move_and_slide()
	if is_on_wall() and not _pouncing:
		velocity.x = 0.0
	_update_sprite_animation()


func _update_sprite_animation() -> void:
	if _windup_timer > 0.0 or _spell_windup_timer > 0.0:
		if sprite.animation != &"attack":
			sprite.play("attack")
		return
	if _pouncing and sprite.animation == &"attack" and sprite.is_playing():
		return
	var desired_animation: StringName = &"glide" if absf(velocity.x) > 2.0 else &"idle"
	if sprite.animation != desired_animation:
		sprite.play(desired_animation)


func _fire_rift_shot(target: Node2D) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var shot := RIFT_SHOT_SCENE.instantiate() as Area2D
	if shot == null:
		return
	var spawn_direction := signf(target.global_position.x - global_position.x)
	if is_zero_approx(spawn_direction):
		spawn_direction = _direction
	var spawn_position := global_position + Vector2(spawn_direction * 12.0, -20.0)
	shot.set("direction", (target.global_position - spawn_position).normalized())
	shot.set("speed", 92.0)
	shot.scale = Vector2(1.25, 1.25)
	add_sibling(shot)
	shot.global_position = spawn_position
	var projectile_sprite := shot.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if projectile_sprite != null:
		if projectile_sprite.sprite_frames.has_animation("ember_wisp"):
			projectile_sprite.play("ember_wisp")
		projectile_sprite.modulate = Color(0.76, 0.53, 1.0)
	_spell_cooldown = RIFT_SHOT_COOLDOWN
	COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, spawn_position, Color(0.73, 0.48, 1.0))


func take_hit(suppress_impact: bool = false) -> void:
	if _is_defeated or _hit_cooldown > 0.0:
		return
	if not suppress_impact:
		COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, global_position + Vector2(0.0, -14.0), Color(0.5, 0.9, 1.0))
	_hit_cooldown = 0.16
	health -= 1
	health_changed.emit(health, max_health)
	if health <= 0:
		_is_defeated = true
		velocity = Vector2.ZERO
		collision_layer = 0
		collision_mask = 0
		defeated.emit()
		visual_animations.play("fade_out")
	else:
		visual_animations.play("hit_flash")


func apply_magic_stun(duration: float) -> void:
	WIND_CARRY.freeze(self, duration)
	_magic_stun_timer = maxf(_magic_stun_timer, duration)
	sprite.modulate = Color(0.52, 0.86, 1.0)


func get_wind_mass() -> float:
	return 4.5


func apply_wind_carry(direction_x: float, mass: float, sweep_speed_world: float) -> void:
	_magic_stun_timer = 0.0
	_windup_timer = 0.0
	_spell_windup_timer = 0.0
	_pouncing = false
	sprite.scale = _base_sprite_scale
	WIND_CARRY.start(self, direction_x, mass, sweep_speed_world, false)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"fade_out":
		queue_free()


func stomp() -> void:
	take_hit()

extends CharacterBody2D

@export var patrol_distance := 56.0
@export var speed := 32.0
@export var purple_variant := false
@export var pounce_enabled := false
@export_enum("Slime", "Bat", "Beetle", "Ember Wisp", "Rift Crab", "Comet Jelly") var enemy_role := 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var _start_x := 0.0
var _direction := -1.0
var _pounce_cooldown := 1.2
var _windup_timer := 0.0
var _pouncing := false
var _health := 3
var _hit_cooldown := 0.0
var _stun_timer := 0.0
var _magic_stun_timer := 0.0
var _shot_timer := 1.2
var _hover_origin := Vector2.ZERO
var _dive_timer := 0.0
var _base_sprite_scale := Vector2.ONE

const PROJECTILE_SCENE: PackedScene = preload("res://scense/enemy_projectile.tscn")
const COMBAT_EFFECTS := preload("res://scripts/combat_effects.gd")
const WIND_CARRY := preload("res://scripts/wind_carry.gd")
const SPACE_ENEMY_FRAMES: SpriteFrames = preload("res://assests/sprites/space_enemy_frames.tres")

const POUNCE_WARNING_TIME := 0.42
const POUNCE_COOLDOWN := 2.8
const POUNCE_RANGE := 168.0
const POUNCE_SPEED := 112.0
const POUNCE_JUMP_VELOCITY := -205.0

func _ready() -> void:
	_start_x = global_position.x
	_hover_origin = global_position
	add_to_group("enemy")
	sprite.flip_h = _direction > 0.0
	var animation_name := "slime_purple" if purple_variant else "slime_green"
	match enemy_role:
		1: animation_name = "bat"
		2: animation_name = "beetle"
		3: animation_name = "ember_wisp"
		4:
			sprite.sprite_frames = SPACE_ENEMY_FRAMES
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(0.05, 0.05)
			sprite.modulate = Color.WHITE
			animation_name = "rift_crab_walk"
			pounce_enabled = true
		5:
			sprite.sprite_frames = SPACE_ENEMY_FRAMES
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(0.05, 0.05)
			sprite.modulate = Color.WHITE
			animation_name = "comet_jelly_hover"
	_base_sprite_scale = sprite.scale
	sprite.play(animation_name)
	sprite.speed_scale = 0.85 if enemy_role == 2 else (1.15 if enemy_role == 3 else (1.25 if enemy_role == 1 else (1.1 if enemy_role >= 4 else 1.0)))
	if enemy_role == 2:
		_snap_beetle_to_floor.call_deferred()

func _physics_process(delta: float) -> void:
	if enemy_role >= 4 and get_meta("offscreen_reinforcement", false):
		var tracked_player := get_tree().get_first_node_in_group("player") as Node2D
		if tracked_player != null and global_position.distance_to(tracked_player.global_position) > 1050.0:
			queue_free()
			return
	if WIND_CARRY.move_if_active(self, delta):
		return
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	if _magic_stun_timer > 0.0:
		_magic_stun_timer = maxf(_magic_stun_timer - delta, 0.0)
		if enemy_role == 2:
			_stun_timer = maxf(_stun_timer - delta, 0.0)
		velocity = Vector2.ZERO
		move_and_slide()
		if _magic_stun_timer == 0.0:
			sprite.modulate = Color.WHITE
		return
	var hidden_player := get_tree().get_first_node_in_group("player") as Node
	if hidden_player != null and hidden_player.has_method("is_camouflaged") \
		and bool(hidden_player.call("is_camouflaged")):
		_windup_timer = 0.0
		_pouncing = false
		_dive_timer = 0.0
		_shot_timer = maxf(_shot_timer, 0.5)
		sprite.modulate = Color.WHITE
		velocity = velocity.move_toward(Vector2.ZERO, 560.0 * delta)
		move_and_slide()
		return
	if enemy_role == 1:
		_process_bat(delta)
		return
	if enemy_role == 5:
		_process_comet_jelly(delta)
		return
	if enemy_role == 2:
		_process_beetle(delta)
		return
	if enemy_role == 3:
		_process_wisp(delta)
		return
	_process_slime(delta)


func apply_magic_stun(duration: float) -> void:
	WIND_CARRY.freeze(self, duration)
	_magic_stun_timer = maxf(_magic_stun_timer, duration)
	if enemy_role == 2:
		_stun_timer = maxf(_stun_timer, duration)
	sprite.modulate = Color(0.52, 0.86, 1.0)


func get_wind_mass() -> float:
	match enemy_role:
		1: return 0.75 # Bats are light and catch the gust easily.
		2: return 2.4 # Beetles resist the push with their armor.
		3: return 0.65 # Wisps drift readily with the wind.
		4: return 2.8 # Rift crabs are heavy and grounded.
		5: return 1.15 # Comet jellies are light but have some momentum.
		_: return 1.0


func apply_wind_carry(direction_x: float, mass: float, sweep_speed_world: float) -> void:
	var flying := enemy_role == 1 or enemy_role == 3 or enemy_role == 5
	WIND_CARRY.start(self, direction_x, mass, sweep_speed_world, flying)

func _process_slime(delta: float) -> void:
	var grounded_before_move := is_on_floor()
	if not grounded_before_move:
		velocity.y += get_gravity().y * delta
	if enemy_role == 4 and not _pouncing and _windup_timer <= 0.0:
		var target := get_tree().get_first_node_in_group("player") as Node2D
		if target != null and absf(target.global_position.x - global_position.x) <= 460.0 and absf(target.global_position.y - global_position.y) <= 88.0:
			_direction = signf(target.global_position.x - global_position.x)
			if is_zero_approx(_direction):
				_direction = 1.0
			sprite.flip_h = _direction > 0.0
			_start_x = global_position.x

	if pounce_enabled:
		_pounce_cooldown = maxf(_pounce_cooldown - delta, 0.0)
		if _pouncing and grounded_before_move:
			_pouncing = false
			_pounce_cooldown = POUNCE_COOLDOWN
			sprite.scale = _base_sprite_scale

		if _windup_timer > 0.0:
			_windup_timer = maxf(_windup_timer - delta, 0.0)
			velocity.x = move_toward(velocity.x, 0.0, speed * 6.0 * delta)
			if _windup_timer == 0.0:
				var target := get_tree().get_first_node_in_group("player") as Node2D
				if target != null:
					_direction = signf(target.global_position.x - global_position.x)
					if is_zero_approx(_direction):
						_direction = 1.0
					sprite.flip_h = _direction > 0.0
				velocity.x = _direction * POUNCE_SPEED
				velocity.y = POUNCE_JUMP_VELOCITY
				_pouncing = true
		elif _pouncing:
			velocity.x = _direction * POUNCE_SPEED
		else:
			var target := get_tree().get_first_node_in_group("player") as Node2D
			var can_pounce := target != null \
				and grounded_before_move \
				and _pounce_cooldown == 0.0 \
				and absf(target.global_position.x - global_position.x) <= POUNCE_RANGE \
				and absf(target.global_position.y - global_position.y) <= 40.0
			if can_pounce:
				_windup_timer = POUNCE_WARNING_TIME
				velocity.x = 0.0
				sprite.scale = _base_sprite_scale * Vector2(1.28, 0.72)
			else:
				velocity.x = _direction * speed
	else:
		velocity.x = _direction * speed

	if _windup_timer > 0.0:
		sprite.position.y = -6.0
	else:
		sprite.position.y = -8.0 + sin(Time.get_ticks_msec() / 100.0) * 1.0

	move_and_slide()
	if is_on_wall() or absf(global_position.x - _start_x) >= patrol_distance:
		_direction *= -1.0
		sprite.flip_h = _direction > 0.0

func _process_bat(delta: float) -> void:
	var target := get_tree().get_first_node_in_group("player") as Node2D
	var home_y := _hover_origin.y + sin(Time.get_ticks_msec() / 230.0) * 5.0
	var dive_target := Vector2.ZERO
	if target != null and absf(target.global_position.x - global_position.x) < 112.0 and absf(target.global_position.y - global_position.y) < 72.0:
		_dive_timer = 0.5
		dive_target = target.global_position + Vector2(0.0, -8.0)
	else:
		_dive_timer = maxf(_dive_timer - delta, 0.0)
	if _dive_timer > 0.0 and target != null:
		var aim := (dive_target - global_position).normalized()
		velocity = velocity.move_toward(aim * 105.0, 240.0 * delta)
	else:
		velocity.x = _direction * speed
		velocity.y = move_toward(velocity.y, (home_y - global_position.y) * 2.4, 180.0 * delta)
		if absf(global_position.x - _start_x) >= patrol_distance:
			_direction *= -1.0
			sprite.flip_h = _direction > 0.0
	move_and_slide()


func _process_comet_jelly(delta: float) -> void:
	var target := get_tree().get_first_node_in_group("player") as Node2D
	var home_y := _hover_origin.y + sin(Time.get_ticks_msec() / 190.0) * 7.0
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	if target == null:
		velocity.x = _direction * speed
		velocity.y = move_toward(velocity.y, (home_y - global_position.y) * 2.2, 180.0 * delta)
		move_and_slide()
		return
	var to_player := target.global_position - global_position
	var distance := to_player.length()
	if distance <= 96.0 and _shot_timer <= 0.0:
		_dive_timer = 0.48
		_shot_timer = 1.8
	if distance <= 560.0:
		var pursuit_speed := 142.0 if _dive_timer > 0.0 else 74.0
		var desired_velocity := to_player.normalized() * pursuit_speed
		velocity = velocity.move_toward(desired_velocity, 320.0 * delta)
		_dive_timer = maxf(_dive_timer - delta, 0.0)
		sprite.flip_h = to_player.x < 0.0
	else:
		velocity.x = _direction * speed
		velocity.y = move_toward(velocity.y, (home_y - global_position.y) * 2.2, 180.0 * delta)
		if absf(global_position.x - _start_x) >= patrol_distance:
			_direction *= -1.0
			sprite.flip_h = _direction > 0.0
	move_and_slide()

func configure_swarm_entry(target_position: Vector2) -> void:
	# Reinforcement bats enter from off-screen and fly toward the hero before diving.
	_start_x = global_position.x
	_hover_origin = global_position
	_direction = signf(target_position.x - global_position.x)
	if is_zero_approx(_direction):
		_direction = 1.0
	sprite.flip_h = _direction > 0.0
	patrol_distance = maxf(patrol_distance, absf(target_position.x - global_position.x) + 180.0)

func _process_beetle(delta: float) -> void:
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	if _stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		sprite.modulate = Color(1.0, 0.82, 0.38)
	else:
		if not $AnimationPlayer.is_playing():
			sprite.modulate = Color.WHITE
		velocity.x = _direction * speed * 0.72
		if is_on_floor() and not _has_beetle_floor_ahead():
			_direction *= -1.0
			sprite.flip_h = _direction > 0.0
			velocity.x = _direction * speed * 0.72
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	move_and_slide()
	if is_on_wall() or absf(global_position.x - _start_x) >= patrol_distance:
		_direction *= -1.0
		sprite.flip_h = _direction > 0.0

func _has_beetle_floor_ahead() -> bool:
	var ray_start := global_position + Vector2(_direction * 10.0, -8.0)
	var ray_end := ray_start + Vector2(0.0, 32.0)
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _snap_beetle_to_floor() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var ray_start := global_position + Vector2(0.0, -12.0)
	var ray_end := global_position + Vector2(0.0, 64.0)
	var exclusions: Array[RID] = [get_rid()]
	var player := get_tree().get_first_node_in_group("player") as CollisionObject2D
	if player != null:
		exclusions.append(player.get_rid())
	var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask)
	query.exclude = exclusions
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = float(hit.position.y) - 1.0
		velocity.y = 0.0

func _process_wisp(delta: float) -> void:
	var target := get_tree().get_first_node_in_group("player") as Node2D
	global_position.y = _hover_origin.y + sin(Time.get_ticks_msec() / 290.0) * 6.0
	if target == null:
		return
	var dx := target.global_position.x - global_position.x
	var camera := get_viewport().get_camera_2d()
	var visible_range_x := 130.0
	var visible_range_y := 65.0
	if camera != null:
		visible_range_x = maxf(get_viewport_rect().size.x / (camera.zoom.x * 2.0) - 16.0, 0.0)
		visible_range_y = maxf(get_viewport_rect().size.y / (camera.zoom.y * 2.0) - 16.0, 0.0)
	if absf(dx) <= visible_range_x and absf(target.global_position.y - global_position.y) <= visible_range_y:
		_shot_timer -= delta
		sprite.flip_h = dx < 0.0
		sprite.modulate = Color(1.0, 0.68, 0.42) if _shot_timer <= 0.55 else Color.WHITE
		if _shot_timer <= 0.0:
			_shot_timer = 2.1
			sprite.modulate = Color.WHITE
			var projectile := PROJECTILE_SCENE.instantiate()
			projectile.global_position = global_position + Vector2(signf(dx) * 10.0, 0.0)
			projectile.direction = (target.global_position - global_position).normalized()
			get_tree().current_scene.add_child(projectile)
	else:
		_shot_timer = maxf(_shot_timer, 0.65)
		sprite.modulate = Color.WHITE

func stomp(suppress_impact: bool = false) -> void:
	if _hit_cooldown > 0.0:
		return
	if not suppress_impact:
		COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, global_position + Vector2(0.0, -8.0), Color(1.0, 0.76, 0.28))
	if enemy_role == 2 and _stun_timer <= 0.0:
		_stun_timer = 1.25
	_health -= 1
	_hit_cooldown = 0.18
	if _health > 0:
		$AnimationPlayer.play("hit_flash")
		return
	GameEvents.enemy_defeated.emit(global_position)
	queue_free()

func take_hit(suppress_impact: bool = false) -> void:
	if _hit_cooldown > 0.0:
		return
	if enemy_role == 2 and _stun_timer <= 0.0:
		if not suppress_impact:
			COMBAT_EFFECTS.spawn_armor_hit(get_tree().current_scene, global_position + Vector2(0.0, -8.0))
		$AnimationPlayer.play("hit_flash")
		return
	stomp(suppress_impact)

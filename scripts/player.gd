extends CharacterBody2D

@export_group("Survivor Hull")
@export_range(10, 100, 5) var max_health := 100
@export_range(1, 50, 1) var damage_per_hit := 10

@export_group("Air Jump Mana")
@export_range(20.0, 200.0, 10.0) var max_mana := 100.0
@export_range(5.0, 50.0, 5.0) var air_jump_mana_cost := 10.0
@export_range(0.25, 4.0, 0.25) var mana_regen_delay := 1.0
@export_range(5.0, 60.0, 1.0) var mana_regen_per_second := 28.0
@export_group("Flight")
@export_range(20.0, 200.0, 10.0) var max_flight_fuel := 100.0
@export_range(10.0, 60.0, 2.0) var flight_fuel_per_second := 12.0
@export_range(0.25, 4.0, 0.25) var flight_fuel_regen_delay := 1.0
@export_range(5.0, 60.0, 1.0) var flight_fuel_regen_per_second := 24.0
@export_range(60.0, 180.0, 10.0) var flight_lift_speed := 110.0
@export_range(0.1, 0.6, 0.05) var jump_hold_to_fly_delay := 0.2
@export_group("Dash")
@export_range(0.1, 2.0, 0.1) var dash_cooldown_duration := 0.1
@export_range(1, 20, 1) var max_dash_energy := 20
@export_range(1.0, 10.0, 0.5) var dash_energy_regen_interval := 3.0
@export_range(0.15, 0.5, 0.05) var direction_double_tap_window := 0.3
@export_group("Rift Perch")
@export_range(1.0, 10.0, 0.5) var rift_perch_recharge_seconds := 3.0
@export_group("Stored Energy")
@export_range(1, 10, 1) var jump_reserve_bars := 10
@export_range(1, 10, 1) var flight_reserve_bars := 10

const MAX_SPEED := 130.0
const GROUND_ACCELERATION := 900.0
const AIR_ACCELERATION := 800.0
const GROUND_FRICTION := 1100.0
const JUMP_VELOCITY := -300.0
const DOUBLE_JUMP_VELOCITY := -270.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const FALL_RESPAWN_DISTANCE := 220.0
const ENEMY_CONTACT_DAMAGE_RADIUS := 17.5
const ATTACK_RANGE := 70.0
const ATTACK_VERTICAL_RANGE := 38.0
const FLIGHT_ACCELERATION := 900.0
const FLIGHT_GUST_INTERVAL := 0.24
const AIR_DIVE_SPEED := 620.0
const DASH_ENERGY_PER_USE := 1
const MAX_RIFT_PERCH_CHARGES := 3
const COMBAT_EFFECTS := preload("res://scripts/combat_effects.gd")
const MOVEMENT_EFFECT_SCENE: PackedScene = preload("res://scense/movement_effect.tscn")
const RIFT_ANCHOR_SCENE: PackedScene = preload("res://scense/rift_anchor_platform.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var visual_animations: AnimationPlayer = $AnimationPlayer
@onready var hit_animation: AnimationPlayer = $HitAnimationPlayer
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var land_sound: AudioStreamPlayer2D = $LandSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound

var _spawn_position: Vector2
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var health := 100
var mana := 100.0
var mana_reserve := 0.0
var _mana_regen_timer := 0.0
var flight_fuel := 100.0
var flight_fuel_reserve := 0.0
var _flight_fuel_regen_timer := 0.0
var _hurt_cooldown := 0.0
var _is_dead := false
var _attack_cooldown := 0.0
var _is_attacking := false
var _is_double_jumping := false
var _air_jumps_used := 0
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_energy_regen_timer := 0.0
var dash_energy := 20
var _is_dashing := false
var _dash_direction := 1.0
var _left_was_down := false
var _right_was_down := false
var _left_tap_timer := 0.0
var _right_tap_timer := 0.0
var _dash_hit_enemies: Array[int] = []
var _fall_effect_timer := 0.0
var _fly_effect_timer := 0.0
var _is_flying := false
var _is_diving := false
var _anchor_cooldown := 0.0
var rift_perch_charges := MAX_RIFT_PERCH_CHARGES
var _anchor_resting := false
var _anchor_dash_restore_timer := 0.0
var _flight_needs_release := false
var _jump_hold_time := 0.0
var _aim_direction := Vector2.RIGHT
var _mouse_aim_active := false
var _mouse_aim_screen_position := Vector2.ZERO


func _ready() -> void:
	_spawn_position = global_position
	health = max_health
	mana = max_mana
	flight_fuel = max_flight_fuel
	add_to_group("player")
	hit_animation.animation_finished.connect(_on_hit_animation_finished)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_mouse_aim_active = false
	elif event is InputEventMouseMotion and OS.has_feature("pc"):
		# Keep the last world-aim point when the cursor passes over a HUD button,
		# so clicking the on-screen controls does not aim spells at the UI.
		if get_viewport().gui_get_hovered_control() is BaseButton:
			return
		_mouse_aim_screen_position = event.position
		_mouse_aim_active = true
	elif event is InputEventMouseButton and OS.has_feature("pc"):
		if get_viewport().gui_get_hovered_control() is BaseButton:
			return
		_mouse_aim_screen_position = event.position
		_mouse_aim_active = true


func _on_hit_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"hit_flash":
		sprite.modulate = Color.WHITE


func _spawn_death_visual() -> void:
	var death_visual := AnimatedSprite2D.new()
	death_visual.sprite_frames = sprite.sprite_frames
	death_visual.animation = &"death"
	death_visual.frame = 0
	death_visual.scale = sprite.scale
	death_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	death_visual.z_index = z_index + 1
	get_parent().add_child(death_visual)
	death_visual.global_position = sprite.global_position
	death_visual.animation_finished.connect(_on_death_visual_finished)
	death_visual.play(&"death")


func _on_death_visual_finished() -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("player_death_animation_finished"):
		game.player_death_animation_finished()


func reset_for_new_run(start_position: Vector2) -> void:
	_end_flight()
	_spawn_position = start_position
	global_position = start_position
	if has_node("Camera2D"):
		$Camera2D.reset_smoothing()
	velocity = Vector2.ZERO
	health = max_health
	_is_dead = false
	body_collision.set_deferred("disabled", false)
	_hurt_cooldown = 0.0
	_air_jumps_used = 0
	mana = max_mana
	_mana_regen_timer = 0.0
	flight_fuel = max_flight_fuel
	_flight_fuel_regen_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_is_double_jumping = false
	_is_attacking = false
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_dash_energy_regen_timer = 0.0
	dash_energy = max_dash_energy
	_left_was_down = false
	_right_was_down = false
	_left_tap_timer = 0.0
	_right_tap_timer = 0.0
	$MagicAbility.reset()
	_is_dashing = false
	_dash_hit_enemies.clear()
	_flight_needs_release = false
	_jump_hold_time = 0.0
	_is_diving = false
	_anchor_cooldown = 0.0
	rift_perch_charges = MAX_RIFT_PERCH_CHARGES
	_anchor_resting = false
	_anchor_dash_restore_timer = 0.0
	_aim_direction = Vector2.RIGHT
	_fly_effect_timer = 0.0
	modulate = Color.WHITE
	sprite.visible = true
	sprite.scale = Vector2(0.5, 0.5)
	sprite.rotation = 0.0
	sprite.offset = Vector2.ZERO
	sprite.modulate = Color.WHITE
	visual_animations.stop()
	hit_animation.stop()
	sprite.play("idle")


func bounce_from_spring(launch_speed: float) -> void:
	velocity.y = -absf(launch_speed)
	_air_jumps_used = 0
	_is_double_jumping = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jump_sound.pitch_scale = 0.85
	jump_sound.play()
	jump_sound.pitch_scale = 1.0
	sprite.play("jump")
	visual_animations.play("takeoff")
	_spawn_movement_effect(&"double_jump", Vector2(0.0, -4.0))


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_hurt_cooldown = maxf(_hurt_cooldown - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_update_rift_perch_recharge(delta)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if dash_energy >= max_dash_energy:
		_dash_energy_regen_timer = 0.0
	else:
		if _dash_energy_regen_timer <= 0.0:
			_dash_energy_regen_timer = dash_energy_regen_interval
		_dash_energy_regen_timer -= delta
		if _dash_energy_regen_timer <= 0.0:
			restore_dash_energy(DASH_ENERGY_PER_USE)
			_dash_energy_regen_timer = dash_energy_regen_interval if dash_energy < max_dash_energy else 0.0
	_update_mana(delta)
	_update_flight_fuel(delta)
	var double_tap_direction := _update_direction_double_tap(delta)
	if double_tap_direction != 0.0 and not _is_dashing and _dash_cooldown <= 0.0 and dash_energy >= DASH_ENERGY_PER_USE:
		_start_dash(double_tap_direction)
		_process_dash(delta)
		return
	if _is_dashing:
		_end_flight()
		_process_dash(delta)
		return
	if Input.is_action_just_pressed("power") and _dash_cooldown <= 0.0 and dash_energy >= DASH_ENERGY_PER_USE:
		_start_dash()
		_process_dash(delta)
		return
	var was_on_floor := is_on_floor()
	if was_on_floor:
		_air_jumps_used = 0
	_update_jump_timers(delta, was_on_floor)
	_apply_gravity(delta, was_on_floor)
	_handle_air_dive()
	_handle_anchor_cast()
	_handle_horizontal_movement(delta)
	_handle_jump()
	_handle_flight(delta)
	_update_aim_direction()
	_handle_attack()
	_handle_magic(delta)

	var was_falling := velocity.y > 0.0
	move_and_slide()
	_update_anchor_resting(delta)
	_check_enemy_collisions(was_falling)
	_update_fall_effects(delta)
	_update_visuals(was_on_floor)
	_check_for_fall()


func _spawn_movement_effect(animation_name: StringName, offset: Vector2, facing: float = 1.0) -> void:
	var effect := MOVEMENT_EFFECT_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(effect)
	effect.add_to_group("player_movement_effect")
	effect.global_position = global_position + offset
	effect.call("play_effect", animation_name, facing)


func _update_fall_effects(delta: float) -> void:
	if _is_diving or is_on_floor() or velocity.y < 150.0:
		_fall_effect_timer = 0.0
		return
	_fall_effect_timer -= delta
	if _fall_effect_timer <= 0.0:
		_spawn_movement_effect(&"fall", Vector2(0.0, -10.0))
		_fall_effect_timer = 0.24

func _start_dash(direction_hint: float = 0.0) -> void:
	_end_flight()
	_finish_air_dive()
	dash_energy = maxi(dash_energy - DASH_ENERGY_PER_USE, 0)
	if _dash_energy_regen_timer <= 0.0:
		_dash_energy_regen_timer = dash_energy_regen_interval
	_is_dashing = true
	_dash_timer = 0.22
	_dash_cooldown = dash_cooldown_duration
	_dash_hit_enemies.clear()
	_hurt_cooldown = maxf(_hurt_cooldown, _dash_timer + 0.08)
	velocity.y = 0.0
	var input_direction := _read_horizontal_direction()
	if not is_zero_approx(direction_hint):
		_dash_direction = signf(direction_hint)
	else:
		_dash_direction = signf(input_direction) if not is_zero_approx(input_direction) else (-1.0 if sprite.flip_h else 1.0)
	sprite.flip_h = _dash_direction < 0.0
	# Dash should use one restrained wind trail. Clear recent jump/fall gusts so
	# they do not visually stack with the dash burst.
	for old_effect in get_tree().get_nodes_in_group("player_movement_effect"):
		if is_instance_valid(old_effect):
			old_effect.queue_free()
	_spawn_movement_effect(&"dash_wind", Vector2(-_dash_direction * 12.0, -8.0), _dash_direction)
	sprite.play("double_jump")
	modulate = Color(0.55, 1.0, 1.0)

func _process_dash(delta: float) -> void:
	# Let the player steer the dash with left/right instead of locking its
	# direction for the full burst. This keeps touch and keyboard input aligned.
	var input_direction := _read_horizontal_direction()
	if not is_zero_approx(input_direction):
		_dash_direction = signf(input_direction)
		sprite.flip_h = _dash_direction < 0.0
	velocity = Vector2(_dash_direction * 360.0, 0.0)
	move_and_slide()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if int(enemy.get_instance_id()) in _dash_hit_enemies:
			continue
		if global_position.distance_to(enemy.global_position) <= 27.0:
			_dash_hit_enemies.append(int(enemy.get_instance_id()))
			enemy.take_hit()
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_is_dashing = false
		velocity.x *= 0.25
		modulate = Color.WHITE


func _update_jump_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if _jump_was_pressed():
		_jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_gravity(delta: float, on_floor: bool) -> void:
	if not on_floor:
		velocity += get_gravity() * delta

	# Releasing jump early produces a short hop; holding it gives full height.
	if velocity.y < 0.0 and _jump_was_released():
		velocity.y *= 0.48


func _handle_air_dive() -> void:
	var dive_pressed := Input.is_action_just_pressed("air_dive")
	dive_pressed = dive_pressed or Input.is_action_just_pressed("air_dive_down")
	dive_pressed = dive_pressed or Input.is_action_just_pressed("aim_down")
	if dive_pressed and not is_on_floor() and not _is_diving:
		_is_diving = true
		_flight_needs_release = true
		_jump_buffer_timer = 0.0
		_end_flight()
		velocity.y = AIR_DIVE_SPEED
		visual_animations.stop()
		sprite.scale = Vector2(0.075, 0.075)
		sprite.offset = Vector2(0.0, -80.0)
		sprite.play("air_dive_roll")
		for old_effect in get_tree().get_nodes_in_group("player_movement_effect"):
			if is_instance_valid(old_effect):
				old_effect.queue_free()
		_spawn_movement_effect(&"fall", Vector2(0.0, -12.0))
	if _is_diving:
		velocity.y = maxf(velocity.y, AIR_DIVE_SPEED)


func _finish_air_dive() -> void:
	_is_diving = false
	sprite.scale = Vector2(0.5, 0.5)
	sprite.rotation = 0.0
	sprite.offset = Vector2.ZERO


func _handle_anchor_cast() -> void:
	if not Input.is_action_just_pressed("air_anchor") or is_on_floor() or rift_perch_charges <= 0:
		return
	var platform := RIFT_ANCHOR_SCENE.instantiate() as StaticBody2D
	get_tree().current_scene.add_child(platform)
	# Put the one-way ledge just below the collision body's feet so it catches
	# the player on the next fall instead of spawning through their body.
	var body_bottom := body_collision.position.y + body_collision.shape.get_rect().size.y * 0.5
	platform.global_position = global_position + Vector2(0.0, body_bottom + 10.0)
	rift_perch_charges -= 1
	if _anchor_cooldown <= 0.0 and rift_perch_charges < MAX_RIFT_PERCH_CHARGES:
		_anchor_cooldown = rift_perch_recharge_seconds
	_anchor_dash_restore_timer = 0.0
	if velocity.y > 0.0:
		velocity.y = 0.0
	get_tree().call_group("game", "show_anchor_message")


func _update_rift_perch_recharge(delta: float) -> void:
	if rift_perch_charges >= MAX_RIFT_PERCH_CHARGES:
		rift_perch_charges = MAX_RIFT_PERCH_CHARGES
		_anchor_cooldown = 0.0
		return
	_anchor_cooldown -= delta
	while _anchor_cooldown <= 0.0 and rift_perch_charges < MAX_RIFT_PERCH_CHARGES:
		rift_perch_charges += 1
		if rift_perch_charges < MAX_RIFT_PERCH_CHARGES:
			_anchor_cooldown += rift_perch_recharge_seconds
		else:
			_anchor_cooldown = 0.0


func _update_anchor_resting(delta: float) -> void:
	var resting_on_anchor := false
	if is_on_floor():
		for index in get_slide_collision_count():
			var collision := get_slide_collision(index)
			var collider := collision.get_collider() as Node
			if collider != null and collider.is_in_group("air_anchor") and collision.get_normal().y < -0.6:
				resting_on_anchor = true
				break
	_anchor_resting = resting_on_anchor
	sprite.self_modulate = Color(0.55, 0.86, 1.0, 0.66) if _anchor_resting else Color.WHITE
	if not _anchor_resting:
		_anchor_dash_restore_timer = 0.0
		return
	mana = minf(mana + 18.0 * delta, max_mana)
	flight_fuel = minf(flight_fuel + 22.0 * delta, max_flight_fuel)
	_anchor_dash_restore_timer += delta
	if _anchor_dash_restore_timer >= 1.25:
		_anchor_dash_restore_timer -= 1.25
		restore_dash_energy(1)


func is_camouflaged() -> bool:
	return _anchor_resting


func _update_aim_direction() -> void:
	var joystick_vertical_aim := Input.is_action_pressed("aim_up") or Input.is_action_pressed("aim_down")
	if _mouse_aim_active and not joystick_vertical_aim:
		var aim_origin := global_position + Vector2(0.0, -12.0)
		var mouse_world_position := get_viewport().get_canvas_transform().affine_inverse() * _mouse_aim_screen_position
		var mouse_direction := mouse_world_position - aim_origin
		if mouse_direction.length_squared() > 1.0:
			_aim_direction = mouse_direction.normalized()
			if absf(_aim_direction.x) > 0.1:
				sprite.flip_h = _aim_direction.x < 0.0
		return
	var horizontal := _read_horizontal_direction()
	var vertical := 0.0
	if Input.is_action_pressed("aim_up") or Input.is_action_pressed("ui_up"):
		vertical = -1.0
	elif Input.is_action_pressed("aim_down") or Input.is_action_pressed("ui_down"):
		vertical = 1.0
	var direction := Vector2(horizontal, vertical)
	if direction.length_squared() > 0.0:
		_aim_direction = direction.normalized()
		if absf(_aim_direction.x) > 0.1:
			sprite.flip_h = _aim_direction.x < 0.0


func _handle_horizontal_movement(delta: float) -> void:
	var direction := _read_horizontal_direction()

	if not is_zero_approx(direction):
		var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, acceleration * delta)
	else:
		var friction := GROUND_FRICTION if is_on_floor() else AIR_ACCELERATION * 0.35
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _read_horizontal_direction() -> float:
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	return clampf(direction, -1.0, 1.0)


func _update_direction_double_tap(delta: float) -> float:
	var left_down := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right_down := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	_left_tap_timer = maxf(_left_tap_timer - delta, 0.0)
	_right_tap_timer = maxf(_right_tap_timer - delta, 0.0)
	var dash_direction := 0.0

	if left_down and not _left_was_down:
		if _left_tap_timer > 0.0:
			dash_direction = -1.0
			_left_tap_timer = 0.0
		else:
			_left_tap_timer = direction_double_tap_window
	if right_down and not _right_was_down:
		if _right_tap_timer > 0.0:
			dash_direction = 1.0
			_right_tap_timer = 0.0
		else:
			_right_tap_timer = direction_double_tap_window

	_left_was_down = left_down
	_right_was_down = right_down
	return dash_direction


func _handle_jump() -> void:
	if _is_diving or _jump_buffer_timer <= 0.0:
		return

	# The first jump after touching ground (or leaving it during coyote time) is free.
	if _coyote_timer > 0.0 and _air_jumps_used == 0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		jump_sound.play()
		visual_animations.play("takeoff")
		_spawn_movement_effect(&"jump", Vector2.ZERO)
	elif mana >= air_jump_mana_cost:
		mana = maxf(mana - air_jump_mana_cost, 0.0)
		_mana_regen_timer = mana_regen_delay
		velocity.y = DOUBLE_JUMP_VELOCITY
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_air_jumps_used += 1
		_is_double_jumping = true
		jump_sound.pitch_scale = 1.25
		jump_sound.play()
		jump_sound.pitch_scale = 1.0
		sprite.frame = 0
		sprite.play("double_jump")
		visual_animations.play("double_jump_pop")
		_spawn_movement_effect(&"double_jump", Vector2(0.0, -6.0))


func _handle_flight(delta: float) -> void:
	if _is_diving:
		_is_flying = false
		return
	var jump_held := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")
	if jump_held and not is_on_floor():
		_jump_hold_time += delta
	else:
		_jump_hold_time = 0.0
	var hold_to_fly := jump_held and _jump_hold_time >= jump_hold_to_fly_delay and not is_on_floor()
	var fly_pressed := hold_to_fly
	if not fly_pressed:
		_flight_needs_release = false
	_is_flying = fly_pressed and not _flight_needs_release and flight_fuel > 0.0
	if not _is_flying:
		_fly_effect_timer = 0.0
		return

	flight_fuel = maxf(flight_fuel - flight_fuel_per_second * delta, 0.0)
	_flight_fuel_regen_timer = flight_fuel_regen_delay
	if is_zero_approx(flight_fuel):
		_flight_needs_release = true
		_is_flying = false
	velocity.y = move_toward(velocity.y, -flight_lift_speed, FLIGHT_ACCELERATION * delta)
	_fly_effect_timer -= delta
	if _fly_effect_timer <= 0.0:
		_spawn_movement_effect(&"double_jump", Vector2(0.0, 4.0))
		_fly_effect_timer = FLIGHT_GUST_INTERVAL


func _end_flight() -> void:
	_is_flying = false
	_fly_effect_timer = 0.0


func _update_visuals(was_on_floor: bool) -> void:
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		var landed_from_dive := _is_diving
		_finish_air_dive()
		land_sound.play()
		visual_animations.play("landing_squash")
		_spawn_movement_effect(&"land", Vector2.ZERO)
		if landed_from_dive:
			COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, global_position + Vector2(0.0, -4.0))

	if _is_diving:
		sprite.play("air_dive_roll")
		if absf(velocity.x) > 1.0:
			sprite.flip_h = velocity.x < 0.0
		return

	if _is_attacking:
		if sprite.animation == "attack" and sprite.is_playing():
			return
		_is_attacking = false

	if _is_double_jumping:
		if on_floor:
			_is_double_jumping = false
		elif sprite.animation == "double_jump" and sprite.is_playing() and not _is_flying:
			return
		else:
			_is_double_jumping = false

	if _is_flying:
		sprite.play("fly")
	elif not on_floor:
		sprite.play("jump")
	elif absf(velocity.x) > 8.0:
		sprite.play("run")
	else:
		sprite.play("idle")

	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0


func _check_for_fall() -> void:
	if global_position.y > _spawn_position.y + FALL_RESPAWN_DISTANCE:
		take_damage(0.0, true)


func _check_enemy_collisions(was_falling: bool) -> void:
	for index in get_slide_collision_count():
		var collider := get_slide_collision(index).get_collider()
		if not collider.is_in_group("enemy"):
			continue
		if was_falling and global_position.y < collider.global_position.y - 4.0:
			var dived_into_enemy := _is_diving
			collider.stomp()
			var game := get_tree().get_first_node_in_group("game")
			if game != null:
				game.register_stomp()
			if dived_into_enemy:
				COMBAT_EFFECTS.spawn_impact(get_tree().current_scene, collider.global_position)
				_finish_air_dive()
			velocity.y = JUMP_VELOCITY * 0.65
		elif global_position.distance_to(collider.global_position) <= ENEMY_CONTACT_DAMAGE_RADIUS:
			var knockback_direction := -1.0 if global_position.x < collider.global_position.x else 1.0
			take_damage(knockback_direction)
			break


func take_damage(knockback_direction: float = 0.0, respawn_after_hit: bool = false) -> void:
	if _is_dead or _anchor_resting or _hurt_cooldown > 0.0 or _is_dashing or $MagicAbility.is_warded():
		return
	_end_flight()
	_finish_air_dive()
	health = maxi(health - damage_per_hit, 0)
	_hurt_cooldown = 1.2
	hurt_sound.play()
	hit_animation.play("hit_flash")
	var game := get_tree().get_first_node_in_group("game")
	GameEvents.player_hurt.emit()
	if health <= 0:
		_is_dead = true
		_is_attacking = false
		_is_flying = false
		velocity = Vector2.ZERO
		body_collision.set_deferred("disabled", true)
		hit_animation.stop()
		_spawn_death_visual()
		return
	if respawn_after_hit:
		global_position = game.checkpoint if game != null else _spawn_position
		if has_node("Camera2D"):
			$Camera2D.reset_smoothing()
		velocity = Vector2.ZERO
	else:
		if is_zero_approx(knockback_direction):
			knockback_direction = 1.0 if sprite.flip_h else -1.0
		velocity = Vector2(knockback_direction * 165.0, -145.0)


func upgrade_hull() -> void:
	max_health = mini(max_health + 10, 160)
	health = mini(health + 10, max_health)


func restore_mana(amount: float) -> void:
	if amount <= 0.0:
		return
	var overflow := maxf(mana + amount - max_mana, 0.0)
	mana = minf(mana + amount, max_mana)
	mana_reserve = minf(mana_reserve + overflow, max_mana * jump_reserve_bars)
	_mana_regen_timer = 0.0


func restore_flight_fuel(amount: float) -> void:
	if amount <= 0.0:
		return
	var overflow := maxf(flight_fuel + amount - max_flight_fuel, 0.0)
	flight_fuel = minf(flight_fuel + amount, max_flight_fuel)
	flight_fuel_reserve = minf(flight_fuel_reserve + overflow, max_flight_fuel * flight_reserve_bars)
	_flight_fuel_regen_timer = 0.0


func restore_dash_energy(amount: int) -> void:
	if amount <= 0.0:
		return
	dash_energy = mini(dash_energy + amount, max_dash_energy)


func _update_mana(delta: float) -> void:
	if mana <= 0.0 and mana_reserve >= max_mana:
		mana_reserve -= max_mana
		mana = max_mana
	if mana >= max_mana:
		mana = max_mana
		_mana_regen_timer = 0.0
		return
	if _mana_regen_timer > 0.0:
		_mana_regen_timer = maxf(_mana_regen_timer - delta, 0.0)
		return
	mana = minf(mana + mana_regen_per_second * delta, max_mana)


func _update_flight_fuel(delta: float) -> void:
	if flight_fuel <= 0.0 and flight_fuel_reserve >= max_flight_fuel:
		flight_fuel_reserve -= max_flight_fuel
		flight_fuel = max_flight_fuel
	if flight_fuel >= max_flight_fuel:
		flight_fuel = max_flight_fuel
		_flight_fuel_regen_timer = 0.0
		return
	if _flight_fuel_regen_timer > 0.0:
		_flight_fuel_regen_timer = maxf(_flight_fuel_regen_timer - delta, 0.0)
		return
	flight_fuel = minf(flight_fuel + flight_fuel_regen_per_second * delta, max_flight_fuel)


func _handle_attack() -> void:
	if not Input.is_action_just_pressed("attack") or _attack_cooldown > 0.0:
		return
	_attack_cooldown = 0.38
	attack_sound.play()
	var attack_direction := _aim_direction.normalized()
	_is_attacking = true
	sprite.play("attack")
	COMBAT_EFFECTS.spawn_directional_slash(get_tree().current_scene, global_position + attack_direction * 16.0 + Vector2(0.0, -12.0), attack_direction)
	var closest_enemy: Node2D
	var closest_distance := ATTACK_RANGE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var offset: Vector2 = enemy.global_position - global_position
		var forward_distance := offset.dot(attack_direction)
		var side_distance := absf(offset.cross(attack_direction))
		if forward_distance <= 0.0 or forward_distance > closest_distance or side_distance > ATTACK_VERTICAL_RANGE:
			continue
		closest_enemy = enemy
		closest_distance = forward_distance
	if closest_enemy != null:
		closest_enemy.take_hit()

func _handle_magic(delta: float) -> void:
	$MagicAbility.handle_input(_aim_direction, delta)


func _jump_was_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")


func _jump_was_released() -> bool:
	return Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")

extends Node
class_name SwarmDirector
## Owns survival-wave timing, spawn pacing, and off-screen enemy entry.

@export_group("Space Swarm Waves")
@export_range(2.0, 24.0, 1.0) var first_swarm_delay := 5.0
@export_range(3.0, 30.0, 1.0) var swarm_wave_interval := 8.0
@export_range(1, 6, 1) var swarm_base_wave_size := 2
@export_range(4, 20, 1) var swarm_base_enemy_cap := 10
@export_range(30.0, 160.0, 2.0) var swarm_chase_speed := 72.0
@export_range(1, 4, 1) var bat_reinforcement_every_waves := 2
@export_range(2, 12, 1) var bat_reinforcement_cap := 8
@export_range(1, 8, 1) var new_enemy_wave_cap := 4

const SLIME_SCENE: PackedScene = preload("res://scense/slime.tscn")
const STAR_HUNTER_SCENE: PackedScene = preload("res://scense/star_hunter.tscn")
const SURVIVAL_ENEMY_SCENE: PackedScene = preload("res://scense/survival_enemy.tscn")
const SURVIVAL_ENEMY_WAVE_ORDER: Array[int] = [0, 3, 4, 5, 1, 2]

var wave_count := 0
var _game: Node2D
var _swarm_wave_timer := 0.0
var _random := RandomNumberGenerator.new()
var _new_enemy_spawn_count := 0
var _new_survival_spawn_count := 0

func _ready() -> void:
	_game = get_parent() as Node2D

func reset() -> void:
	wave_count = 0
	_new_enemy_spawn_count = 0
	_new_survival_spawn_count = 0
	_swarm_wave_timer = first_swarm_delay
	_random.randomize()

func stop() -> void:
	_swarm_wave_timer = INF

func _ground_surface_y(world_x: float, desired_surface_y: float) -> float:
	if not is_instance_valid(_game):
		return -1.0
	return float(_game.call("ground_surface_y", world_x, desired_surface_y))

func _spawn_enemy(role: int, world_position: Vector2, movement_speed: float, patrol_distance: float) -> CharacterBody2D:
	var enemy := SLIME_SCENE.instantiate() as CharacterBody2D
	enemy.position = world_position
	enemy.speed = movement_speed
	enemy.patrol_distance = patrol_distance
	enemy.enemy_role = role
	_game.add_child(enemy)
	return enemy

func process_waves(delta: float, boss_active: bool) -> void:
	if boss_active:
		return
	_swarm_wave_timer -= delta
	if _swarm_wave_timer > 0.0:
		return
	_swarm_wave_timer = swarm_wave_interval
	_spawn_swarm_wave()

func _spawn_swarm_wave() -> void:
	var player := _game.get_node_or_null("Player") as Node2D
	if player == null:
		return
	var active_count := 0
	for hunter in get_tree().get_nodes_in_group("space_swarm"):
		if is_instance_valid(hunter) and not hunter.is_queued_for_deletion():
			active_count += 1
	var enemy_cap := mini(swarm_base_enemy_cap + wave_count * 2, 24)
	var free_slots := enemy_cap - active_count
	if free_slots <= 0:
		return

	var wave_size := mini(swarm_base_wave_size + floori(float(wave_count) / 3.0), 8)
	wave_size = mini(wave_size, free_slots)
	var view_center := player.global_position
	var half_view := get_viewport().get_visible_rect().size * 0.5
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		half_view /= camera.zoom
		view_center = camera.get_screen_center_position()
	for index in range(wave_size):
		# Place each hunter beyond one camera edge, with enough clearance for its sprite.
		# Use the camera's actual center so this remains correct with camera smoothing.
		var spawn_margin := _random.randf_range(44.0, 76.0)
		var spawn_position: Vector2
		match _random.randi_range(0, 3):
			0:
				spawn_position = Vector2(view_center.x - half_view.x - spawn_margin,
					view_center.y + _random.randf_range(-half_view.y * 0.55, half_view.y * 0.55))
			1:
				spawn_position = Vector2(view_center.x + half_view.x + spawn_margin,
					view_center.y + _random.randf_range(-half_view.y * 0.55, half_view.y * 0.55))
			2:
				spawn_position = Vector2(view_center.x + _random.randf_range(-half_view.x * 0.65, half_view.x * 0.65),
					view_center.y - half_view.y - spawn_margin)
			_:
				spawn_position = Vector2(view_center.x + _random.randf_range(-half_view.x * 0.65, half_view.x * 0.65),
					view_center.y + half_view.y + spawn_margin)
		var hunter := STAR_HUNTER_SCENE.instantiate() as CharacterBody2D
		hunter.chase_speed = swarm_chase_speed + minf(float(wave_count) * 1.5, 24.0)
		_game.add_child(hunter)
		hunter.global_position = spawn_position
	wave_count += 1
	if wave_count % bat_reinforcement_every_waves == 0:
		_spawn_swarm_bat(player, view_center, half_view)
	if wave_count == 1 or wave_count % 2 == 0:
		_spawn_new_enemy_wave(player, view_center, half_view)


func _spawn_swarm_bat(player: Node2D, view_center: Vector2, half_view: Vector2) -> void:
	var active_bats := get_tree().get_nodes_in_group("bat_swarm").size()
	if active_bats >= bat_reinforcement_cap:
		return
	var side := -1.0 if _random.randf() < 0.5 else 1.0
	var spawn_margin := _random.randf_range(56.0, 88.0)
	var spawn_position := Vector2(
		view_center.x + side * (half_view.x + spawn_margin),
		player.global_position.y + _random.randf_range(-38.0, 18.0)
	)
	var bat := SLIME_SCENE.instantiate() as CharacterBody2D
	bat.enemy_role = 1
	bat.speed = 44.0 + minf(float(wave_count) * 1.2, 18.0)
	bat.patrol_distance = absf(player.global_position.x - spawn_position.x) + 180.0
	bat.add_to_group("bat_swarm")
	_game.add_child(bat)
	bat.global_position = spawn_position
	bat.configure_swarm_entry(player.global_position)


func _spawn_new_enemy_wave(player: Node2D, view_center: Vector2, half_view: Vector2) -> void:
	var active_count := 0
	for enemy in get_tree().get_nodes_in_group("approach_enemy"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			active_count += 1
	if active_count >= new_enemy_wave_cap:
		return
	# Introduce the new silhouettes after the first few waves, then rotate through
	# them so players learn each attack before the next one appears.
	if wave_count >= 3:
		if _spawn_survival_enemy(player, view_center, half_view):
			_new_enemy_spawn_count += 1
			return
	# Send reinforcements from ahead of the hero so the player actually meets them.
	# They still enter just outside the camera view, as requested.
	var side := _player_forward_side(player)
	var margin := _random.randf_range(28.0, 44.0)
	var role := 4 if _new_enemy_spawn_count % 2 == 0 else 5
	var spawn_position := Vector2.ZERO
	if role == 4:
		var found_ground := false
		var offsets: Array[float] = [0.0, 16.0, 32.0]
		for offset in offsets:
			var candidate_x: float = view_center.x + side * (half_view.x + margin - offset)
			var surface_y: float = _ground_surface_y(candidate_x, player.global_position.y + 28.0)
			if surface_y >= 0.0:
				spawn_position = Vector2(candidate_x, surface_y)
				found_ground = true
				break
		if not found_ground:
			role = 5
	if role == 5:
		spawn_position = Vector2(
			view_center.x + side * (half_view.x + margin),
			view_center.y + _random.randf_range(-half_view.y * 0.28, half_view.y * 0.28)
		)
	var new_enemy := _spawn_enemy(role, spawn_position, 48.0 + minf(float(wave_count) * 1.2, 18.0), 520.0) as CharacterBody2D
	new_enemy.add_to_group("approach_enemy")
	new_enemy.set_meta("offscreen_reinforcement", true)
	_new_enemy_spawn_count += 1

func _spawn_survival_enemy(player: Node2D, view_center: Vector2, half_view: Vector2) -> bool:
	var kind: int = SURVIVAL_ENEMY_WAVE_ORDER[_new_survival_spawn_count % SURVIVAL_ENEMY_WAVE_ORDER.size()]
	var side := _player_forward_side(player)
	var margin := _random.randf_range(44.0, 68.0)
	var spawn_position := Vector2(
		view_center.x + side * (half_view.x + margin),
		view_center.y + _random.randf_range(-half_view.y * 0.2, half_view.y * 0.2)
	)
	var needs_ground := kind == 1 or kind == 2
	if needs_ground:
		var found_surface := false
		var outward_offsets: Array[float] = [0.0, 24.0, 48.0, 72.0, 96.0]
		for outward_offset in outward_offsets:
			var candidate_x := spawn_position.x + side * outward_offset
			var surface_y := _ground_surface_y(candidate_x, player.global_position.y + 28.0)
			if surface_y < 0.0:
				continue
			spawn_position = Vector2(candidate_x, surface_y)
			found_surface = true
			break
		if not found_surface:
			return false
	var enemy := SURVIVAL_ENEMY_SCENE.instantiate() as CharacterBody2D
	enemy.set("enemy_kind", kind)
	if kind == 0 or kind >= 3:
		enemy.set("chase_speed", 62.0 + minf(float(wave_count) * 1.0, 20.0))
	else:
		enemy.set("chase_speed", 52.0 + minf(float(wave_count) * 0.8, 14.0))
	enemy.add_to_group("approach_enemy")
	enemy.set_meta("offscreen_reinforcement", true)
	_game.add_child(enemy)
	enemy.global_position = spawn_position
	if kind == 0 or kind >= 3:
		enemy.call("configure_swarm_entry", player.global_position)
	_new_survival_spawn_count += 1
	return true

func _player_forward_side(player: Node2D) -> float:
	var body := player as CharacterBody2D
	if body != null and absf(body.velocity.x) > 18.0:
		return signf(body.velocity.x)
	var player_sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if player_sprite != null and player_sprite.flip_h:
		return -1.0
	return 1.0

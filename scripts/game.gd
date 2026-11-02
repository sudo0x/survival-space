extends Node2D

@export_group("Input")
@export var show_touch_controls_on_desktop := false

@export_group("Run Structure")
@export_range(120.0, 900.0, 30.0) var run_duration_seconds := 480.0

const SLIME_SCENE: PackedScene = preload("res://scense/slime.tscn")
const GUARDIAN_SCENE: PackedScene = preload("res://scense/guardian.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scense/pickup.tscn")
const PLATFORM_SCENE: PackedScene = preload("res://scense/platform.tscn")
const BACKDROP_SCENE: PackedScene = preload("res://scense/distant_backdrop.tscn")
const AMBIENT_PROP_SCENE: PackedScene = preload("res://scense/ambient_prop.tscn")
const RELIC_SCENE: PackedScene = preload("res://scense/relic.tscn")
const ISLAND_RAIDER_SCENE: PackedScene = preload("res://scense/island_raider.tscn")
const RUNE_TORTOISE_SCENE: PackedScene = preload("res://scense/rune_tortoise.tscn")
const GAME_OVER_PANEL_SCENE: PackedScene = preload("res://scense/game_over_panel.tscn")
const WORLD_ATLAS: Texture2D = preload("res://assests/sprites/world_tileset.png")
const MENU_FONT: FontFile = preload("res://assests/fonts/PixelOperator8-Bold.ttf")
const KNIGHT_STYLE_SHADER: Shader = preload("res://assests/shaders/knight_style.gdshader")
const CONTROL_SETTINGS = preload("res://scripts/control_settings.gd")
const CHARACTER_STYLES: Dictionary = {
	"classic": [Color(0.039, 0.439, 0.188), Color(0.824, 0.125, 0.173)],
	"moon": [Color(0.035, 0.47, 0.80), Color(0.24, 0.88, 1.0)],
	"jungle": [Color(0.20, 0.60, 0.24), Color(1.0, 0.72, 0.20)],
	"ember": [Color(0.78, 0.20, 0.12), Color(1.0, 0.52, 0.12)],
}
const RELIC_SET_SIZE := 1
const XP_PER_LEVEL := 8

var collected := 0
var coins_collected := 0
var fruit_collected := 0
var checkpoint := Vector2(7, 53)
var game_started := false
var game_finished := false
var time_elapsed := 0.0
var best_survival_score := 0
var sound_enabled := true
var enemies_defeated := 0
var survivor_xp := 0
var survivor_level := 1
@onready var _tutorial_hint: Label = $HUD/TutorialHint
@onready var _swarm_director: SwarmDirector = $SwarmDirector
@onready var _player_health_bar: ProgressBar = $HUD/PlayerHealth/HealthBar
@onready var _player_health_label: Label = $HUD/PlayerHealth/HealthLabel
@onready var _player_mana_bar: ProgressBar = $HUD/PlayerMana/ManaBar
@onready var _player_mana_label: Label = $HUD/PlayerMana/ManaLabel
@onready var _player_flight_bar: ProgressBar = $HUD/PlayerFlight/FlightBar
@onready var _player_flight_label: Label = $HUD/PlayerFlight/FlightLabel
@onready var _magic_style_label: Label = $HUD/MagicStyle
@onready var _xp_bar: ProgressBar = $HUD/PlayerXP/XPBar
@onready var _xp_label: Label = $HUD/PlayerXP/XPLabel
@onready var _boss_health: VBoxContainer = $HUD/BossHealth
@onready var _boss_health_bar: ProgressBar = $HUD/BossHealth/HealthBar
@onready var _upgrade_panel: RunUpgradePanel = $HUD/UpgradePanel
var _tutorial_elapsed := 0.0
var _progress_save_timer := 0.0
var _stomp_combo := 0
var _stomp_combo_timer := 0.0
var collected_relic_ids: Array[String] = []
var _relic_set_rewarded := false
var character_style := "classic"
var _boss_active := false
var _run_won := false
var _frost_intro_drop_given := false
var _show_touch_controls := false
var _run_progress_banked := false
var _last_profile_xp_reward := 0
var _drop_rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_drop_rng.randomize()
	_connect_game_events()
	_show_touch_controls = OS.has_feature("mobile") or show_touch_controls_on_desktop
	$HUD/TouchControls.visible = _show_touch_controls
	_add_distant_backdrop()
	_add_world_scenery()
	_add_later_challenges()
	_add_checkpoint()
	_setup_gameplay_actions()
	_load_preferences()
	_upgrade_panel.upgrade_selected.connect(_on_upgrade_selected)
	_apply_character_style()
	$HUD/InventoryPanel.set_style(character_style, CHARACTER_STYLES[character_style][0], CHARACTER_STYLES[character_style][1])
	_start_survival_run(true)
	var terrain_generator := $SpaceArena.get_node_or_null("TerrainGenerator")
	if terrain_generator != null:
		terrain_generator.call("begin", $Player)
	for marker in $RelicMarkers.get_children():
		var spawn := marker as StageSpawnMarker
		if spawn.spawn_kind == StageSpawnMarker.SpawnKind.RELIC:
			_spawn_relic(spawn.global_position, spawn.relic_id)
	_spawn_marked_content($SpaceArena)
	game_started = true
	get_tree().paused = false
	_update_hud()


func _connect_game_events() -> void:
	_connect_event(GameEvents.enemy_defeated, Callable(self, "enemy_defeated"))
	_connect_event(GameEvents.pickup_collected, Callable(self, "collect_pickup"))
	_connect_event(GameEvents.powerup_collected, Callable(self, "collect_powerup"))
	_connect_event(GameEvents.enemy_drop_collected, Callable(self, "collect_enemy_drop"))
	_connect_event(GameEvents.relic_collected, Callable(self, "collect_relic"))
	_connect_event(GameEvents.player_hurt, Callable(self, "player_hurt"))


func _connect_event(event: Signal, callback: Callable) -> void:
	if not event.is_connected(callback):
		event.connect(callback)

func _add_distant_backdrop() -> void:
	var regional_tints := [
		Color(0.92, 1.0, 0.94),
		Color(1.0, 0.91, 0.70),
		Color(0.74, 0.88, 1.0),
		Color(0.78, 1.0, 0.77),
		Color(0.84, 0.89, 1.0),
	]
	const BACKDROP_TILE_COUNT := 15
	for tile_index in range(BACKDROP_TILE_COUNT):
		var backdrop := BACKDROP_SCENE.instantiate()
		var islands: Sprite2D = backdrop.get_node("Sprite2D")
		backdrop.name = "DistantIslands%d" % tile_index
		# The texture is exactly 768 px wide. Keep each tile at native width and
		# aligned to its neighbor so transparent edges cannot open visible gaps.
		backdrop.position = Vector2(tile_index * 768.0, 40.0)
		islands.scale = Vector2.ONE
		islands.flip_h = tile_index % 2 == 1
		var region_index := mini(int(float(tile_index) * regional_tints.size() / BACKDROP_TILE_COUNT), regional_tints.size() - 1)
		islands.modulate = regional_tints[region_index]
		islands.z_index = -10
		add_child(backdrop)
		backdrop.get_node("AnimationPlayer").seek(0.0, true)

func _process(delta: float) -> void:
	if game_started and not game_finished and not get_tree().paused:
		time_elapsed += delta
		_progress_save_timer += delta
		if _progress_save_timer >= 10.0:
			_progress_save_timer = 0.0
			_save_preferences()
		_tutorial_elapsed += delta
		if not _boss_active and time_elapsed >= run_duration_seconds:
			_start_final_encounter()
		if _stomp_combo_timer > 0.0:
			_stomp_combo_timer = maxf(_stomp_combo_timer - delta, 0.0)
			if _stomp_combo_timer == 0.0:
				_stomp_combo = 0
				$HUD/ComboLabel.visible = false
		_update_hud()
		_swarm_director.process_waves(delta, _boss_active)
		_update_tutorial_hint()

func _setup_gameplay_actions() -> void:
	CONTROL_SETTINGS.apply_saved_bindings()
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	for keycode in [KEY_J, KEY_X]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		if not InputMap.action_has_event("attack", key):
			InputMap.action_add_event("attack", key)
	if not InputMap.has_action("power"):
		InputMap.add_action("power")
	for keycode in [KEY_K]:
		var power_key := InputEventKey.new()
		power_key.physical_keycode = keycode
		if not InputMap.action_has_event("power", power_key):
			InputMap.action_add_event("power", power_key)
	if not InputMap.has_action("magic"):
		InputMap.add_action("magic")
	var magic_key := InputEventKey.new()
	magic_key.physical_keycode = KEY_L
	if not InputMap.action_has_event("magic", magic_key):
		InputMap.action_add_event("magic", magic_key)
	if OS.has_feature("pc"):
		_add_mouse_button_binding("attack", MOUSE_BUTTON_LEFT)
		_add_mouse_button_binding("magic", MOUSE_BUTTON_RIGHT)

func _add_mouse_button_binding(action: StringName, button_index: int) -> void:
	var mouse_button := InputEventMouseButton.new()
	mouse_button.button_index = button_index
	if not InputMap.action_has_event(action, mouse_button):
		InputMap.action_add_event(action, mouse_button)

func _spawn_marked_content(stage_scene: Node2D) -> void:
	for marker in stage_scene.get_node("SpawnPoints").get_children():
		var spawn := marker as StageSpawnMarker
		var spawn_position := spawn.global_position
		match spawn.spawn_kind:
			StageSpawnMarker.SpawnKind.SLIME:
				_spawn_slime(spawn_position, spawn.movement_speed, spawn.patrol_distance, false)
			StageSpawnMarker.SpawnKind.PURPLE_SLIME:
				_spawn_slime(spawn_position, spawn.movement_speed, spawn.patrol_distance, true)
			StageSpawnMarker.SpawnKind.BAT, StageSpawnMarker.SpawnKind.BEETLE, StageSpawnMarker.SpawnKind.WISP:
				_spawn_enemy(spawn.spawn_kind - StageSpawnMarker.SpawnKind.BAT + 1, spawn_position, spawn.movement_speed, spawn.patrol_distance)
			StageSpawnMarker.SpawnKind.ISLAND_RAIDER:
				_spawn_island_raider(spawn_position, spawn.movement_speed, spawn.patrol_distance)
			StageSpawnMarker.SpawnKind.RUNE_TORTOISE:
				_spawn_rune_tortoise(spawn_position, spawn.movement_speed, spawn.patrol_distance)
			StageSpawnMarker.SpawnKind.COIN:
				_spawn_pickup(spawn_position, spawn.treasure_points)
			StageSpawnMarker.SpawnKind.FRUIT:
				_spawn_pickup(spawn_position, spawn.treasure_points, true)
			StageSpawnMarker.SpawnKind.POWERUP:
				_spawn_powerup(spawn_position)
			StageSpawnMarker.SpawnKind.CHECKPOINT:
				_add_checkpoint_at("ArenaCheckpoint", spawn_position)
			StageSpawnMarker.SpawnKind.MOVING_PLATFORM:
				_spawn_moving_platform(spawn_position, spawn_position + spawn.platform_end_offset, spawn.platform_travel_time)
			StageSpawnMarker.SpawnKind.RELIC:
				_spawn_relic(spawn_position, spawn.relic_id)

func _spawn_slime(world_position: Vector2, movement_speed: float, patrol_distance: float, purple: bool) -> void:
	var slime := SLIME_SCENE.instantiate()
	slime.position = world_position
	slime.speed = movement_speed
	slime.patrol_distance = patrol_distance
	if purple:
		slime.purple_variant = true
		slime.pounce_enabled = true
	add_child(slime)

func _spawn_enemy(role: int, world_position: Vector2, movement_speed: float, patrol_distance: float) -> CharacterBody2D:
	var enemy := SLIME_SCENE.instantiate() as CharacterBody2D
	enemy.position = world_position
	enemy.speed = movement_speed
	enemy.patrol_distance = patrol_distance
	enemy.enemy_role = role
	add_child(enemy)
	return enemy

func _spawn_island_raider(world_position: Vector2, movement_speed: float, patrol_distance: float) -> void:
	var raider := ISLAND_RAIDER_SCENE.instantiate()
	raider.position = world_position
	raider.speed = movement_speed
	raider.patrol_distance = patrol_distance
	add_child(raider)

func _spawn_rune_tortoise(world_position: Vector2, movement_speed: float, patrol_distance: float) -> void:
	var tortoise := RUNE_TORTOISE_SCENE.instantiate()
	tortoise.position = world_position
	tortoise.speed = movement_speed
	tortoise.patrol_distance = patrol_distance
	add_child(tortoise)

func _spawn_pickup(world_position: Vector2, points: int, fruit: bool = false) -> void:
	var pickup := PICKUP_SCENE.instantiate()
	pickup.position = world_position
	pickup.points = points
	pickup.pickup_type = 1 if fruit else 0
	add_child(pickup)

func _spawn_powerup(world_position: Vector2) -> void:
	var pickup := PICKUP_SCENE.instantiate()
	pickup.position = world_position
	pickup.pickup_type = 1
	pickup.is_powerup = true
	add_child(pickup)

func _spawn_relic(world_position: Vector2, relic_id: String) -> void:
	if relic_id.is_empty() or has_relic(relic_id):
		return
	var relic := RELIC_SCENE.instantiate()
	relic.position = world_position
	relic.relic_id = relic_id
	add_child(relic)

func _spawn_moving_platform(start_position: Vector2, end_position: Vector2, travel_time: float) -> void:
	var platform := PLATFORM_SCENE.instantiate() as AnimatableBody2D
	platform.position = start_position
	add_child(platform)
	var movement := platform.create_tween().set_loops()
	movement.tween_property(platform, "position", end_position, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movement.tween_property(platform, "position", start_position, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_survival_run(teleport_player: bool) -> void:
	collected = 0
	enemies_defeated = 0
	time_elapsed = 0.0
	survivor_xp = 0
	survivor_level = 1
	_boss_active = false
	_run_won = false
	_boss_health.visible = false
	_upgrade_panel.visible = false
	collected_relic_ids.clear()
	_relic_set_rewarded = false
	_swarm_director.reset()
	_frost_intro_drop_given = false
	_run_progress_banked = false
	_last_profile_xp_reward = 0
	var start_position := Vector2(7, 53)
	if checkpoint.x >= 0.0 and checkpoint.x <= 1800.0:
		start_position = checkpoint
	else:
		checkpoint = start_position
	if teleport_player:
		var player := get_node_or_null("Player")
		if player != null:
			player.reset_for_new_run(start_position)
	_tutorial_elapsed = 0.0
	_update_hud()

func _add_world_scenery() -> void:
	var tree_positions := [90.0, 260.0, 610.0, 910.0, 1280.0, 1450.0]
	for index in range(tree_positions.size()):
		var tree_surface := ground_surface_y(tree_positions[index], 80.0)
		var tree_y := tree_surface - 6.0 if tree_surface >= 0.0 else 74.0
		_add_atlas_prop(Rect2(48, 80, 32, 32), Vector2(tree_positions[index], tree_y), 2.0, -1, "tree_sway", float(index) * 0.24)
	var plant_positions := [170.0, 480.0, 780.0, 1110.0, 1380.0]
	for index in range(plant_positions.size()):
		var plant_surface := ground_surface_y(plant_positions[index], 64.0)
		var plant_y := plant_surface - 19.0 if plant_surface >= 0.0 else 45.0
		_add_atlas_prop(Rect2(0, 48, 16, 32), Vector2(plant_positions[index], plant_y), 2.0, -2, "plant_sway", float(index) * 0.35)

func ground_surface_y(world_x: float, desired_surface_y: float) -> float:
	var stage := get_node_or_null("SpaceArena") as Node2D
	if stage == null:
		return -1.0
	var ground := stage.get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		return -1.0
	var local_probe := ground.to_local(Vector2(world_x, 0.0))
	var cell_x := floori(local_probe.x / 16.0)
	var best_surface := -1.0
	var best_distance := INF
	for cell_y in range(0, 24):
		var cell := Vector2i(cell_x, cell_y)
		if ground.get_cell_source_id(cell) < 0 or ground.get_cell_atlas_coords(cell).y != 0:
			continue
		var local_surface_y := float(cell_y * 16)
		var surface_y := ground.to_global(Vector2(local_probe.x, local_surface_y)).y
		var distance := absf(surface_y - desired_surface_y)
		if distance < best_distance:
			best_surface = surface_y
			best_distance = distance
	return best_surface

func _add_atlas_prop(region: Rect2, world_position: Vector2, sprite_scale: float, depth: int, animation_name: String, phase: float) -> Sprite2D:
	var prop_scene := AMBIENT_PROP_SCENE.instantiate()
	var prop: Sprite2D = prop_scene.get_node("Sprite2D")
	prop.region_enabled = true
	prop.region_rect = region
	prop_scene.position = world_position
	prop.scale = Vector2.ONE * sprite_scale
	prop.z_index = depth
	add_child(prop_scene)
	var animation_player: AnimationPlayer = prop_scene.get_node("AnimationPlayer")
	animation_player.play(animation_name)
	animation_player.seek(fposmod(phase, 1.4), true)
	return prop

func _add_later_challenges() -> void:
	for x in [790.0, 1050.0, 1320.0]:
		var slime := SLIME_SCENE.instantiate()
		slime.position = Vector2(x, 78)
		slime.speed = 38.0 + x / 100.0
		add_child(slime)
	_spawn_enemy(1, Vector2(690, 24), 34.0, 72.0)
	_spawn_enemy(1, Vector2(1370, 4), 42.0, 96.0)
	_spawn_enemy(2, Vector2(1160, 77), 26.0, 26.0)
	var raider_surface := ground_surface_y(1330.0, 80.0)
	if raider_surface >= 0.0:
		_spawn_island_raider(Vector2(1330.0, raider_surface), 45.0, 72.0)
	_spawn_powerup(Vector2(560, 24))
	for x in [675.0, 735.0, 880.0, 1010.0, 1170.0, 1250.0, 1400.0, 1470.0]:
		var pickup := PICKUP_SCENE.instantiate()
		pickup.position = Vector2(x, 35 if int(x) % 2 == 0 else 63)
		add_child(pickup)

func _add_checkpoint() -> void:
	_add_checkpoint_at("Checkpoint", Vector2(960, 42))

func _add_checkpoint_at(checkpoint_name: String, world_position: Vector2) -> void:
	var flag := Area2D.new()
	flag.name = checkpoint_name
	flag.position = world_position
	flag.collision_layer = 0
	flag.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	shape.position.y = -8
	flag.add_child(shape)
	var marker := Sprite2D.new()
	marker.texture = WORLD_ATLAS
	marker.region_enabled = true
	marker.region_rect = Rect2(80, 96, 16, 16)
	marker.scale = Vector2(2.0, 2.0)
	marker.position.y = -12
	flag.add_child(marker)
	flag.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			checkpoint_reached(flag.position + Vector2(0, -20))
	)
	add_child(flag)

func _update_tutorial_hint() -> void:
	if not is_instance_valid(_tutorial_hint):
		return
	var controls_hint := "TAP MAGIC: QUICK SPELL. HOLD: FULL-HEIGHT WIND SWEEP (2.5S COOLDOWN)." if _show_touch_controls else "A/D MOVE. LEFT CLICK HIT. TAP RIGHT CLICK/L: SPELL; HOLD: FULL-HEIGHT WIND SWEEP (2.5S COOLDOWN)."
	var aiming_hint := "AIM HIT WITH THE STICK. MAGIC HOMES TO VISIBLE FOES; OTHERWISE IT FIRES YOUR AIM DIRECTION." if _show_touch_controls else "MOUSE AIMS HIT. MAGIC HOMES TO VISIBLE FOES; OTHERWISE IT FIRES YOUR AIM DIRECTION."
	var dash_hint := "DOUBLE-TAP LEFT/RIGHT OR TAP DASH. EACH DASH USES 1 ENERGY; ENEMY ORBS REFILL IT." if _show_touch_controls else "DOUBLE-TAP A/D OR PRESS K TO DASH. EACH USE SPENDS 1 ENERGY; ORBS REFILL IT."
	var messages: Array[String] = [
		controls_hint,
		"WAVES ARRIVE FROM OUTSIDE YOUR VIEW. KEEP MOVING AND WATCH THE SKY.",
		dash_hint,
		aiming_hint,
		"COLLECT XP. LEVEL UP TO PAUSE AND CHOOSE ONE OF THREE UPGRADES.",
		"AIR JUMPS SPEND MANA AFTER YOUR FREE JUMP. FLIGHT USES ITS OWN FUEL.",
		"HOLD JUMP TO FLY. PRESS I OR PUSH THE STICK DOWN IN AIR TO DIVE-SLAM.",
		"PRESS U / RIFT WHILE AIRBORNE TO PLACE A PERCH. 3 CHARGES; ONE REFILLS EVERY 3 SECONDS. REST ON IT TO RECOVER.",
		"SURVIVE UNTIL THE RIFT OPENS, THEN DEFEAT THE RIFT GUARDIAN TO WIN.",
	]
	if messages.is_empty():
		_tutorial_hint.visible = false
		return
	var step_length := 6.0
	var step := int(floor(_tutorial_elapsed / step_length))
	if step >= messages.size():
		_tutorial_hint.visible = false
	else:
		_tutorial_hint.visible = true
		_tutorial_hint.text = messages[step]

func collect_pickup(amount: int, pickup_type: int = 0) -> void:
	collected += amount
	if pickup_type == 1:
		fruit_collected += 1
	else:
		coins_collected += 1
	$CoinSound.play()
	_update_hud()
	_save_preferences()

func collect_powerup() -> void:
	var player := get_node_or_null("Player")
	if player != null and player.has_method("restore_dash_energy"):
		player.call("restore_dash_energy", 1)
		$HUD/ComboLabel.text = "DASH ENERGY +1"
		$HUD/ComboLabel.visible = true
		$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
		_stomp_combo_timer = 2.2
	_update_hud()

func enemy_defeated(world_position: Vector2) -> void:
	enemies_defeated += 1
	collected += 2
	# Enemy deaths can be reported from a physics collision callback. Defer adding
	# the Area2D pickup until Godot has finished flushing physics queries.
	_spawn_enemy_drop.call_deferred(world_position)
	_update_hud()
	_save_preferences()


func _spawn_enemy_drop(world_position: Vector2) -> void:
	var roll := _drop_rng.randi_range(0, 99)
	# Energy orbs refill both air-jump mana and the dash reserve.
	var is_frost_intro_drop := not _frost_intro_drop_given
	var is_frost_drop := is_frost_intro_drop or roll < 50
	var reward_type := 4 if is_frost_drop else (5 if roll < 70 else (2 if roll < 85 else (4 if roll < 93 else 3)))
	if is_frost_intro_drop:
		_frost_intro_drop_given = true
	var drop := PICKUP_SCENE.instantiate()
	drop.pickup_type = reward_type
	if reward_type == 4:
		if is_frost_drop:
			drop.magic_element = 2
		else:
			drop.magic_element = _drop_rng.randi_range(0, 1)
	elif reward_type == 5:
		var energy_roll := _drop_rng.randi_range(0, 99)
		drop.energy_amount = 10 if energy_roll < 15 else (25 if energy_roll < 45 else (50 if energy_roll < 80 else (75 if energy_roll < 95 else 100)))
	drop.position = world_position + Vector2(_drop_rng.randf_range(-8.0, 8.0), -8.0)
	add_child(drop)


func collect_enemy_drop(reward_type: int, magic_element: int = 0, energy_amount: int = 0) -> void:
	var player := get_node_or_null("Player")
	match reward_type:
		2:
			_grant_experience(1)
			$CoinSound.play()
		4:
			if player != null and player.has_method("restore_mana"):
				player.call("restore_mana", 40.0)
			if player != null and player.has_method("restore_flight_fuel"):
				player.call("restore_flight_fuel", 40.0)
			var magic_ability: Node = player.get_node_or_null("MagicAbility") if player != null else null
			if magic_ability != null:
				magic_ability.call("grant_magic_style", magic_element)
				$HUD/ComboLabel.text = String(magic_ability.call("get_spell_style_label")).replace("SPELL:", "MAGIC:")
				if magic_element == 2:
					$HUD/ComboLabel.text += " / FREEZES 3 FOES"
				$HUD/ComboLabel.visible = true
				$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
				_stomp_combo_timer = 2.2
		5:
			var dash_energy_gain := maxi(1, roundi(float(energy_amount) / 20.0))
			if player != null and player.has_method("restore_mana"):
				player.call("restore_mana", energy_amount)
			if player != null and player.has_method("restore_dash_energy"):
				player.call("restore_dash_energy", dash_energy_gain)
			if player != null:
				$HUD/ComboLabel.text = "ORB +%d MANA / +%d DASH" % [energy_amount, dash_energy_gain]
				$HUD/ComboLabel.visible = true
				$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
				_stomp_combo_timer = 2.2
			$CoinSound.play()
		3:
			if player != null and int(player.get("health")) < int(player.get("max_health")):
				player.set("health", mini(int(player.get("health")) + 10, int(player.get("max_health"))))
				$CoinSound.play()
			else:
				collected += 2
	_update_hud()
	_save_preferences()


func _grant_experience(amount: int) -> void:
	survivor_xp += amount
	if survivor_xp < XP_PER_LEVEL:
		return
	survivor_xp -= XP_PER_LEVEL
	survivor_level += 1
	_show_upgrade_choices()


func _show_upgrade_choices() -> void:
	var choices: Array[Dictionary] = [
		{"id": "hull", "title": "REINFORCED HULL", "description": "+10 maximum health and repair 10 health."},
		{"id": "dash", "title": "DASH CELLS", "description": "+4 maximum dash energy and refill 4 cells."},
		{"id": "chain", "title": "CHAIN CONDUIT", "description": "+1 lightning target and a wider chain radius."},
		{"id": "rapid", "title": "RAPID FOCUS", "description": "Cast quick magic more often."},
	]
	choices.shuffle()
	var offered: Array[Dictionary] = []
	for index in range(3):
		offered.append(choices[index])
	_set_gameplay_hud_visible(false)
	_upgrade_panel.present_choices(offered, survivor_level)
	get_tree().paused = true


func _on_upgrade_selected(upgrade_id: String) -> void:
	var player := get_node_or_null("Player")
	var magic: Node = player.get_node_or_null("MagicAbility") if player != null else null
	match upgrade_id:
		"hull":
			if player != null and player.has_method("upgrade_hull"):
				player.call("upgrade_hull")
		"dash":
			if player != null:
				var new_max := mini(int(player.get("max_dash_energy")) + 4, 32)
				player.set("max_dash_energy", new_max)
				player.call("restore_dash_energy", 4)
		"chain":
			if magic != null:
				magic.set("chained_enemies", mini(int(magic.get("chained_enemies")) + 1, 5))
				magic.set("chain_radius", minf(float(magic.get("chain_radius")) + 24.0, 240.0))
		"rapid":
			if magic != null:
				magic.set("quick_cooldown_seconds", maxf(float(magic.get("quick_cooldown_seconds")) - 0.04, 0.12))
		_:
			return
	_upgrade_panel.visible = false
	_set_gameplay_hud_visible(true)
	get_tree().paused = false
	_update_hud()
	$HUD/ComboLabel.text = "UPGRADE INSTALLED"
	$HUD/ComboLabel.visible = true
	$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
	_stomp_combo_timer = 1.8


func _start_final_encounter() -> void:
	_boss_active = true
	_swarm_director.stop()
	$HUD/TutorialHint.text = "THE RIFT IS OPEN. DEFEAT THE GUARDIAN TO SEAL IT!"
	$HUD/TutorialHint.visible = true
	$HUD/ComboLabel.text = "RIFT BREACH!  GUARDIAN APPROACHING"
	$HUD/ComboLabel.visible = true
	$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
	_stomp_combo_timer = 3.0
	var guardian := GUARDIAN_SCENE.instantiate() as CharacterBody2D
	guardian.set("max_health", 24)
	guardian.connect("health_changed", Callable(self, "_on_final_guardian_health_changed"))
	guardian.connect("defeated", Callable(self, "_on_final_guardian_defeated"))
	var player := get_node_or_null("Player") as Node2D
	var camera := get_viewport().get_camera_2d()
	var camera_center := player.global_position if player != null else Vector2.ZERO
	var half_view := get_viewport_rect().size * 0.5
	if camera != null:
		camera_center = camera.get_screen_center_position()
		half_view /= camera.zoom
	add_child(guardian)
	guardian.global_position = Vector2(camera_center.x + half_view.x + 18.0, player.global_position.y - 10.0 if player != null else camera_center.y)
	guardian.call("set_encounter_origin")
	$HUD/BossHealth/BossName.text = "RIFT GUARDIAN  /  24"
	_boss_health_bar.max_value = 24.0
	_boss_health_bar.value = 24.0
	_boss_health.visible = true
	_update_hud()


func _on_final_guardian_health_changed(current_health: int, total_health: int) -> void:
	_boss_health_bar.max_value = total_health
	_boss_health_bar.value = current_health
	$HUD/BossHealth/BossName.text = "RIFT GUARDIAN  /  %d" % current_health


func _on_final_guardian_defeated() -> void:
	if _run_won:
		return
	_run_won = true
	await get_tree().create_timer(0.4).timeout
	if game_finished:
		return
	enemies_defeated += 1
	collected += 50
	game_started = false
	game_finished = true
	best_survival_score = maxi(best_survival_score, collected)
	_bank_run_progress()
	_save_preferences()
	_update_hud()
	_show_end_run_panel(true)

func register_stomp() -> void:
	_stomp_combo = mini(_stomp_combo + 1, 4) if _stomp_combo_timer > 0.0 else 1
	_stomp_combo_timer = 2.0
	var bonus := maxi(_stomp_combo - 1, 0) * 2
	var combo_label: Label = $HUD/ComboLabel
	combo_label.text = "STOMP x%d!  +%d TREASURE" % [_stomp_combo, bonus] if _stomp_combo > 1 else "STOMP!"
	combo_label.visible = true
	combo_label.scale = Vector2.ONE
	$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
	if bonus > 0:
		collected += bonus
		$CoinSound.play()
		_update_hud()
		_save_preferences()

func _update_hud() -> void:
	var player := get_node_or_null("Player")
	var max_health: int = int(player.get("max_health")) if player != null else 100
	var current_health := _player_health()
	var phase_text := "RIFT GUARDIAN" if _boss_active else "RIFT IN %02d:%02d" % [floori(maxf(run_duration_seconds - time_elapsed, 0.0) / 60.0), int(maxf(run_duration_seconds - time_elapsed, 0.0)) % 60]
	var perch_charges := int(player.get("rift_perch_charges")) if player != null else 3
	var perch_status := "PERCH %d/3" % perch_charges
	if perch_charges < 3 and player != null:
		perch_status += " +%ds" % ceili(maxf(float(player.get("_anchor_cooldown")), 0.0))
	$HUD/Status.text = "WAVE %02d   ♥ %d   SCORE %04d   KILLS %03d   %s   %s" % [maxi(_swarm_director.wave_count, 1), current_health, collected, enemies_defeated, phase_text, perch_status]
	$HUD/TouchControls/Anchor.text = "RIFT %d/3" % perch_charges
	_player_health_bar.max_value = max_health
	_player_health_bar.value = current_health
	_player_health_label.text = "HP %d/%d" % [current_health, max_health]
	var max_mana := float(player.get("max_mana")) if player != null else 100.0
	var current_mana := float(player.get("mana")) if player != null else max_mana
	var stored_mana := float(player.get("mana_reserve")) if player != null else 0.0
	_player_mana_bar.max_value = max_mana
	_player_mana_bar.value = current_mana
	_player_mana_label.text = "MANA %d/%d B%d" % [roundi(current_mana), roundi(max_mana), roundi(stored_mana)]
	var max_flight_fuel := float(player.get("max_flight_fuel")) if player != null else 100.0
	var current_flight_fuel := float(player.get("flight_fuel")) if player != null else max_flight_fuel
	var stored_flight_fuel := float(player.get("flight_fuel_reserve")) if player != null else 0.0
	_player_flight_bar.max_value = max_flight_fuel
	_player_flight_bar.value = current_flight_fuel
	_player_flight_label.text = "FLY %d/%d B%d" % [roundi(current_flight_fuel), roundi(max_flight_fuel), roundi(stored_flight_fuel)]
	var max_dash_energy := int(player.get("max_dash_energy")) if player != null else 20
	var current_dash_energy := int(player.get("dash_energy")) if player != null else max_dash_energy
	var dash_cooldown := float(player.get("_dash_cooldown")) if player != null else 0.0
	var dash_cooldown_text := "READY" if dash_cooldown <= 0.0 else "%0.1fs" % dash_cooldown
	$HUD/PlayerDash/DashBar.max_value = max_dash_energy
	$HUD/PlayerDash/DashBar.value = current_dash_energy
	$HUD/PlayerDash/DashLabel.text = "DASH %d/%d  CD %s" % [current_dash_energy, max_dash_energy, dash_cooldown_text]
	var magic_ability: Node = player.get_node_or_null("MagicAbility") if player != null else null
	_magic_style_label.text = String(magic_ability.call("get_spell_style_label")) if magic_ability != null else "SPELL: ARCANE"
	if magic_ability != null and magic_ability.has_method("get_wind_status_label"):
		_magic_style_label.text += "  " + String(magic_ability.call("get_wind_status_label"))
	_magic_style_label.add_theme_color_override("font_color", magic_ability.call("get_spell_style_color") if magic_ability != null else Color(0.32, 0.82, 1.0))
	_xp_bar.max_value = XP_PER_LEVEL
	_xp_bar.value = survivor_xp
	_xp_label.text = "LV %d  XP %d/%d" % [survivor_level, survivor_xp, XP_PER_LEVEL]
	$HUD/InventoryPanel.set_contents(coins_collected, fruit_collected, collected_relic_ids.size(), current_dash_energy, max_dash_energy)

func has_relic(relic_id: String) -> bool:
	return collected_relic_ids.has(relic_id)

func collect_relic(relic_id: String) -> void:
	if relic_id.is_empty() or has_relic(relic_id):
		return
	collected_relic_ids.append(relic_id)
	collected += 8
	$CoinSound.play()
	if collected_relic_ids.size() >= RELIC_SET_SIZE and not _relic_set_rewarded:
		_relic_set_rewarded = true
		collected += 25
		$HUD/ComboLabel.text = "RELIC SET COMPLETE!  +25 TREASURE"
		$HUD/ComboLabel.visible = true
		$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
	else:
		$HUD/ComboLabel.text = "ANCIENT RELIC FOUND!  +8 TREASURE"
		$HUD/ComboLabel.visible = true
		$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
	_update_hud()
	_save_preferences()

func _unhandled_input(event: InputEvent) -> void:
	if _upgrade_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and game_started and not game_finished:
		get_viewport().set_input_as_handled()
		if $HUD/InventoryPanel.visible:
			close_inventory()
		elif get_tree().paused:
			get_tree().paused = false
		else:
			_show_menu("PAUSED", "Take a breath, adventurer.", "RESUME")


func open_pause_menu() -> void:
	if game_finished or get_tree().paused:
		return
	_show_menu("PAUSED", "Your survival run is paused.", "RESUME")


func show_anchor_message() -> void:
	if not is_instance_valid($HUD/ComboLabel):
		return
	var label: Label = $HUD/ComboLabel
	var player := get_node_or_null("Player")
	var charges := int(player.get("rift_perch_charges")) if player != null else 0
	var message := "RIFT PERCH PLACED  /  %d CHARGES LEFT" % charges
	label.text = message
	label.visible = true
	$HUD/ComboLabel/ComboAnimationPlayer.play("combo_pop")
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(label) and label.text == message:
			label.visible = false
	)

func _input(event: InputEvent) -> void:
	if game_started or not get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_on_overlay_button()

func _show_menu(title_text: String, message: String, button_text: String) -> void:
	get_tree().paused = true
	_set_gameplay_hud_visible(false)
	var overlay := Control.new()
	overlay.name = "GameOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.022, 0.045, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var viewport_size := get_viewport_rect().size
	var panel_width := minf(500.0, viewport_size.x - 40.0)
	var panel_height := 450.0 if title_text == "PAUSED" else 314.0
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.042, 0.075, 0.99)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.30, 0.60, 0.78, 1.0)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 24.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)
	var stack := VBoxContainer.new()
	stack.process_mode = Node.PROCESS_MODE_ALWAYS
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 11)
	panel.add_child(stack)
	var eyebrow := Label.new()
	eyebrow.text = "SURVIVAL SPACE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", MENU_FONT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.47, 0.75, 0.88))
	stack.add_child(eyebrow)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", MENU_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	stack.add_child(title)
	var details := Label.new()
	details.text = message
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_theme_font_size_override("font_size", 16)
	details.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98))
	stack.add_child(details)
	if game_finished:
		var run_summary := Label.new()
		run_summary.text = "WAVE %02d     •     SURVIVED %d:%02d" % [maxi(_swarm_director.wave_count, 1), floori(time_elapsed / 60.0), int(time_elapsed) % 60]
		run_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		run_summary.add_theme_font_override("font", MENU_FONT)
		run_summary.add_theme_font_size_override("font_size", 13)
		run_summary.add_theme_color_override("font_color", Color(0.62, 0.80, 0.90))
		stack.add_child(run_summary)
	var button := Button.new()
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.text = "RETRY ADVENTURE" if game_finished else button_text
	button.custom_minimum_size = Vector2(panel_width - 56.0, 54.0)
	_style_overlay_button(button, true)
	button.pressed.connect(_on_overlay_button)
	stack.add_child(button)
	var sound_button := Button.new()
	sound_button.text = "SOUND: ON" if sound_enabled else "SOUND: OFF"
	sound_button.custom_minimum_size = Vector2(panel_width - 56.0, 40.0)
	_style_overlay_button(sound_button, false)
	sound_button.pressed.connect(_toggle_sound.bind(sound_button))
	stack.add_child(sound_button)
	if game_started and not game_finished:
		var home_button := Button.new()
		home_button.text = "RETURN TO HOME"
		home_button.custom_minimum_size = Vector2(panel_width - 56.0, 40.0)
		_style_overlay_button(home_button, false)
		home_button.pressed.connect(_return_to_home)
		stack.add_child(home_button)
		var restart := Button.new()
		restart.text = "RESTART"
		_style_overlay_button(restart, false)
		restart.pressed.connect(func(): get_tree().reload_current_scene())
		stack.add_child(restart)
	var input_hint := Label.new()
	input_hint.text = "ENTER TO CONTINUE"
	input_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_hint.add_theme_font_override("font", MENU_FONT)
	input_hint.add_theme_font_size_override("font_size", 10)
	input_hint.add_theme_color_override("font_color", Color(0.53, 0.65, 0.77))
	stack.add_child(input_hint)

func _show_game_over_panel() -> void:
	_show_end_run_panel(false)


func _show_end_run_panel(is_victory: bool) -> void:
	get_tree().paused = true
	_set_gameplay_hud_visible(false)
	var game_over := GAME_OVER_PANEL_SCENE.instantiate() as GameOverPanel
	$HUD.add_child(game_over)
	game_over.set_run_summary(maxi(_swarm_director.wave_count, 1), collected, survivor_level, enemies_defeated, best_survival_score, sound_enabled, is_victory)
	game_over.retry_requested.connect(_on_overlay_button)
	game_over.home_requested.connect(_return_to_home)
	game_over.sound_toggled.connect(_set_sound_enabled)
	game_over.set_profile_reward(_last_profile_xp_reward)


func _return_to_home() -> void:
	if game_started and not game_finished:
		best_survival_score = maxi(best_survival_score, collected)
		_bank_run_progress()
	get_tree().paused = false
	_save_preferences()
	get_tree().change_scene_to_file("res://scense/main_menu.tscn")


func _bank_run_progress() -> void:
	if _run_progress_banked:
		return
	_run_progress_banked = true
	var config := ConfigFile.new()
	config.load("user://island_game.cfg")
	var profile_level := maxi(int(config.get_value("profile", "level", 1)), 1)
	var profile_xp := maxi(int(config.get_value("profile", "xp", 0)), 0)
	_last_profile_xp_reward = 20 + maxi(floori(time_elapsed / 12.0), 0) + enemies_defeated + survivor_level * 5
	profile_xp += _last_profile_xp_reward
	var xp_to_next_level := 100 + (profile_level - 1) * 50
	while profile_xp >= xp_to_next_level:
		profile_xp -= xp_to_next_level
		profile_level += 1
		xp_to_next_level = 100 + (profile_level - 1) * 50
	config.set_value("profile", "level", profile_level)
	config.set_value("profile", "xp", profile_xp)
	var best_wave := int(config.get_value("progress", "best_wave", 0))
	config.set_value("progress", "best_wave", maxi(best_wave, _swarm_director.wave_count))
	config.save("user://island_game.cfg")


func _set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	AudioServer.set_bus_mute(0, not sound_enabled)
	_save_preferences()

func _style_overlay_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 15 if primary else 12)
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	var accent := Color(0.91, 0.70, 0.30) if primary else Color(0.31, 0.53, 0.68)
	normal.bg_color = Color(0.09, 0.17, 0.25, 1.0) if primary else Color(0.035, 0.065, 0.10, 1.0)
	hover.bg_color = Color(0.13, 0.25, 0.34, 1.0) if primary else Color(0.07, 0.12, 0.17, 1.0)
	pressed.bg_color = Color(0.06, 0.12, 0.19, 1.0)
	for style in [normal, hover, pressed]:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = accent
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55) if primary else Color(0.74, 0.86, 0.96))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.74))
	button.add_theme_color_override("font_pressed_color", Color(0.84, 0.92, 1.0))

func _set_gameplay_hud_visible(should_be_visible: bool) -> void:
	$HUD/TouchControls.visible = should_be_visible and _show_touch_controls
	$HUD/Status.visible = should_be_visible
	$HUD/PlayerHealth.visible = should_be_visible
	$HUD/PlayerMana.visible = should_be_visible
	$HUD/PlayerFlight.visible = should_be_visible
	$HUD/PlayerDash.visible = should_be_visible
	$HUD/MagicStyle.visible = should_be_visible
	$HUD/PlayerXP.visible = should_be_visible
	$HUD/TutorialHint.visible = should_be_visible and _tutorial_elapsed < 18.0
	$HUD/ComboLabel.visible = should_be_visible and _stomp_combo_timer > 0.0
	_boss_health.visible = should_be_visible and _boss_active and not game_finished
	$HUD/Controls.visible = false

func _on_overlay_button() -> void:
	if game_finished:
		get_tree().reload_current_scene()
		return
	game_started = true
	_set_gameplay_hud_visible(true)
	get_tree().paused = false
	$HUD/GameOverlay.queue_free()

func _toggle_sound(button: Button) -> void:
	sound_enabled = not sound_enabled
	AudioServer.set_bus_mute(0, not sound_enabled)
	button.text = "SOUND: ON" if sound_enabled else "SOUND: OFF"
	_save_preferences()

func toggle_inventory() -> void:
	if game_finished:
		return
	if $HUD/InventoryPanel.visible:
		close_inventory()
		return
	var player := get_node_or_null("Player")
	var dash_energy := int(player.get("dash_energy")) if player != null else 0
	var max_dash_energy := int(player.get("max_dash_energy")) if player != null else 20
	$HUD/InventoryPanel.set_contents(coins_collected, fruit_collected, collected_relic_ids.size(), dash_energy, max_dash_energy)
	$HUD/InventoryPanel.set_style(character_style, CHARACTER_STYLES[character_style][0], CHARACTER_STYLES[character_style][1])
	$HUD/InventoryPanel.show()
	get_tree().paused = true

func close_inventory() -> void:
	$HUD/InventoryPanel.hide()
	get_tree().paused = false

func select_character_style(style_id: String) -> void:
	if not CHARACTER_STYLES.has(style_id):
		return
	character_style = style_id
	_apply_character_style()
	$HUD/InventoryPanel.set_style(character_style, CHARACTER_STYLES[character_style][0], CHARACTER_STYLES[character_style][1])
	_save_preferences()

func _apply_character_style() -> void:
	if not CHARACTER_STYLES.has(character_style):
		character_style = "classic"
	var palette: Array = CHARACTER_STYLES[character_style]
	var style_material := ShaderMaterial.new()
	style_material.shader = KNIGHT_STYLE_SHADER
	style_material.set_shader_parameter("tunic_color", palette[0])
	style_material.set_shader_parameter("plume_color", palette[1])
	var player_sprite := get_node_or_null("Player/AnimatedSprite2D") as AnimatedSprite2D
	if player_sprite != null:
		player_sprite.material = style_material

func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load("user://island_game.cfg") == OK:
		best_survival_score = int(config.get_value("progress", "best_score", config.get_value("progress", "best_treasures", 0)))
		coins_collected = int(config.get_value("inventory", "coins", 0))
		fruit_collected = int(config.get_value("inventory", "fruit", 0))
		character_style = String(config.get_value("appearance", "character_style", "classic"))
		var player := get_node_or_null("Player")
		if player != null:
			player.set("mana_reserve", clampf(float(config.get_value("inventory", "mana_reserve", 0.0)), 0.0, float(player.get("max_mana")) * int(player.get("jump_reserve_bars"))))
			player.set("flight_fuel_reserve", clampf(float(config.get_value("inventory", "flight_fuel_reserve", 0.0)), 0.0, float(player.get("max_flight_fuel")) * int(player.get("flight_reserve_bars"))))
		var saved_checkpoint := Vector2(float(config.get_value("progress", "checkpoint_x", 7.0)), float(config.get_value("progress", "checkpoint_y", 53.0)))
		checkpoint = saved_checkpoint if saved_checkpoint.x >= 0.0 and saved_checkpoint.x <= 1800.0 else Vector2(7, 53)
		sound_enabled = bool(config.get_value("settings", "sound", true))
	AudioServer.set_bus_mute(0, not sound_enabled)

func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.load("user://island_game.cfg")
	config.set_value("progress", "best_score", best_survival_score)
	config.set_value("inventory", "coins", coins_collected)
	config.set_value("inventory", "fruit", fruit_collected)
	config.set_value("appearance", "character_style", character_style)
	var player := get_node_or_null("Player")
	if player != null:
		config.set_value("inventory", "mana_reserve", float(player.get("mana_reserve")))
		config.set_value("inventory", "flight_fuel_reserve", float(player.get("flight_fuel_reserve")))
	config.set_value("progress", "checkpoint_x", checkpoint.x)
	config.set_value("progress", "checkpoint_y", checkpoint.y)
	config.set_value("settings", "sound", sound_enabled)
	config.save("user://island_game.cfg")

func _player_health() -> int:
	var player := get_node_or_null("Player")
	return player.health if player != null else 100

func checkpoint_reached(safe_position: Vector2) -> void:
	checkpoint = safe_position
	$HUD/Status.text = "CHECKPOINT REACHED!"
	_save_preferences()

func player_hurt() -> void:
	_stomp_combo = 0
	_stomp_combo_timer = 0.0
	$HUD/ComboLabel.visible = false
	_update_hud()

func player_death_animation_finished() -> void:
	if game_finished:
		return
	game_started = false
	game_finished = true
	best_survival_score = maxi(best_survival_score, collected)
	_bank_run_progress()
	_save_preferences()
	_show_game_over_panel()

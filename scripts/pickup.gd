extends Area2D

const REWARD_FRAMES: SpriteFrames = preload("res://assests/sprites/reward_pickup_frames.tres")
const RIFT_LIGHTNING_FRAMES: SpriteFrames = preload("res://assests/sprites/rift_lightning_frames.tres")
const STAR_BOLT_FRAMES: SpriteFrames = preload("res://assests/sprites/star_bolt_frames.tres")
const FROST_FRAMES: SpriteFrames = preload("res://assests/sprites/frost_spell_frames.tres")
const JUMP_ENERGY_FRAMES: SpriteFrames = preload("res://assests/sprites/jump_energy_orb_frames.tres")

@export var points := 1
@export_enum("Coin", "Fruit", "Experience", "Health", "Magic", "Energy Orb") var pickup_type := 0
@export var is_powerup := false
@export_enum("Rift Lightning", "Star Bolt", "Frost Shard") var magic_element := 0
@export_range(10, 100, 5) var energy_amount := 50
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const MAGIC_MAGNET_RADIUS := 48.0
const MAGIC_MAGNET_SPEED := 220.0

func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Special drops sit above the terrain so they remain easy to spot.
	if pickup_type >= 2:
		z_index = 12
	if pickup_type >= 2:
		if pickup_type == 4:
			match magic_element:
				0:
					sprite.sprite_frames = RIFT_LIGHTNING_FRAMES
					sprite.scale = Vector2(0.03, 0.03)
				1:
					sprite.sprite_frames = STAR_BOLT_FRAMES
					sprite.scale = Vector2(0.03, 0.03)
				_:
					# Reuse the Frost spell's impact art as its drop icon.
					sprite.sprite_frames = FROST_FRAMES
					sprite.animation = &"impact"
					sprite.frame = 2
					sprite.stop()
					sprite.scale = Vector2(0.8, 0.8)
		elif pickup_type == 5:
			sprite.sprite_frames = JUMP_ENERGY_FRAMES
			sprite.scale = Vector2(0.05, 0.05)
		else:
			sprite.sprite_frames = REWARD_FRAMES
			sprite.scale = Vector2(0.05, 0.05)
		match pickup_type:
			2:
				sprite.play("experience")
			3:
				sprite.play("health")
			4:
				if magic_element == 2:
					# Frost drops use a held impact frame as their pickup icon.
					sprite.stop()
				else:
					sprite.play("flight")
			5:
				sprite.play("orb")
	else:
		sprite.play("fruit" if pickup_type == 1 else "coin")
	if is_powerup:
		sprite.modulate = Color(0.45, 1.0, 1.0)
	body_entered.connect(_on_body_entered)
	if pickup_type == 4:
		monitoring = false
		get_tree().create_timer(0.65).timeout.connect(_arm_magic_drop)
	if pickup_type >= 2:
		get_tree().create_timer(18.0).timeout.connect(queue_free)


func _process(delta: float) -> void:
	if pickup_type != 4 and pickup_type != 5:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not monitoring:
		return
	var magnet_radius := 18.0 if pickup_type == 4 and magic_element == 2 else MAGIC_MAGNET_RADIUS
	if global_position.distance_to(player.global_position) <= magnet_radius:
		global_position = global_position.move_toward(player.global_position + Vector2(0.0, -4.0), MAGIC_MAGNET_SPEED * delta)


func _arm_magic_drop() -> void:
	if is_inside_tree():
		monitoring = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if pickup_type >= 2:
			GameEvents.enemy_drop_collected.emit(pickup_type, magic_element, energy_amount)
		elif is_powerup:
			GameEvents.powerup_collected.emit()
		else:
			GameEvents.pickup_collected.emit(points, pickup_type)
		queue_free()

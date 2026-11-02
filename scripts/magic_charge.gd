extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arcane_light: PointLight2D = $ArcaneLight

var _charge_level := 0.0
var _flicker_clock := 0.0
var spell_color := Color(0.32, 0.82, 1.0)
var spell_frames: SpriteFrames


func _ready() -> void:
	sprite.play("flight")
	set_charge(0.0)


func _process(delta: float) -> void:
	_flicker_clock += delta
	arcane_light.energy = lerpf(0.45, 1.2, _charge_level) + sin(_flicker_clock * 24.0) * 0.08


func set_charge(progress: float) -> void:
	_charge_level = clampf(progress, 0.0, 1.0)
	var orb_scale := lerpf(0.027, 0.05, _charge_level)
	sprite.scale = Vector2.ONE * orb_scale
	arcane_light.texture_scale = lerpf(0.24, 0.4, _charge_level)


func set_spell_color(color: Color) -> void:
	spell_color = color
	sprite.modulate = Color.WHITE if spell_frames != null else spell_color
	arcane_light.color = spell_color


func set_spell_frames(frames: SpriteFrames) -> void:
	if spell_frames == frames:
		return
	spell_frames = frames
	sprite.sprite_frames = spell_frames
	sprite.modulate = Color.WHITE
	sprite.play("flight")

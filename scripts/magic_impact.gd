extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light: PointLight2D = $ArcaneLight
var spell_color := Color(0.32, 0.82, 1.0)
var spell_frames: SpriteFrames

func set_spell_color(color: Color) -> void:
	spell_color = color
	if is_node_ready():
		sprite.modulate = Color.WHITE if spell_frames != null else spell_color
		light.color = spell_color

func set_spell_frames(frames: SpriteFrames) -> void:
	spell_frames = frames
	if is_node_ready() and spell_frames != null:
		sprite.sprite_frames = spell_frames
		_fit_small_spell_frames()
		sprite.modulate = Color.WHITE
		sprite.play("impact")

func _ready() -> void:
	if spell_frames != null:
		sprite.sprite_frames = spell_frames
		_fit_small_spell_frames()
	sprite.modulate = Color.WHITE if spell_frames != null else spell_color
	light.color = spell_color
	sprite.animation_finished.connect(queue_free)
	sprite.play("impact")
	if _uses_compact_spell_art():
		# Give Frost hits a visible icy pop, then settle back to the normal size.
		var settled_scale := sprite.scale
		sprite.scale = settled_scale * 0.62
		var impact_pop := create_tween()
		impact_pop.tween_property(sprite, "scale", settled_scale * 1.14, 0.09)
		impact_pop.tween_property(sprite, "scale", settled_scale, 0.14)
	var light_fade := create_tween()
	light_fade.tween_property(light, "energy", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fit_small_spell_frames() -> void:
	if not spell_frames.has_animation("impact"):
		return
	var frame_texture := spell_frames.get_frame_texture("impact", 0)
	if frame_texture != null and frame_texture.get_width() <= 64:
		# Keep the Frost burst clear while leaving the target visible.
		sprite.scale = Vector2(0.42, 0.42)


func _uses_compact_spell_art() -> bool:
	if spell_frames == null or not spell_frames.has_animation("impact"):
		return false
	var frame_texture := spell_frames.get_frame_texture("impact", 0)
	return frame_texture != null and frame_texture.get_width() <= 64

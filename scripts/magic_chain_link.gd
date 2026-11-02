extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func play_between(start_position: Vector2, end_position: Vector2, _spell_color: Color = Color(0.32, 0.82, 1.0)) -> void:
	var offset := end_position - start_position
	var distance := offset.length()
	if distance < 1.0:
		queue_free()
		return

	global_position = start_position
	global_rotation = offset.angle()
	sprite.position = Vector2(distance * 0.5, 0.0)
	# The atlas frame is 543 px wide; scale it to bridge any enemy gap.
	sprite.scale = Vector2(distance / 543.0, 0.11)
	sprite.modulate = Color.WHITE
	sprite.play("crackle")

	var fade := create_tween()
	fade.tween_property(sprite, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.finished.connect(queue_free)

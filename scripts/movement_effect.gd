extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func play_effect(animation_name: StringName, facing: float = 1.0) -> void:
	sprite.flip_h = facing < 0.0
	sprite.play(animation_name)
	sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)

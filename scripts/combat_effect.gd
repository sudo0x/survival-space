extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.animation_finished.connect(queue_free)

func play_effect(animation_name: StringName, facing: float = 1.0) -> void:
	sprite.flip_h = facing < 0.0
	sprite.play(animation_name)

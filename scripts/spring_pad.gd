extends Area2D

@export var launch_speed := 570.0

@onready var animator: AnimationPlayer = $AnimationPlayer

var _launch_locked := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	animator.animation_finished.connect(_on_animation_finished)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _launch_locked:
		return
	if body is CharacterBody2D and body.velocity.y < -12.0:
		return

	_launch_locked = true
	animator.play("launch_sequence")
	if body.has_method("bounce_from_spring"):
		body.bounce_from_spring(launch_speed)
	elif body is CharacterBody2D:
		body.velocity.y = -launch_speed
	await get_tree().create_timer(0.32).timeout
	_launch_locked = false


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"launch_sequence":
		animator.play("idle_breathe")

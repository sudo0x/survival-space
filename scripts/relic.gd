extends Area2D

@export var relic_id := ""

func _ready() -> void:
	$AnimatedSprite2D.play("coin")
	$AnimationPlayer.play("shimmer")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameEvents.relic_collected.emit(relic_id)
		queue_free()

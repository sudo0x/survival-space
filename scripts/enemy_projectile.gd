extends Area2D

@export var direction := Vector2.LEFT
@export var speed := 52.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction.normalized() * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("is_camouflaged") and bool(body.call("is_camouflaged")):
			queue_free()
			return
		body.take_damage()
	queue_free()

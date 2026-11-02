extends StaticBody2D
## Temporary one-way rune ledge that lets the hero recover energy while resting.

@export_range(2.0, 10.0, 0.5) var lifetime_seconds := 5.5

@onready var sprite: Sprite2D = $Sprite2D

var _remaining := 0.0


func _ready() -> void:
	add_to_group("air_anchor")
	_remaining = lifetime_seconds


func _process(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	var pulse := 0.76 + sin(Time.get_ticks_msec() * 0.006) * 0.08
	sprite.modulate.a = pulse if _remaining > 0.8 else pulse * (_remaining / 0.8)
	if _remaining <= 0.0:
		queue_free()

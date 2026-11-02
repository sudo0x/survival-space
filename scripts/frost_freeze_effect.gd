extends AnimatedSprite2D

var _remaining_seconds := 1.55
var _rest_scale := Vector2.ONE


func configure(duration: float) -> void:
	_remaining_seconds = maxf(_remaining_seconds, duration)


func refresh(duration: float) -> void:
	_remaining_seconds = maxf(_remaining_seconds, duration)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rest_scale = scale
	animation_finished.connect(_hold_frozen_pose, CONNECT_ONE_SHOT)
	play("freeze_shell")
	scale = _rest_scale * 0.82
	var snap_on := create_tween()
	snap_on.tween_property(self, "scale", _rest_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_remaining_seconds -= delta
	if _remaining_seconds <= 0.0:
		queue_free()


func _hold_frozen_pose() -> void:
	play("frozen_idle")
	var shimmer_pulse := create_tween().set_loops()
	shimmer_pulse.tween_property(self, "scale", _rest_scale * 1.045, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shimmer_pulse.tween_property(self, "scale", _rest_scale * 0.99, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

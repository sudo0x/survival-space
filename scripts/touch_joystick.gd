extends Control
## Platform touch stick: X steers, and the full stick direction aims Hit.

@export_range(0.1, 0.4, 0.05) var deadzone := 0.18
@export_range(0.2, 0.5, 0.05) var vertical_activation := 0.42

@onready var knob: TextureRect = $Knob

var _active_touch := -1
var _mouse_active := false
var _radius := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	resized.connect(_update_geometry)
	_update_geometry()


func _update_geometry() -> void:
	_radius = minf(size.x, size.y) * 0.34
	knob.size = size * 0.46
	_center_knob()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch_position_local := _to_local_position(event.position)
		if event.pressed and _active_touch == -1 and Rect2(Vector2.ZERO, size).has_point(touch_position_local):
			_active_touch = event.index
			_update_stick(touch_position_local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
			_reset_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _active_touch:
		_update_stick(_to_local_position(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_position_local := _to_local_position(event.position)
		if event.pressed and Rect2(Vector2.ZERO, size).has_point(mouse_position_local):
			_mouse_active = true
			_update_stick(mouse_position_local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _mouse_active:
			_mouse_active = false
			_reset_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_stick(_to_local_position(event.position))
		get_viewport().set_input_as_handled()


func _to_local_position(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _update_stick(local_position: Vector2) -> void:
	var offset := local_position - size * 0.5
	if offset.length() > _radius:
		offset = offset.normalized() * _radius
	knob.position = size * 0.5 + offset - knob.size * 0.5
	var direction := offset / _radius
	if direction.length() < deadzone:
		direction = Vector2.ZERO
	_set_axis_action(&"ui_left", maxf(-direction.x, 0.0))
	_set_axis_action(&"ui_right", maxf(direction.x, 0.0))
	_set_axis_action(&"aim_up", maxf(-direction.y, 0.0) if direction.y <= -vertical_activation else 0.0)
	_set_axis_action(&"aim_down", maxf(direction.y, 0.0) if direction.y >= vertical_activation else 0.0)


func _set_axis_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _reset_stick() -> void:
	_center_knob()
	for action in [&"ui_left", &"ui_right", &"aim_up", &"aim_down"]:
		Input.action_release(action)


func _center_knob() -> void:
	knob.position = (size - knob.size) * 0.5


func _exit_tree() -> void:
	_reset_stick()

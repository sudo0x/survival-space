extends Control
## On-screen buttons forward held input to the same actions used by keyboard controls.

@export_range(80.0, 144.0, 4.0) var action_button_size := 116.0
@export_range(76.0, 128.0, 4.0) var movement_button_size := 108.0
@export_range(64.0, 112.0, 4.0) var utility_button_size := 88.0
@export_range(12.0, 40.0, 2.0) var screen_edge_margin := 28.0
@export_range(8.0, 28.0, 2.0) var button_gap := 14.0

func _ready() -> void:
	$MoveJoystick.tooltip_text = "Move and aim Hit. Push DOWN while airborne to dive-slam. Magic seeks nearby foes."
	_bind_button($Dash, "power")
	_bind_button($Magic, "magic")
	$Magic.tooltip_text = "Tap and release: cast your equipped spell. Hold Magic: sweep a wind slash across the full screen height. Unlimited uses; 2.5s cooldown."
	_bind_button($Hit, "attack")
	_bind_button($Jump, "ui_accept")
	$Jump.tooltip_text = "Tap to jump / double-jump. Hold while airborne to fly; push the stick DOWN to dive-slam."
	_bind_button($Anchor, "air_anchor")
	$Anchor.tooltip_text = "3 rift-perch charges. One charge refills every 3 seconds. Rest on a perch to restore mana, flight fuel, and dash energy."
	$Pause.pressed.connect(func(): get_tree().call_group("game", "open_pause_menu"))
	get_viewport().size_changed.connect(_layout_buttons)
	_layout_buttons()
	call_deferred("_layout_buttons")

func _layout_buttons() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# Keep the buttons round when Android's "expand" stretch mode adds extra height.
	var size_scale := minf(minf(viewport_size.x, viewport_size.y) / 648.0, 1.0)
	var action_size := maxf(80.0, action_button_size * size_scale)
	var move_size := maxf(76.0, movement_button_size * size_scale)
	var utility_size := maxf(64.0, utility_button_size * size_scale)
	var margin := maxf(16.0, minf(screen_edge_margin, minf(viewport_size.x, viewport_size.y) * 0.045))
	var gap := maxf(8.0, minf(button_gap, action_size * 0.14))

	var move_y := viewport_size.y - margin - move_size
	_place_square($MoveJoystick, Vector2(margin, move_y), move_size)

	var action_right_x := viewport_size.x - margin - action_size
	var action_left_x := action_right_x - action_size - gap
	var action_bottom_y := viewport_size.y - margin - action_size
	var action_top_y := action_bottom_y - action_size - gap
	_place_square($Magic, Vector2(action_left_x, action_top_y), action_size)
	_place_square($Dash, Vector2(action_right_x, action_top_y), action_size)
	_place_square($Hit, Vector2(action_left_x, action_bottom_y), action_size)
	_place_square($Jump, Vector2(action_right_x, action_bottom_y), action_size)
	var utility_x := viewport_size.x - margin - utility_size
	var utility_y := minf(88.0, viewport_size.y * 0.14)
	var latest_utility_y := action_top_y - (utility_size + margin)
	utility_y = minf(utility_y, maxf(margin, latest_utility_y))
	_place_square($Pause, Vector2(utility_x, utility_y), utility_size)
	var anchor_y := minf(utility_y + utility_size + gap, action_top_y - utility_size - gap)
	_place_square($Anchor, Vector2(utility_x, maxf(margin, anchor_y)), utility_size)

func _place_square(button: Control, top_left: Vector2, button_size: float) -> void:
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = top_left
	button.size = Vector2.ONE * button_size

func _bind_button(button: Button, action: StringName) -> void:
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))

func _exit_tree() -> void:
	for action in [&"ui_left", &"ui_right", &"aim_up", &"aim_down", &"power", &"magic", &"attack", &"ui_accept", &"air_anchor"]:
		Input.action_release(action)

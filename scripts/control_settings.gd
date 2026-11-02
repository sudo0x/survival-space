extends RefCounted
## Applies and saves the user-selected keyboard keys for air abilities.

const SAVE_PATH := "user://island_game.cfg"
const DEFAULT_DIVE_KEY := KEY_I
const DEFAULT_ANCHOR_KEY := KEY_U
const REMAP_ACTIONS: Array[StringName] = [&"air_dive", &"air_anchor"]
const RESERVED_ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept", &"ui_cancel",
	&"attack", &"power", &"magic", &"air_dive_down",
]


static func apply_saved_bindings() -> void:
	for action in REMAP_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var keycode := saved_key_for(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action, key_event)
	if not InputMap.has_action("air_dive_down"):
		InputMap.add_action("air_dive_down")
	InputMap.action_erase_events("air_dive_down")
	var down_event := InputEventKey.new()
	down_event.physical_keycode = KEY_DOWN
	InputMap.action_add_event("air_dive_down", down_event)


static func saved_key_for(action: StringName) -> int:
	var default_key := DEFAULT_DIVE_KEY if action == &"air_dive" else DEFAULT_ANCHOR_KEY
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return default_key
	return int(config.get_value("controls", String(action), default_key))


static func save_key_for(action: StringName, keycode: int) -> bool:
	if not REMAP_ACTIONS.has(action) or not is_key_available(keycode, action):
		return false
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("controls", String(action), keycode)
	if config.save(SAVE_PATH) != OK:
		return false
	apply_saved_bindings()
	return true


static func is_key_available(keycode: int, ignore_action: StringName) -> bool:
	if keycode <= 0 or keycode == KEY_ESCAPE or keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		return false
	for action in REMAP_ACTIONS:
		if action != ignore_action and saved_key_for(action) == keycode:
			return false
	for action in RESERVED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var mapped_key: int = event.physical_keycode if event.physical_keycode > 0 else event.keycode
				if mapped_key == keycode:
					return false
	return true

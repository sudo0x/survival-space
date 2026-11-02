extends Control

const SAVE_PATH := "user://island_game.cfg"
const GAME_SCENE := "res://scense/game.tscn"
const CONTROL_SETTINGS := preload("res://scripts/control_settings.gd")
const KNIGHT_STYLE_SHADER: Shader = preload("res://assests/shaders/knight_style.gdshader")
const STYLE_COLORS: Dictionary = {
	"classic": [Color(0.039, 0.439, 0.188), Color(0.824, 0.125, 0.173)],
	"moon": [Color(0.035, 0.47, 0.80), Color(0.24, 0.88, 1.0)],
	"jungle": [Color(0.20, 0.60, 0.24), Color(1.0, 0.72, 0.20)],
	"ember": [Color(0.78, 0.20, 0.12), Color(1.0, 0.52, 0.12)],
}
const SPARKLE_ANCHORS := [Vector2(0.11, 0.20), Vector2(0.87, 0.22), Vector2(0.16, 0.80), Vector2(0.82, 0.77), Vector2(0.66, 0.12)]

@onready var _music: AudioStreamPlayer = $MenuMusic
@onready var _page_title: Label = $Shell/Body/MainPanel/Margin/MainStack/PageHeader/Title
@onready var _page_subtitle: Label = $Shell/Body/MainPanel/Margin/MainStack/PageHeader/Subtitle
@onready var _pages: Dictionary = {
	"home": $Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage,
	"armory": $Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage,
	"collection": $Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage,
	"market": $Shell/Body/MainPanel/Margin/MainStack/Pages/MarketPage,
	"settings": $Shell/Body/MainPanel/Margin/MainStack/Pages/SettingsPage,
}
@onready var _portrait: TextureRect = $Shell/Body/Sidebar/Margin/SidebarStack/Portrait
@onready var _large_portrait: TextureRect = $Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/WelcomeCard/Welcome/Portrait
@onready var _level_label: Label = $Shell/Body/Sidebar/Margin/SidebarStack/FieldLevel
@onready var _xp_bar: ProgressBar = $Shell/Body/Sidebar/Margin/SidebarStack/XPBar
@onready var _xp_label: Label = $Shell/Body/Sidebar/Margin/SidebarStack/XPLabel
@onready var _side_coins: Label = $Shell/Body/Sidebar/Margin/SidebarStack/CoinBalance
@onready var _home_coins: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/QuickStats/CoinsCard/CoinInfo/Coins
@onready var _home_best: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/QuickStats/ScoreCard/ScoreInfo/Score
@onready var _home_wave: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/QuickStats/WaveCard/WaveInfo/Wave
@onready var _collection_coins: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/CoinsCard/Info/Value
@onready var _collection_fruit: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/FruitCard/Info/Value
@onready var _collection_score: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/ScoreCard/Info/Value
@onready var _collection_wave: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/WaveCard/Info/Value
@onready var _sound_button: Button = $Shell/Body/MainPanel/Margin/MainStack/Pages/SettingsPage/SettingsStack/Sound
@onready var _dive_key_button: Button = $Shell/Body/MainPanel/Margin/MainStack/Pages/SettingsPage/SettingsStack/DiveKey
@onready var _anchor_key_button: Button = $Shell/Body/MainPanel/Margin/MainStack/Pages/SettingsPage/SettingsStack/AnchorKey
@onready var _controls_label: Label = $Shell/Body/MainPanel/Margin/MainStack/Pages/SettingsPage/SettingsStack/ControlsCard/Controls

var _profile_level := 1
var _profile_xp := 0
var _coins := 0
var _fruit := 0
var _best_score := 0
var _best_wave := 0
var _sound_enabled := true
var _character_style := "classic"
var _current_page := "home"
var _waiting_for_rebind := &""


func _ready() -> void:
	get_tree().paused = false
	CONTROL_SETTINGS.apply_saved_bindings()
	_load_profile()
	$Shell/Body/Sidebar/Margin/SidebarStack/Nav/Home.pressed.connect(_show_page.bind("home"))
	$Shell/Body/Sidebar/Margin/SidebarStack/Nav/Armory.pressed.connect(_show_page.bind("armory"))
	$Shell/Body/Sidebar/Margin/SidebarStack/Nav/Collection.pressed.connect(_show_page.bind("collection"))
	$Shell/Body/Sidebar/Margin/SidebarStack/Nav/Market.pressed.connect(_show_page.bind("market"))
	$Shell/Body/Sidebar/Margin/SidebarStack/Nav/Settings.pressed.connect(_show_page.bind("settings"))
	$Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/Deploy.pressed.connect(_launch_run)
	_sound_button.pressed.connect(_toggle_sound)
	_dive_key_button.pressed.connect(_begin_key_rebind.bind(&"air_dive"))
	_anchor_key_button.pressed.connect(_begin_key_rebind.bind(&"air_anchor"))
	$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Classic.pressed.connect(_select_style.bind("classic"))
	$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Moon.pressed.connect(_select_style.bind("moon"))
	$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Jungle.pressed.connect(_select_style.bind("jungle"))
	$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Ember.pressed.connect(_select_style.bind("ember"))
	_style_interface()
	_apply_style_preview()
	_update_profile_labels()
	_update_control_key_labels()
	_show_page("home")
	_start_ambience()
	_layout_for_viewport()
	get_viewport().size_changed.connect(_layout_for_viewport)
	$Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/Deploy.grab_focus()


func _input(event: InputEvent) -> void:
	if _waiting_for_rebind.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ESCAPE:
		_waiting_for_rebind = &""
		_update_control_key_labels()
		get_viewport().set_input_as_handled()
		return
	var keycode: int = key_event.physical_keycode if key_event.physical_keycode > 0 else key_event.keycode
	var target_button := _dive_key_button if _waiting_for_rebind == &"air_dive" else _anchor_key_button
	if CONTROL_SETTINGS.save_key_for(_waiting_for_rebind, keycode):
		_waiting_for_rebind = &""
		_update_control_key_labels()
	else:
		_waiting_for_rebind = &""
		target_button.text = "KEY IN USE  /  TRY AGAIN"
		get_tree().create_timer(1.2).timeout.connect(_update_control_key_labels)
	get_viewport().set_input_as_handled()


func _begin_key_rebind(action: StringName) -> void:
	_waiting_for_rebind = action
	var button := _dive_key_button if action == &"air_dive" else _anchor_key_button
	button.text = "PRESS A KEY  /  ESC CANCEL"


func _update_control_key_labels() -> void:
	if not is_instance_valid(_dive_key_button) or not is_instance_valid(_anchor_key_button):
		return
	var dive_key := OS.get_keycode_string(CONTROL_SETTINGS.saved_key_for(&"air_dive"))
	var anchor_key := OS.get_keycode_string(CONTROL_SETTINGS.saved_key_for(&"air_anchor"))
	if _waiting_for_rebind == &"air_dive":
		_dive_key_button.text = "DIVE KEY  /  PRESS A KEY"
	else:
		_dive_key_button.text = "DIVE KEY  /  " + dive_key
	if _waiting_for_rebind == &"air_anchor":
		_anchor_key_button.text = "RIFT REST KEY  /  PRESS A KEY"
	else:
		_anchor_key_button.text = "RIFT REST KEY  /  " + anchor_key
	_controls_label.text = "CONTROLS\n\nPC  A / D MOVE  •  MOUSE AIM  •  LEFT CLICK HIT  •  RIGHT CLICK MAGIC  •  %s DIVE  •  %s RIFT PERCH\n\nMOBILE  LEFT STICK TO MOVE / AIM  •  PUSH DOWN IN AIR TO DIVE  •  TAP RIFT TO PLACE A PERCH\n\nJUMP  TAP TO JUMP  •  HOLD WHILE AIRBORNE TO FLY  •  REST ON A PERCH TO RECOVER MANA, FLIGHT FUEL, AND DASH ENERGY" % [dive_key, anchor_key]


func _load_profile() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	_profile_level = maxi(int(config.get_value("profile", "level", 1)), 1)
	_profile_xp = maxi(int(config.get_value("profile", "xp", 0)), 0)
	_coins = maxi(int(config.get_value("inventory", "coins", 0)), 0)
	_fruit = maxi(int(config.get_value("inventory", "fruit", 0)), 0)
	_best_score = maxi(int(config.get_value("progress", "best_score", config.get_value("progress", "best_treasures", 0))), 0)
	_best_wave = maxi(int(config.get_value("progress", "best_wave", 0)), 0)
	_sound_enabled = bool(config.get_value("settings", "sound", true))
	_character_style = String(config.get_value("appearance", "character_style", "classic"))
	if not STYLE_COLORS.has(_character_style):
		_character_style = "classic"
	AudioServer.set_bus_mute(0, not _sound_enabled)


func _update_profile_labels() -> void:
	var xp_to_next := 100 + (_profile_level - 1) * 50
	var visible_xp := mini(_profile_xp, xp_to_next)
	_level_label.text = "FIELD LEVEL  %02d" % _profile_level
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = visible_xp
	_xp_label.text = "XP  %d / %d" % [visible_xp, xp_to_next]
	_side_coins.text = "%04d  COINS" % _coins
	_home_coins.text = "%04d" % _coins
	_home_best.text = "%04d" % _best_score
	_home_wave.text = "%02d" % _best_wave
	_collection_coins.text = "%04d" % _coins
	_collection_fruit.text = "%04d" % _fruit
	_collection_score.text = "%04d" % _best_score
	_collection_wave.text = "%02d" % _best_wave
	_sound_button.text = "SOUND  /  ON" if _sound_enabled else "SOUND  /  OFF"


func _show_page(page_name: String) -> void:
	if not _pages.has(page_name):
		return
	_current_page = page_name
	for key in _pages:
		(_pages[key] as Control).visible = key == page_name
	var nav: Node = $Shell/Body/Sidebar/Margin/SidebarStack/Nav
	for button_name in ["Home", "Armory", "Collection", "Market", "Settings"]:
		var button: Button = nav.get_node(button_name) as Button
		button.button_pressed = button_name.to_lower() == page_name
	match page_name:
		"home":
			_page_title.text = "COMMAND DECK"
			_page_subtitle.text = "Choose your next run. Your long-term progress stays here."
		"armory":
			_page_title.text = "ARMORY"
			_page_subtitle.text = "Set your look before you deploy. Styles are saved to your profile."
		"collection":
			_page_title.text = "FIELD RECORDS"
			_page_subtitle.text = "Your banked finds and strongest survival run."
		"market":
			_page_title.text = "MARKET"
			_page_subtitle.text = "A dedicated place for optional offers when the store is connected."
		"settings":
			_page_title.text = "SETTINGS"
			_page_subtitle.text = "Tune the experience and review the controls."


func _launch_run() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _select_style(style_id: String) -> void:
	if not STYLE_COLORS.has(style_id):
		return
	_character_style = style_id
	_apply_style_preview()
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("appearance", "character_style", _character_style)
	config.save(SAVE_PATH)


func _apply_style_preview() -> void:
	var palette: Array = STYLE_COLORS[_character_style]
	var style_material := ShaderMaterial.new()
	style_material.shader = KNIGHT_STYLE_SHADER
	style_material.set_shader_parameter("tunic_color", palette[0])
	style_material.set_shader_parameter("plume_color", palette[1])
	_portrait.material = style_material
	_large_portrait.material = style_material
	var grid: Node = $Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid
	for style_id in STYLE_COLORS:
		var button: Button = grid.get_node(style_id.capitalize()) as Button
		button.text = ("SELECTED  /  " if style_id == _character_style else "") + style_id.to_upper()
		button.modulate = Color.WHITE if style_id == _character_style else Color(0.78, 0.85, 0.92)


func _toggle_sound() -> void:
	_sound_enabled = not _sound_enabled
	AudioServer.set_bus_mute(0, not _sound_enabled)
	_sound_button.text = "SOUND  /  ON" if _sound_enabled else "SOUND  /  OFF"
	if _sound_enabled and not _music.playing:
		_music.play()
	elif not _sound_enabled:
		_music.stop()
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("settings", "sound", _sound_enabled)
	config.save(SAVE_PATH)


func _start_ambience() -> void:
	_music.finished.connect(_replay_music)
	if _sound_enabled:
		_music.play()
	for index in range(SPARKLE_ANCHORS.size()):
		var sparkle := ColorRect.new()
		sparkle.name = "PixelSparkle%d" % index
		sparkle.size = Vector2(4, 4) if index % 2 == 0 else Vector2(3, 3)
		sparkle.position = get_viewport_rect().size * SPARKLE_ANCHORS[index]
		sparkle.color = Color(0.45, 0.88, 1.0, 0.9) if index % 2 == 0 else Color(1.0, 0.79, 0.38, 0.85)
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$SparkleLayer.add_child(sparkle)
		var base_y := sparkle.position.y
		var drift := create_tween().set_loops()
		drift.tween_property(sparkle, "position:y", base_y - 10.0, 2.8 + index * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(sparkle, "position:y", base_y, 2.8 + index * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var twinkle := create_tween().set_loops()
		twinkle.tween_property(sparkle, "modulate:a", 0.18, 0.8 + (index % 3) * 0.2)
		twinkle.tween_property(sparkle, "modulate:a", 1.0, 0.8 + (index % 3) * 0.2)
	var title: Control = $Shell/Body/MainPanel/Margin/MainStack/PageHeader/Title
	var pulse := create_tween().set_loops()
	pulse.tween_property(title, "modulate", Color(1.0, 0.96, 0.84), 2.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title, "modulate", Color.WHITE, 2.0).set_trans(Tween.TRANS_SINE)


func _replay_music() -> void:
	if _sound_enabled:
		_music.play()


func _layout_for_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	for child in $SparkleLayer.get_children():
		if child is ColorRect:
			var index := int(child.name.trim_prefix("PixelSparkle"))
			child.position = viewport_size * SPARKLE_ANCHORS[index]
	var sidebar_width := clampf(viewport_size.x * 0.205, 190.0, 250.0)
	$Shell/Body/Sidebar.custom_minimum_size.x = sidebar_width


func _style_interface() -> void:
	_style_panel($Shell, Color(0.25, 0.45, 0.58, 0.96), Color(0.018, 0.032, 0.055, 0.97))
	_style_panel($Shell/Body/Sidebar, Color(0.21, 0.39, 0.52, 0.9), Color(0.027, 0.047, 0.073, 0.98))
	_style_panel($Shell/Body/MainPanel, Color(0.17, 0.33, 0.45, 0.9), Color(0.027, 0.044, 0.068, 0.94))
	for card in [
		$Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/WelcomeCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/QuickStats/CoinsCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/QuickStats/ScoreCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/QuickStats/WaveCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/CoinsCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/FruitCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/ScoreCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/CollectionPage/CollectionStack/CollectionGrid/WaveCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/MarketPage/MarketStack/OfferGrid/Cosmetics,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/MarketPage/MarketStack/OfferGrid/AdFree,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/MarketPage/MarketStack/OfferGrid/Supporter,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/SettingsPage/SettingsStack/ControlsCard,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/PreviewCard,
	]:
		_style_panel(card as Control, Color(0.17, 0.34, 0.46, 0.9), Color(0.043, 0.068, 0.10, 0.97))
	var nav: Node = $Shell/Body/Sidebar/Margin/SidebarStack/Nav
	for button_name in ["Home", "Armory", "Collection", "Market", "Settings"]:
		_style_button(nav.get_node(button_name) as Button, false)
	for button in [
		$Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/Deploy,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Classic,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Moon,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Jungle,
		$Shell/Body/MainPanel/Margin/MainStack/Pages/ArmoryPage/ArmoryStack/StyleGrid/Ember,
		_sound_button,
		_dive_key_button,
		_anchor_key_button,
	]:
		_style_button(button as Button, button == $Shell/Body/MainPanel/Margin/MainStack/Pages/HomePage/HomeStack/Deploy)


func _style_panel(panel: Control, border_color: Color, fill_color: Color) -> void:
	if not is_instance_valid(panel):
		push_warning("Main menu styling skipped a missing panel node.")
		return
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)


func _style_button(button: Button, primary: bool) -> void:
	if not is_instance_valid(button):
		push_warning("Main menu styling skipped a missing button node.")
		return
	button.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	var accent := Color(0.90, 0.69, 0.32, 1.0) if primary else Color(0.28, 0.49, 0.63, 1.0)
	for style in [normal, hover, pressed]:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = accent
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
	normal.bg_color = Color(0.09, 0.16, 0.22, 1.0)
	hover.bg_color = Color(0.13, 0.24, 0.31, 1.0)
	pressed.bg_color = Color(0.10, 0.22, 0.30, 1.0)
	pressed.border_color = Color(0.47, 0.78, 0.91, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.57) if primary else Color(0.77, 0.89, 0.96))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78))

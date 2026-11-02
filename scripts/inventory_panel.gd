extends Control
## Editor-visible hero home: palette choices plus the player's collected finds.

const KNIGHT_STYLE_SHADER: Shader = preload("res://assests/shaders/knight_style.gdshader")
const STYLE_IDS: Array[String] = ["classic", "moon", "jungle", "ember"]

@onready var _coins_label: Label = $Panel/Margin/VBox/Coins
@onready var _fruit_label: Label = $Panel/Margin/VBox/Fruit
@onready var _relics_label: Label = $Panel/Margin/VBox/Relics
@onready var _charges_label: Label = $Panel/Margin/VBox/Charges

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/Margin/VBox/Close.pressed.connect(_close_inventory)
	for style_id in STYLE_IDS:
		var button_name := style_id.capitalize()
		$Panel/Margin/VBox/Styles.get_node(button_name).pressed.connect(_request_style.bind(style_id))

func set_contents(coins: int, fruit: int, relics: int, dash_energy: int, max_dash_energy: int) -> void:
	_coins_label.text = "COINS COLLECTED     %03d" % coins
	_fruit_label.text = "FRUIT COLLECTED     %03d" % fruit
	_relics_label.text = "ANCIENT RELICS       %d" % relics
	_charges_label.text = "DASH ENERGY          %d / %d" % [dash_energy, max_dash_energy]
	_charges_label.tooltip_text = "Each dash spends 1 energy. Enemy energy orbs restore 1 to 5 dash energy and 10 to 100 jump mana. Dash energy regenerates 1 point every 3 seconds; maximum: %d." % max_dash_energy

func set_style(style_id: String, tunic_color: Color, plume_color: Color) -> void:
	var preview_material := ShaderMaterial.new()
	preview_material.shader = KNIGHT_STYLE_SHADER
	preview_material.set_shader_parameter("tunic_color", tunic_color)
	preview_material.set_shader_parameter("plume_color", plume_color)
	$Panel/Margin/VBox/StylePreview.material = preview_material
	for button_key in STYLE_IDS:
		var button: Button = $Panel/Margin/VBox/Styles.get_node(button_key.capitalize())
		var selected := button_key == style_id
		button.text = ("✓ " if selected else "") + button_key.to_upper()
		button.modulate = Color.WHITE if selected else Color(0.74, 0.80, 0.87, 1.0)

func _request_style(style_id: String) -> void:
	get_tree().call_group("game", "select_character_style", style_id)

func _close_inventory() -> void:
	get_tree().call_group("game", "close_inventory")

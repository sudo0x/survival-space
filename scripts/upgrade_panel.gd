extends Control
class_name RunUpgradePanel

signal upgrade_selected(upgrade_id: String)

@onready var _choice_buttons: Array[Button] = [
	$Panel/Content/Choices/HullChoice,
	$Panel/Content/Choices/DashChoice,
	$Panel/Content/Choices/MagicChoice,
]


func _ready() -> void:
	for index in range(_choice_buttons.size()):
		_choice_buttons[index].pressed.connect(_select_choice.bind(index))


func present_choices(choices: Array[Dictionary], level: int) -> void:
	visible = true
	$Panel/Content/Title.text = "LEVEL %02d  /  CHOOSE AN UPGRADE" % level
	for index in range(_choice_buttons.size()):
		var button := _choice_buttons[index]
		if index >= choices.size():
			button.visible = false
			continue
		var choice: Dictionary = choices[index]
		button.set_meta("upgrade_id", String(choice.id))
		button.text = "%s\n\n%s" % [String(choice.title), String(choice.description)]
		button.visible = true
		if index == 0:
			button.grab_focus()


func _select_choice(index: int) -> void:
	if index < 0 or index >= _choice_buttons.size():
		return
	var button := _choice_buttons[index]
	if button.visible:
		upgrade_selected.emit(String(button.get_meta("upgrade_id", "")))

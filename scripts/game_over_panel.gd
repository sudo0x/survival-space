extends Control
class_name GameOverPanel

signal retry_requested
signal home_requested
signal sound_toggled(enabled: bool)

@onready var _wave_value: Label = $Panel/Content/RunStats/WaveCard/WaveInfo/WaveValue
@onready var _treasure_value: Label = $Panel/Content/RunStats/TreasureCard/TreasureInfo/TreasureRow/TreasureValue
@onready var _level_value: Label = $Panel/Content/RunStats/LevelCard/LevelInfo/LevelValue
@onready var _enemy_value: Label = $Panel/Content/RunStats/EnemyCard/EnemyInfo/EnemyValue
@onready var _sound_button: Button = $Panel/Content/Actions/SoundButton
@onready var _retry_button: TextureButton = $Panel/Content/Actions/Retry
@onready var _home_button: Button = $Panel/Content/Actions/Home

var _sound_enabled := true

func _ready() -> void:
	_retry_button.pressed.connect(func(): retry_requested.emit())
	_home_button.pressed.connect(func(): home_requested.emit())
	_sound_button.pressed.connect(_toggle_sound)
	_retry_button.grab_focus()

func set_run_summary(wave: int, score: int, level: int, kills: int, best_score: int, sound_is_enabled: bool, is_victory: bool = false) -> void:
	_wave_value.text = "%02d" % wave
	_treasure_value.text = "%04d" % score
	_level_value.text = "%02d" % level
	_enemy_value.text = "%03d" % kills
	$Panel/Content/Title.text = "RIFT SEALED!" if is_victory else "RUN OVER"
	$Panel/Content/Description.text = "You defended the arena and sealed the rift! Best score: %d." % best_score if is_victory else "The swarm overwhelmed your hull. Best score: %d." % best_score
	$Panel/Content/Actions/Retry/RetryText.text = "PLAY\nAGAIN" if is_victory else "TRY\nAGAIN"
	$Panel/Content/Hint.text = "THE ARENA IS SAFE... FOR NOW" if is_victory else "TAP THE STONE TO LAUNCH ANOTHER RUN"
	_sound_enabled = sound_is_enabled
	_sound_button.text = "SOUND  ON" if _sound_enabled else "SOUND  OFF"

func set_profile_reward(xp_reward: int) -> void:
	$Panel/Content/ProfileReward.text = "CAREER XP EARNED  +%d" % xp_reward

func _toggle_sound() -> void:
	_sound_enabled = not _sound_enabled
	_sound_button.text = "SOUND  ON" if _sound_enabled else "SOUND  OFF"
	sound_toggled.emit(_sound_enabled)

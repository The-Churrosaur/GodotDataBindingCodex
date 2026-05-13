extends Node

const SAMPLE_SCENE := preload("res://addons/data_binding/samples/data_binding_sample.tscn")

var _failures: PackedStringArray = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var sample := SAMPLE_SCENE.instantiate()
	add_child(sample)

	await get_tree().process_frame
	await get_tree().process_frame

	var player_data := sample.get_node("PlayerData")
	var plain_settings := sample.get_node("PlainSettings")
	var name_edit := sample.get_node("Form/NameEdit") as LineEdit
	var health_slider := sample.get_node("Form/HealthSlider") as HSlider
	var invincible_check := sample.get_node("Form/InvincibleCheck") as CheckBox
	var title_signal_value := sample.get_node("Form/TitleSignalValue") as Label
	var nickname_edit := sample.get_node("Form/NicknameEdit") as LineEdit
	var metrics_check := sample.get_node("Form/MetricsCheck") as CheckBox

	_expect_equal(name_edit.text, "Ada", "initial player_name syncs to NameEdit.text")
	_expect_approx(health_slider.value, 75.0, "initial health syncs to HealthSlider.value")
	_expect_equal(invincible_check.button_pressed, false, "initial invincible syncs to InvincibleCheck.button_pressed")
	_expect_equal(title_signal_value.text, "Custom signal ready", "initial custom-signal title syncs to TitleSignalValue.text")

	player_data.player_name = "Bea"
	player_data.health = 42.0
	player_data.invincible = true
	player_data.title = "Captain"
	await get_tree().process_frame

	_expect_equal(name_edit.text, "Bea", "data player_name propagates to NameEdit.text")
	_expect_approx(health_slider.value, 42.0, "data health propagates to HealthSlider.value")
	_expect_equal(invincible_check.button_pressed, true, "data invincible propagates to InvincibleCheck.button_pressed")
	_expect_equal(title_signal_value.text, "Captain", "custom data signal propagates title to TitleSignalValue.text")

	name_edit.text = "Cy"
	name_edit.text_changed.emit(name_edit.text)
	health_slider.value = 63.0
	health_slider.value_changed.emit(health_slider.value)
	invincible_check.button_pressed = false
	invincible_check.toggled.emit(invincible_check.button_pressed)
	await get_tree().process_frame

	_expect_equal(player_data.player_name, "Cy", "NameEdit.text propagates to data player_name")
	_expect_approx(player_data.health, 63.0, "HealthSlider.value propagates to data health")
	_expect_equal(player_data.invincible, false, "InvincibleCheck.button_pressed propagates to data invincible")

	nickname_edit.text = "Plain nickname"
	nickname_edit.text_changed.emit(nickname_edit.text)
	metrics_check.button_pressed = true
	metrics_check.toggled.emit(metrics_check.button_pressed)
	await get_tree().process_frame

	_expect_equal(plain_settings.nickname, "Plain nickname", "NicknameEdit.text propagates to signal-free PlainSettings.nickname")
	_expect_equal(plain_settings.send_metrics, true, "MetricsCheck.button_pressed propagates to signal-free PlainSettings.send_metrics")

	sample.queue_free()
	await get_tree().process_frame

	if _failures.is_empty():
		print("PASS: sample binding propagation smoke test")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS: %s" % message)
		return

	_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if is_equal_approx(actual, expected):
		print("PASS: %s" % message)
		return

	_failures.append("%s: expected %s, got %s" % [message, expected, actual])

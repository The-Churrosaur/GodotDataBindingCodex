@tool
extends EditorProperty

## Custom inspector picker for PropertyBinding.control_changed_signal.
const ControlBindingAdaptersScript := preload("res://addons/data_binding/runtime/control_binding_adapters.gd")

const META_KIND_COMMAND := "command"
const COMMAND_SET_SHOW_ALL := "set_show_all"

var _binding: Object
var _option_button: OptionButton


func _init() -> void:
	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.set("fit_to_longest_item", false)
	_option_button.set("text_overrun_behavior", TextServer.OVERRUN_TRIM_ELLIPSIS)
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)
	add_focusable(_option_button)


## Binds this editor property to the PropertyBinding currently being inspected.
func setup(binding: Object) -> void:
	_binding = binding
	_rebuild_options()


func _update_property() -> void:
	_rebuild_options()


func _rebuild_options() -> void:
	_option_button.clear()

	if not is_instance_valid(_binding):
		_add_disabled_item("Binding unavailable")
		return

	var control := _binding.get("control_node") as Control
	if control == null:
		_add_disabled_item("Assign control_node first")
		return

	var control_property := StringName(_binding.get("control_property"))
	if control_property == &"":
		_add_disabled_item("Select control_property first")
		return

	var current_signal := StringName(_binding.get("control_changed_signal"))
	var default_signal := ControlBindingAdaptersScript.get_default_changed_signal(control, control_property)
	var configured_signals := ControlBindingAdaptersScript.get_changed_signal_options(control, control_property)
	var include_reflected_signals := bool(_binding.get("show_all_control_signals"))
	var configured_signal_names := {}
	var first_signal_index := -1
	var placeholder_index := -1
	var selected_index := -1
	_option_button.disabled = false

	if include_reflected_signals and current_signal == &"" and default_signal == &"":
		_option_button.add_item("Select signal")
		placeholder_index = _option_button.get_item_count() - 1
		_option_button.set_item_disabled(placeholder_index, true)

	for signal_option in configured_signals:
		var signal_name := StringName(signal_option.get("name", ""))
		if signal_name == &"":
			continue

		configured_signal_names[signal_name] = true
		var item_index := _add_signal_option(signal_option, default_signal)
		if first_signal_index < 0:
			first_signal_index = item_index
		if _option_matches_current_signal(signal_name, default_signal, current_signal):
			selected_index = item_index

	if include_reflected_signals:
		var reflected_separator_added := false
		for signal_option in ControlBindingAdaptersScript.get_reflected_signals(control):
			var signal_name := StringName(signal_option.get("name", ""))
			if signal_name == &"":
				continue
			if configured_signal_names.has(signal_name):
				continue

			if not reflected_separator_added and _option_button.get_item_count() > 0:
				_option_button.add_separator()
				reflected_separator_added = true

			var item_index := _add_signal_option(signal_option, default_signal)
			if first_signal_index < 0:
				first_signal_index = item_index
			if _option_matches_current_signal(signal_name, default_signal, current_signal):
				selected_index = item_index

	if _option_button.get_item_count() == 0:
		var placeholder := "No configured signals"
		if include_reflected_signals:
			placeholder = "No reflected signals"
		_option_button.add_item(placeholder)
		placeholder_index = _option_button.get_item_count() - 1
		_option_button.set_item_disabled(placeholder_index, true)

	if selected_index >= 0:
		_option_button.select(selected_index)
	elif current_signal != &"":
		if _option_button.get_item_count() > 0:
			_option_button.add_separator()
		if control.has_signal(current_signal):
			_option_button.add_item("%s (manual override)" % current_signal)
			var override_index := _option_button.get_item_count() - 1
			_option_button.set_item_metadata(override_index, current_signal)
			_option_button.select(override_index)
		else:
			_option_button.add_item("%s (missing)" % current_signal)
			var missing_index := _option_button.get_item_count() - 1
			_option_button.set_item_disabled(missing_index, true)
			_option_button.select(missing_index)
	elif placeholder_index >= 0:
		_option_button.select(placeholder_index)
	elif first_signal_index >= 0:
		_option_button.select(first_signal_index)
	else:
		_option_button.select(0)

	_add_show_all_command()


func _format_signal_label(signal_option: Dictionary) -> String:
	var signal_name := StringName(signal_option.get("name", ""))
	return String(signal_name)


func _add_signal_option(signal_option: Dictionary, default_signal: StringName) -> int:
	var signal_name := StringName(signal_option.get("name", ""))
	var label := _format_signal_label(signal_option)
	if signal_name == default_signal:
		label = "%s (default)" % label

	_option_button.add_item(label)
	var item_index := _option_button.get_item_count() - 1
	_option_button.set_item_metadata(item_index, signal_name)
	return item_index


func _option_matches_current_signal(signal_name: StringName, default_signal: StringName, current_signal: StringName) -> bool:
	if current_signal == signal_name:
		return true
	return current_signal == &"" and signal_name == default_signal


func _add_show_all_command() -> void:
	if _option_button.get_item_count() > 0:
		_option_button.add_separator()

	var is_showing_all := bool(_binding.get("show_all_control_signals"))
	var label := "Show all control signals"
	if is_showing_all:
		label = "Show configured control signals only"

	_option_button.add_item(label)
	var item_index := _option_button.get_item_count() - 1
	_option_button.set_item_metadata(item_index, {
		META_KIND_COMMAND: COMMAND_SET_SHOW_ALL,
		"property": &"show_all_control_signals",
		"value": not is_showing_all,
	})


func _handle_command(metadata: Dictionary) -> void:
	if metadata.get(META_KIND_COMMAND, "") != COMMAND_SET_SHOW_ALL:
		return

	var flag_property := StringName(metadata.get("property", ""))
	if flag_property == &"":
		return

	var value := bool(metadata.get("value", false))
	_binding.set(flag_property, value)
	_rebuild_options()


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _option_button.get_item_count():
		return

	var selected_signal := _option_button.get_item_metadata(index)
	if selected_signal == null:
		return
	if typeof(selected_signal) == TYPE_DICTIONARY:
		_handle_command(selected_signal)
		return

	emit_changed("control_changed_signal", StringName(selected_signal))


func _add_disabled_item(text: String) -> void:
	_option_button.disabled = true
	_option_button.add_item(text)
	_option_button.set_item_disabled(0, true)
	_option_button.select(0)

@tool
extends EditorProperty

## Custom inspector picker for PropertyBinding signal fields.
const ControlBindingAdaptersScript := preload("res://addons/data_binding/runtime/control_binding_adapters.gd")

const META_KIND_COMMAND := "command"
const COMMAND_SET_SHOW_ALL := "set_show_all"

var _binding: Object
var _edited_property := &""
var _target_property := &""
var _target_label := ""
var _dependent_property := &""
var _dependent_label := ""
var _use_control_catalog := false
var _use_script_signals := false
var _show_all_property := &""
var _default_signal := &""
var _show_all_label := "Show all signals"
var _show_limited_label := "Show recommended signals only"
var _empty_limited_label := "No recommended signals"
var _empty_all_label := "No reflected signals"
var _enabled_mode_mask := 0
var _option_button: OptionButton


func _init() -> void:
	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.set("fit_to_longest_item", false)
	_option_button.set("text_overrun_behavior", TextServer.OVERRUN_TRIM_ELLIPSIS)
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)
	add_focusable(_option_button)


## Binds this editor property to one signal field on the PropertyBinding being inspected.
func setup(
	binding: Object,
	edited_property: StringName,
	target_property: StringName,
	target_label: String,
	dependent_property: StringName = &"",
	dependent_label: String = "",
	use_control_catalog := false,
	use_script_signals := false,
	show_all_property: StringName = &"",
	default_signal: StringName = &"",
	show_all_label := "",
	show_limited_label := "",
	empty_limited_label := "",
	empty_all_label := "",
	enabled_mode_mask := 0
) -> void:
	_binding = binding
	_edited_property = edited_property
	_target_property = target_property
	_target_label = target_label
	_dependent_property = dependent_property
	_dependent_label = dependent_label
	_use_control_catalog = use_control_catalog
	_use_script_signals = use_script_signals
	_show_all_property = show_all_property
	_default_signal = default_signal
	if show_all_label != "":
		_show_all_label = show_all_label
	if show_limited_label != "":
		_show_limited_label = show_limited_label
	if empty_limited_label != "":
		_empty_limited_label = empty_limited_label
	if empty_all_label != "":
		_empty_all_label = empty_all_label
	_enabled_mode_mask = enabled_mode_mask
	_rebuild_options()


func _update_property() -> void:
	_rebuild_options()


func _rebuild_options() -> void:
	_option_button.clear()

	if not is_instance_valid(_binding):
		_add_disabled_item("Binding unavailable")
		return

	var target := _binding.get(String(_target_property)) as Object
	if target == null:
		_add_disabled_item("Assign %s first" % _target_label)
		return

	var dependent_value := &""
	if _dependent_property != &"":
		dependent_value = StringName(_binding.get(String(_dependent_property)))
		if dependent_value == &"":
			_add_disabled_item("Select %s first" % _dependent_label)
			return

	var current_signal := StringName(_binding.get(String(_edited_property)))
	var default_signal := _get_default_signal(target, dependent_value)
	var configured_signals := _get_configured_signal_options(target, dependent_value)
	var include_reflected_signals := _should_include_reflected_signals()
	var configured_signal_names := {}
	var first_signal_index := -1
	var placeholder_index := -1
	var selected_index := -1
	var disabled_selection_index := -1
	_option_button.disabled = false

	if include_reflected_signals and current_signal == &"" and default_signal == &"":
		placeholder_index = _add_placeholder_item("Select signal")

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
		for signal_option in _get_reflected_signals(target):
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
		var placeholder := _empty_limited_label
		if include_reflected_signals:
			placeholder = _empty_all_label
		placeholder_index = _add_placeholder_item(placeholder)

	if selected_index >= 0:
		_option_button.select(selected_index)
	elif current_signal != &"":
		if _option_button.get_item_count() > 0:
			_option_button.add_separator()
		if target.has_signal(current_signal):
			_option_button.add_item("%s (manual override)" % current_signal)
			var override_index := _option_button.get_item_count() - 1
			_option_button.set_item_metadata(override_index, current_signal)
			_option_button.select(override_index)
		else:
			var missing_index := _add_placeholder_item("%s (missing)" % current_signal)
			disabled_selection_index = missing_index
	elif placeholder_index >= 0:
		disabled_selection_index = placeholder_index
	elif first_signal_index >= 0:
		_option_button.select(first_signal_index)
	else:
		disabled_selection_index = _add_placeholder_item(_empty_limited_label)

	_add_show_all_command()
	if disabled_selection_index >= 0:
		_option_button.select(disabled_selection_index)
	_apply_mode_enabled_state()


func _apply_mode_enabled_state() -> void:
	if _enabled_mode_mask == 0 or not is_instance_valid(_binding):
		return

	var binding_mode := int(_binding.get("mode"))
	if (_enabled_mode_mask & (1 << binding_mode)) == 0:
		_option_button.disabled = true


func _get_configured_signal_options(target: Object, dependent_value: StringName) -> Array[Dictionary]:
	if not _use_control_catalog or not (target is Control):
		if _use_script_signals:
			return _get_script_signals(target)
		return []

	return ControlBindingAdaptersScript.get_changed_signal_options(target, dependent_value)


func _get_default_signal(target: Object, dependent_value: StringName) -> StringName:
	if _use_control_catalog and target is Control:
		return ControlBindingAdaptersScript.get_default_changed_signal(target, dependent_value)

	if _default_signal != &"" and target.has_signal(_default_signal):
		return _default_signal

	return &""


func _should_include_reflected_signals() -> bool:
	if _show_all_property == &"":
		return true

	return bool(_binding.get(String(_show_all_property)))


func _get_reflected_signals(target: Object) -> Array[Dictionary]:
	var signals: Array[Dictionary] = []
	if target == null:
		return signals

	for signal_info in target.get_signal_list():
		var signal_name := StringName(signal_info.get("name", ""))
		if signal_name == &"":
			continue

		signals.append({
			"name": signal_name,
			"label": String(signal_name),
			"argument_count": (signal_info.get("args", []) as Array).size(),
		})

	signals.sort_custom(_compare_named_options)
	return signals


func _get_script_signals(target: Object) -> Array[Dictionary]:
	var signals: Array[Dictionary] = []
	if target == null:
		return signals

	var seen_signal_names := {}
	var script_resource := target.get_script() as Script
	while script_resource != null:
		for signal_info in script_resource.get_script_signal_list():
			var signal_name := StringName(signal_info.get("name", ""))
			if signal_name == &"" or seen_signal_names.has(signal_name):
				continue

			seen_signal_names[signal_name] = true
			signals.append({
				"name": signal_name,
				"label": String(signal_name),
				"argument_count": (signal_info.get("args", []) as Array).size(),
			})

		script_resource = script_resource.get_base_script()

	signals.sort_custom(_compare_named_options)
	return signals


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
	if _show_all_property == &"":
		return

	if _option_button.get_item_count() > 0:
		_option_button.add_separator()

	var is_showing_all := bool(_binding.get(String(_show_all_property)))
	var label := _show_all_label
	if is_showing_all:
		label = _show_limited_label

	_option_button.add_item(label)
	var item_index := _option_button.get_item_count() - 1
	_option_button.set_item_metadata(item_index, {
		META_KIND_COMMAND: COMMAND_SET_SHOW_ALL,
		"property": _show_all_property,
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

	emit_changed(String(_edited_property), StringName(selected_signal))


func _compare_named_options(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("name", "")).naturalnocasecmp_to(String(right.get("name", ""))) < 0


func _add_disabled_item(text: String) -> void:
	_option_button.disabled = true
	_option_button.add_item(text)
	_option_button.set_item_disabled(0, true)
	_option_button.select(0)


func _add_placeholder_item(text: String) -> int:
	_option_button.add_item(text)
	var index = _option_button.get_item_count() - 1
	_option_button.set_item_disabled(index, true)
	return index

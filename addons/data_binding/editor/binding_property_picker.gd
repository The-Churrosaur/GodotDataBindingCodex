@tool
extends EditorProperty

## Custom inspector picker for PropertyBinding data_property and control_property fields.
const PropertyReflection := preload("res://addons/data_binding/editor/property_reflection.gd")

const MODE_DATA_TO_UI := 0
const MODE_UI_TO_DATA := 1
const MODE_TWO_WAY := 2
const MODE_INITIAL_SYNC_ONLY := 3
const META_KIND_COMMAND := "command"
const COMMAND_SET_SHOW_ALL := "set_show_all"

var _binding: Object
var _edited_property := ""
var _target_property := ""
var _target_label := ""
var _option_button: OptionButton


func _init() -> void:
	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.set("fit_to_longest_item", false)
	_option_button.set("text_overrun_behavior", TextServer.OVERRUN_TRIM_ELLIPSIS)
	_option_button.item_selected.connect(_on_item_selected)
	add_child(_option_button)
	add_focusable(_option_button)


## Binds this picker to one reflected property on one target node field.
func setup(binding: Object, edited_property: String, target_property: String, target_label: String) -> void:
	_binding = binding
	_edited_property = edited_property
	_target_property = target_property
	_target_label = target_label
	_rebuild_options()


func _update_property() -> void:
	_rebuild_options()


func _rebuild_options() -> void:
	_option_button.clear()

	if not is_instance_valid(_binding):
		_add_disabled_item("Binding unavailable")
		return

	var target := _binding.get(_target_property) as Object
	if target == null:
		_add_disabled_item("Assign %s first" % _target_label)
		return

	var options := PropertyReflection.get_bindable_properties(
		target,
		_should_include_fallback_control_properties(target),
		_should_include_fallback_data_properties(target)
	)
	if options.is_empty():
		_option_button.disabled = false
		var empty_label := "No reflected properties"
		if not _is_showing_all(target):
			empty_label = "No recommended properties"
		_option_button.add_item(empty_label)
		_option_button.set_item_disabled(0, true)
		_add_show_all_command(target)
		if _option_button.get_item_count() > 1:
			_option_button.select(0)
		else:
			_option_button.disabled = true
		return

	_option_button.disabled = false
	var current_value := StringName(_binding.get(_edited_property))
	var selected_index := -1

	if current_value == &"":
		_option_button.add_item("Select property")
		_option_button.set_item_disabled(0, true)

	var fallback_separator_added := false
	for option in options:
		if bool(option.get("is_fallback", false)) and not fallback_separator_added:
			_option_button.add_separator()
			fallback_separator_added = true

		var property_name := StringName(option.get("name", ""))
		var label := String(option.get("label", property_name))
		var is_compatible := _is_compatible_control_property_option(option)
		if not is_compatible:
			label = "%s (incompatible)" % label

		_option_button.add_item(label)
		var item_index := _option_button.get_item_count() - 1
		_option_button.set_item_metadata(item_index, property_name)
		_option_button.set_item_disabled(item_index, not is_compatible)
		if property_name == current_value:
			selected_index = item_index

	_add_show_all_command(target)

	if selected_index >= 0:
		_option_button.select(selected_index)
	elif current_value != &"":
		_option_button.add_separator()
		_option_button.add_item("%s (missing)" % current_value)
		var missing_index := _option_button.get_item_count() - 1
		_option_button.set_item_disabled(missing_index, true)
		_option_button.select(missing_index)
	else:
		_option_button.select(0)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _option_button.get_item_count():
		return

	var selected_property := _option_button.get_item_metadata(index)
	if selected_property == null:
		return
	if typeof(selected_property) == TYPE_DICTIONARY:
		_handle_command(selected_property)
		return

	emit_changed(_edited_property, StringName(selected_property))


func _should_include_fallback_control_properties(target: Object) -> bool:
	return _edited_property == "control_property" and target is Control and bool(_binding.get("show_all_control_properties"))


func _should_include_fallback_data_properties(target: Object) -> bool:
	return _edited_property == "data_property" and not (target is Control) and bool(_binding.get("show_all_data_properties"))


func _add_show_all_command(target: Object) -> void:
	var flag_property := _get_show_all_flag_property(target)
	if flag_property == &"":
		return

	if _option_button.get_item_count() > 0:
		_option_button.add_separator()

	var is_showing_all := bool(_binding.get(String(flag_property)))
	var label := _get_show_all_label(target, is_showing_all)
	_option_button.add_item(label)
	var item_index := _option_button.get_item_count() - 1
	_option_button.set_item_metadata(item_index, {
		META_KIND_COMMAND: COMMAND_SET_SHOW_ALL,
		"property": flag_property,
		"value": not is_showing_all,
	})


func _get_show_all_flag_property(target: Object) -> StringName:
	if _edited_property == "data_property" and not (target is Control):
		return &"show_all_data_properties"
	if _edited_property == "control_property" and target is Control:
		return &"show_all_control_properties"
	return &""


func _is_showing_all(target: Object) -> bool:
	var flag_property := _get_show_all_flag_property(target)
	return flag_property != &"" and bool(_binding.get(String(flag_property)))


func _get_show_all_label(target: Object, is_showing_all: bool) -> String:
	var option_type := "properties"
	if _edited_property == "data_property" and not (target is Control):
		option_type = "data properties"
	elif _edited_property == "control_property" and target is Control:
		option_type = "control properties"

	if is_showing_all:
		return "Show configured %s only" % option_type
	return "Show all %s" % option_type


func _handle_command(metadata: Dictionary) -> void:
	if metadata.get(META_KIND_COMMAND, "") != COMMAND_SET_SHOW_ALL:
		return

	var flag_property := StringName(metadata.get("property", ""))
	if flag_property == &"":
		return

	var value := bool(metadata.get("value", false))
	_binding.set(flag_property, value)
	_rebuild_options()


func _is_compatible_control_property_option(option: Dictionary) -> bool:
	if _edited_property != "control_property":
		return true
	if not is_instance_valid(_binding):
		return true

	var data_node := _binding.get("data_node") as Object
	var data_property := StringName(_binding.get("data_property"))
	if data_node == null or data_property == &"":
		return true

	var data_type := PropertyReflection.get_property_type(data_node, data_property)
	var control_type := int(option.get("type", TYPE_NIL))
	var converter := _binding.get("converter") as BindingConverter
	var mode := int(_binding.get("mode"))

	match mode:
		MODE_DATA_TO_UI, MODE_INITIAL_SYNC_ONLY:
			return _can_convert_types(data_type, control_type, converter, false)
		MODE_UI_TO_DATA:
			return _can_convert_types(data_type, control_type, converter, true)
		MODE_TWO_WAY:
			return _can_convert_types(data_type, control_type, converter, false) and _can_convert_types(data_type, control_type, converter, true)
		_:
			return _can_convert_types(data_type, control_type, converter, false)


func _can_convert_types(data_type: int, control_type: int, converter: BindingConverter, reverse: bool) -> bool:
	if converter != null:
		if reverse:
			return converter.can_convert_back_types(data_type, control_type)
		return converter.can_convert_types(data_type, control_type)

	if reverse:
		return _types_are_assignable(control_type, data_type)
	return _types_are_assignable(data_type, control_type)


func _types_are_assignable(source_type: int, target_type: int) -> bool:
	if source_type == TYPE_NIL or target_type == TYPE_NIL:
		return true
	if source_type == target_type:
		return true
	if source_type in [TYPE_INT, TYPE_FLOAT] and target_type in [TYPE_INT, TYPE_FLOAT]:
		return true
	if source_type in [TYPE_STRING, TYPE_STRING_NAME] and target_type in [TYPE_STRING, TYPE_STRING_NAME]:
		return true
	return false


func _add_disabled_item(text: String) -> void:
	_option_button.disabled = true
	_option_button.add_item(text)
	_option_button.set_item_disabled(0, true)
	_option_button.select(0)

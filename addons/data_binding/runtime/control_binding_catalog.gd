@tool
extends RefCounted
class_name ControlBindingCatalog

## Loads the exact-class control binding catalog used by editor property and signal pickers.
const CATALOG_PATH := "res://addons/data_binding/config/control_bindings.json"

static var _catalog: Dictionary = {}
static var _is_loaded := false


## Returns cataloged property names for a control's exact native class.
static func get_bindable_properties(control: Control) -> PackedStringArray:
	var properties := PackedStringArray()
	var class_entry := _get_class_entry(control)
	for property_name in class_entry.keys():
		var string_name := String(property_name)
		if not properties.has(string_name):
			properties.append(string_name)
	return properties


## Returns configured, reflected-valid signal options for a control property.
static func get_signal_options(control: Control, property_name: StringName) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if control == null or property_name == &"":
		return options

	var signal_order: Array[StringName] = []
	var default_signal := get_default_signal(control, property_name)
	for signal_name in _get_configured_signal_names(control, property_name):
		if signal_name == &"" or signal_order.has(signal_name) or not control.has_signal(signal_name):
			continue

		signal_order.append(signal_name)
		options.append({
			"name": signal_name,
			"label": String(signal_name),
			"signal": signal_name,
			"argument_count": _get_signal_argument_count(control, signal_name),
			"is_default": signal_name == default_signal,
		})

	return options


## Returns the first configured, reflected-valid signal for a control property.
static func get_default_signal(control: Control, property_name: StringName) -> StringName:
	if control == null or property_name == &"":
		return &""

	for signal_name in _get_configured_signal_names(control, property_name):
		if signal_name != &"" and control.has_signal(signal_name):
			return signal_name

	return &""


## Returns reflected signals for advanced manual signal overrides.
static func get_reflected_signals(control: Control) -> Array[Dictionary]:
	var signals: Array[Dictionary] = []
	if control == null:
		return signals

	for signal_info in control.get_signal_list():
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


static func _get_configured_signal_names(control: Control, property_name: StringName) -> Array[StringName]:
	var signal_names: Array[StringName] = []
	var property_entry := _get_property_entry(control, property_name)
	var signals: Variant = property_entry.get("signals", [])
	if typeof(signals) != TYPE_ARRAY:
		return signal_names

	for signal_entry in signals:
		var signal_name := &""
		if typeof(signal_entry) == TYPE_DICTIONARY:
			signal_name = StringName(signal_entry.get("signal", signal_entry.get("name", "")))
		else:
			signal_name = StringName(signal_entry)

		if signal_name != &"":
			signal_names.append(signal_name)

	return signal_names


static func _get_property_entry(control: Control, property_name: StringName) -> Dictionary:
	var class_entry := _get_class_entry(control)
	var property_key := String(property_name)
	if not class_entry.has(property_key):
		return {}

	var property_entry: Variant = class_entry[property_key]
	if typeof(property_entry) != TYPE_DICTIONARY:
		return {}

	return property_entry


static func _get_class_entry(control: Control) -> Dictionary:
	if control == null:
		return {}

	var catalog := _get_catalog()
	var exact_class := control.get_class()
	if not catalog.has(exact_class):
		return {}

	var class_entry: Variant = catalog[exact_class]
	if typeof(class_entry) != TYPE_DICTIONARY:
		return {}

	return class_entry


static func _get_catalog() -> Dictionary:
	if _is_loaded:
		return _catalog

	_is_loaded = true
	var json_text := FileAccess.get_file_as_string(CATALOG_PATH)
	if json_text.is_empty():
		push_warning("Control binding catalog is empty or missing: %s" % CATALOG_PATH)
		return _catalog

	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Control binding catalog must contain a JSON object: %s" % CATALOG_PATH)
		return _catalog

	_catalog = parsed
	return _catalog


static func _get_signal_argument_count(control: Control, signal_name: StringName) -> int:
	for signal_info in control.get_signal_list():
		if StringName(signal_info.get("name", "")) == signal_name:
			var args: Array = signal_info.get("args", [])
			return args.size()

	return 0


static func _compare_named_options(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("name", "")).naturalnocasecmp_to(String(right.get("name", ""))) < 0

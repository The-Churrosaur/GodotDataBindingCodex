@tool
extends RefCounted
class_name ControlBindingAdapters

## Runtime facade over control catalog and signal reflection helpers.
const ControlBindingCatalogScript := preload("res://addons/data_binding/runtime/control_binding_catalog.gd")


## Resolves the signal to connect for a control property, honoring manual overrides first.
static func resolve_changed_signal(
	control: Control,
	property_name: StringName,
	override_signal: StringName
) -> StringName:
	if override_signal != &"":
		return override_signal

	return ControlBindingCatalogScript.get_default_signal(control, property_name)


## Returns configured signal options for a reflected control property.
static func get_changed_signal_options(control: Control, property_name: StringName) -> Array[Dictionary]:
	return ControlBindingCatalogScript.get_signal_options(control, property_name)


## Returns the configured default changed signal for the control property.
static func get_default_changed_signal(control: Control, property_name: StringName) -> StringName:
	return ControlBindingCatalogScript.get_default_signal(control, property_name)


## Returns all signals reflected from the control.
static func get_reflected_signals(control: Control) -> Array[Dictionary]:
	return ControlBindingCatalogScript.get_reflected_signals(control)


## Returns the number of arguments emitted by a signal.
static func get_signal_argument_count(object: Object, signal_name: StringName) -> int:
	if object == null or signal_name == &"":
		return 0

	for signal_info in object.get_signal_list():
		if StringName(signal_info.get("name", "")) == signal_name:
			var args: Array = signal_info.get("args", [])
			return args.size()

	return 0

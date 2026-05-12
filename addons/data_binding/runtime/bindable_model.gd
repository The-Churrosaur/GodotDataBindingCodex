extends Node
class_name BindableModel

## Emitted when an observed property changes. Bindings listen for this signal in data-to-UI modes.
signal property_changed(property: StringName, value: Variant)


## Emits property_changed for a property. If value is null, the current property value is read.
func notify_property_changed(property: StringName, value: Variant = null) -> void:
	if property == &"":
		push_warning("notify_property_changed() called with an empty property name.")
		return

	var emitted_value := value
	if emitted_value == null:
		emitted_value = get(property)

	property_changed.emit(property, emitted_value)


## Sets a property and emits property_changed when the value actually changes.
func set_bound_property(property: StringName, value: Variant) -> bool:
	if property == &"":
		push_warning("set_bound_property() called with an empty property name.")
		return false

	var old_value := get(property)
	if old_value == value:
		return false

	set(property, value)
	property_changed.emit(property, value)
	return true

@tool
extends RefCounted
class_name BindingReflectionCore

## Runtime-safe reflection helpers shared by binding runtime and editor utilities.


## Returns true when object exposes the property_name in get_property_list().
static func has_property(object: Object, property_name: StringName) -> bool:
	return get_property_info(object, property_name).size() > 0


## Returns the Variant.Type for a reflected property, or TYPE_NIL when unknown.
static func get_property_type(object: Object, property_name: StringName) -> int:
	var property_info := get_property_info(object, property_name)
	if property_info.is_empty():
		return TYPE_NIL
	return int(property_info.get("type", TYPE_NIL))


## Returns the full reflected property dictionary, or {} when unknown.
static func get_property_info(object: Object, property_name: StringName) -> Dictionary:
	if object == null or property_name == &"":
		return {}

	for property_info in object.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return property_info

	return {}

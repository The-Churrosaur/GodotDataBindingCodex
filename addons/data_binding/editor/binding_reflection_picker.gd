@tool
extends RefCounted

## Editor picker reflection and filtering helpers for binding property dropdowns.
const ControlBindingCatalog := preload("res://addons/data_binding/runtime/control_binding_catalog.gd")
const BindingReflectionCore := preload("res://addons/data_binding/runtime/binding_reflection_core.gd")
const PROPERTY_USAGE_BINDABLE := PROPERTY_USAGE_EDITOR


## Returns editor-visible bindable properties. Fallback flags append inherited or uncataloged options.
static func get_bindable_properties(
	object: Object,
	include_uncataloged_control_properties := false,
	include_inherited_data_properties := false
) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if object == null:
		return properties

	var allowed_control_properties := PackedStringArray()
	var allowed_control_property_order := {}
	var limit_to_control_catalog := object is Control
	var limit_to_script_data_properties := not limit_to_control_catalog and not include_inherited_data_properties
	var script_property_names := {}
	if limit_to_control_catalog:
		allowed_control_properties = ControlBindingCatalog.get_bindable_properties(object)
		for index in range(allowed_control_properties.size()):
			allowed_control_property_order[String(allowed_control_properties[index])] = index
	else:
		script_property_names = _get_script_property_names(object)

	for property_info in object.get_property_list():
		if not _is_bindable_property(property_info):
			continue

		var property_name := StringName(property_info.get("name", ""))
		var is_script_variable := _is_script_variable(property_info) or script_property_names.has(String(property_name))
		var is_cataloged_control_property := allowed_control_properties.has(String(property_name))
		var is_fallback_property := false
		if limit_to_control_catalog and not is_cataloged_control_property and not include_uncataloged_control_properties:
			continue
		if limit_to_control_catalog:
			is_fallback_property = not is_cataloged_control_property
		else:
			is_fallback_property = not is_script_variable
			if limit_to_script_data_properties and is_fallback_property:
				continue

		properties.append({
			"name": property_name,
			"label": _format_property_label(property_info),
			"type": int(property_info.get("type", TYPE_NIL)),
			"usage": int(property_info.get("usage", 0)),
			"is_script_variable": is_script_variable,
			"is_cataloged": not limit_to_control_catalog or is_cataloged_control_property,
			"is_fallback": is_fallback_property,
			"catalog_order": allowed_control_property_order.get(String(property_name), -1),
		})

	properties.sort_custom(_compare_property_options)
	return properties


## Returns the Variant.Type for a reflected property, or TYPE_NIL when unknown.
static func get_property_type(object: Object, property_name: StringName) -> int:
	return BindingReflectionCore.get_property_type(object, property_name)


static func _is_bindable_property(property_info: Dictionary) -> bool:
	var property_name := String(property_info.get("name", ""))
	if property_name == "" or property_name.begins_with("_"):
		return false

	var property_type := int(property_info.get("type", TYPE_NIL))
	if property_type == TYPE_NIL:
		return false

	var usage := int(property_info.get("usage", 0))
	return (usage & PROPERTY_USAGE_BINDABLE) != 0


static func _is_script_variable(property_info: Dictionary) -> bool:
	var usage := int(property_info.get("usage", 0))
	return (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0


static func _get_script_property_names(object: Object) -> Dictionary:
	var property_names := {}
	var script := object.get_script()
	if script == null or not script.has_method("get_script_property_list"):
		return property_names

	var script_properties: Variant = script.call("get_script_property_list")
	if typeof(script_properties) != TYPE_ARRAY:
		return property_names

	for property_info in script_properties:
		if typeof(property_info) != TYPE_DICTIONARY:
			continue

		var property_name := String(property_info.get("name", ""))
		if property_name != "":
			property_names[property_name] = true

	return property_names


static func _format_property_label(property_info: Dictionary) -> String:
	var property_name := String(property_info.get("name", ""))
	var property_type := int(property_info.get("type", TYPE_NIL))
	var type_label := _type_name(property_type)
	if type_label == "":
		return property_name
	return "%s (%s)" % [property_name, type_label]


static func _type_name(property_type: int) -> String:
	match property_type:
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_STRING_NAME:
			return "StringName"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR3I:
			return "Vector3i"
		TYPE_COLOR:
			return "Color"
		TYPE_NODE_PATH:
			return "NodePath"
		TYPE_OBJECT:
			return "Object"
		TYPE_ARRAY:
			return "Array"
		TYPE_DICTIONARY:
			return "Dictionary"
		_:
			return ""


static func _compare_property_options(left: Dictionary, right: Dictionary) -> bool:
	var left_is_fallback := bool(left.get("is_fallback", false))
	var right_is_fallback := bool(right.get("is_fallback", false))
	if left_is_fallback != right_is_fallback:
		return not left_is_fallback

	var left_catalog_order := int(left.get("catalog_order", -1))
	var right_catalog_order := int(right.get("catalog_order", -1))
	if left_catalog_order != right_catalog_order and left_catalog_order >= 0 and right_catalog_order >= 0:
		return left_catalog_order < right_catalog_order

	var left_is_script := bool(left.get("is_script_variable", false))
	var right_is_script := bool(right.get("is_script_variable", false))
	if left_is_script != right_is_script:
		return left_is_script

	return String(left.get("name", "")).naturalnocasecmp_to(String(right.get("name", ""))) < 0

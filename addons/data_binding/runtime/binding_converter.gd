@tool
extends Resource
class_name BindingConverter

## Whether this converter can transform target/control values back into source/data values.
@export var reversible := true


## Converts a source/data value into a target/control value.
func to_target(value: Variant) -> Variant:
	return value


## Converts a target/control value back into a source/data value.
func to_source(value: Variant) -> Variant:
	return value


## Returns true when two-way or UI-to-data bindings can call to_source().
func can_convert_back() -> bool:
	return reversible


## Returns true when this converter can map source_type into target_type.
func can_convert_types(source_type: int, target_type: int) -> bool:
	return _types_are_assignable(source_type, target_type)


## Returns true when this converter can map target_type back into source_type.
func can_convert_back_types(source_type: int, target_type: int) -> bool:
	return reversible and _types_are_assignable(target_type, source_type)


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

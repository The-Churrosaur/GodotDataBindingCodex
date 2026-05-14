@tool
extends RefCounted
class_name BindingTypeCompatibility

## Shared type-compatibility helpers used by runtime validation and editor pickers.
const MODE_DATA_TO_UI := 0
const MODE_UI_TO_DATA := 1
const MODE_TWO_WAY := 2
const MODE_INITIAL_SYNC_ONLY := 3


## Returns whether the selected data/control property types are valid for the binding mode.
static func are_types_compatible_for_mode(
	mode: int,
	data_type: int,
	control_type: int,
	converter: Variant
) -> bool:
	match mode:
		MODE_DATA_TO_UI, MODE_INITIAL_SYNC_ONLY:
			return can_convert_types(data_type, control_type, converter, false)
		MODE_UI_TO_DATA:
			return can_convert_types(data_type, control_type, converter, true)
		MODE_TWO_WAY:
			return can_convert_types(data_type, control_type, converter, false) and can_convert_types(data_type, control_type, converter, true)
		_:
			return can_convert_types(data_type, control_type, converter, false)


## Returns whether conversion is possible in the selected direction.
static func can_convert_types(
	data_type: int,
	control_type: int,
	converter: Variant,
	reverse: bool
) -> bool:
	if converter != null:
		if reverse:
			return converter.can_convert_back_types(data_type, control_type)
		return converter.can_convert_types(data_type, control_type)

	if reverse:
		return types_are_assignable(control_type, data_type)
	return types_are_assignable(data_type, control_type)


## Returns whether a source Variant.Type is assignable to a target Variant.Type.
static func types_are_assignable(source_type: int, target_type: int) -> bool:
	if source_type == TYPE_NIL or target_type == TYPE_NIL:
		return true
	if source_type == target_type:
		return true
	if source_type in [TYPE_INT, TYPE_FLOAT] and target_type in [TYPE_INT, TYPE_FLOAT]:
		return true
	if source_type in [TYPE_STRING, TYPE_STRING_NAME] and target_type in [TYPE_STRING, TYPE_STRING_NAME]:
		return true
	return false

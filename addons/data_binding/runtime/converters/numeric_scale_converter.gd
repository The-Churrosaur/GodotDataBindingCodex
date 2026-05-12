@tool
extends BindingConverter
class_name NumericScaleConverter

## Multiplies the source value before writing it to the control.
@export var target_multiplier := 1.0
## Adds this value after multiplying the source value.
@export var target_offset := 0.0


## Applies target_multiplier and target_offset to a numeric source value.
func to_target(value: Variant) -> Variant:
	return float(value) * target_multiplier + target_offset


## Reverses the numeric scale transform for UI-to-data updates.
func to_source(value: Variant) -> Variant:
	if is_zero_approx(target_multiplier):
		return 0.0
	return (float(value) - target_offset) / target_multiplier


## Returns false when target_multiplier is zero and the transform cannot be reversed.
func can_convert_back() -> bool:
	return not is_zero_approx(target_multiplier)


## Allows this converter only for int and float property pairs.
func can_convert_types(source_type: int, target_type: int) -> bool:
	return _is_numeric_type(source_type) and _is_numeric_type(target_type)


## Allows reverse conversion only when the numeric transform is reversible.
func can_convert_back_types(source_type: int, target_type: int) -> bool:
	return can_convert_back() and can_convert_types(target_type, source_type)


func _is_numeric_type(type: int) -> bool:
	return type == TYPE_INT or type == TYPE_FLOAT

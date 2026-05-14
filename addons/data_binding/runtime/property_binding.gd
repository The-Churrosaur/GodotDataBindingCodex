@tool
extends Node
class_name PropertyBinding

## Connects one data node property to one UI Control property.
const ControlBindingAdaptersScript := preload("res://addons/data_binding/runtime/control_binding_adapters.gd")
const BindingTypeCompatibilityScript := preload("res://addons/data_binding/runtime/binding_type_compatibility.gd")
const BindingReflectionCoreScript := preload("res://addons/data_binding/runtime/binding_reflection_core.gd")

enum BindingMode {
	DATA_TO_UI,
	UI_TO_DATA,
	TWO_WAY,
	INITIAL_SYNC_ONLY,
}

enum InitialSync {
	NONE,
	DATA_TO_UI,
	UI_TO_DATA,
}

enum DataUpdateSource {
	SIGNAL_ONLY,
	POLLING,
	MANUAL,
}

const DATA_CHANGED_SIGNAL := &"property_changed"

## Enables this binding at runtime.
@export var enabled := true
## Controls which direction values flow between the data node and control node.
@export_enum("Data -> UI", "UI -> Data", "Two Way", "Initial Sync Only") var mode: int = BindingMode.DATA_TO_UI:
	set(value):
		if mode == value:
			return
		mode = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Optional initial value sync performed after runtime connections are made.
@export_enum("None", "Data -> UI", "UI -> Data") var initial_sync: int = InitialSync.DATA_TO_UI


## Node containing the data property.
@export var data_node: Node:
	set(value):
		if data_node == value:
			return
		data_node = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Control node containing the UI property.
@export var control_node: Control:
	set(value):
		if control_node == value:
			return
		control_node = value
		if Engine.is_editor_hint():
			notify_property_list_changed()

## Reflected property name on data_node.
@export var data_property: StringName = &"":
	set(value):
		if data_property == value:
			return
		data_property = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Reflected property name on control_node.
@export var control_property: StringName = &"":
	set(value):
		if control_property == value:
			return
		control_property = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Optional converter that maps between data and control value representations.
@export var converter: BindingConverter:
	set(value):
		if converter == value:
			return
		converter = value
		if Engine.is_editor_hint():
			notify_property_list_changed()

## Chooses how live data-to-UI updates are detected after initial sync.
@export_enum("Signal Only", "Polling", "Manual") var data_update_source: int = DataUpdateSource.SIGNAL_ONLY:
	set(value):
		if data_update_source == value:
			return
		data_update_source = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Signal on data_node that triggers refresh_from_data().
## Signal arguments are ignored; the binding reads data_property when the signal fires.
@export var data_changed_signal: StringName = DATA_CHANGED_SIGNAL:
	set(value):
		if data_changed_signal == value:
			return
		data_changed_signal = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Interval, in seconds, for polling data properties when polling is active.
@export_range(0.05, 5.0, 0.05, "suffix:s") var data_poll_interval := 0.25:
	set(value):
		data_poll_interval = maxf(value, 0.05)
## Manual signal override for custom controls. Empty uses the configured default signal.
@export var control_changed_signal: StringName = &"":
	set(value):
		if control_changed_signal == value:
			return
		control_changed_signal = value
		if Engine.is_editor_hint():
			notify_property_list_changed()

@export_group("Runtime Binding")
## Rebuilds this binding automatically from _ready() during runtime.
@export var rebind_on_ready := false
## Prints runtime validation warnings when a binding cannot be rebuilt.
@export var warn_on_invalid := true

## Editor-only picker state for showing fallback data properties.
var show_all_data_properties := false
## Editor-only picker state for showing inherited/reflected data signals.
var show_all_data_signals := false
## Editor-only picker state for showing fallback control properties.
var show_all_control_properties := false
## Editor-only picker state for showing reflected control signals.
var show_all_control_signals := false

var _updating := false
var _connected_data_node: Node
var _connected_data_signal := &""
var _connected_control_node: Control
var _connected_control_signal := &""
var _connected_control_callable: Callable
var _connected_data_callable: Callable
var _is_polling_data := false
var _poll_elapsed := 0.0
var _last_polled_value: Variant


func _init() -> void:
	_connected_data_callable = Callable(self, "_on_data_changed")


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	if rebind_on_ready:
		rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _is_polling_data:
		return

	_poll_elapsed += delta
	if _poll_elapsed < data_poll_interval:
		return

	_poll_elapsed = 0.0
	_poll_data_property()


func _exit_tree() -> void:
	disconnect_binding()


func _validate_property(property: Dictionary) -> void:
	var property_name := StringName(property.get("name", ""))
	if property_name == &"data_update_source" and not _uses_live_data_to_ui_updates():
		property["usage"] = int(property.get("usage", PROPERTY_USAGE_DEFAULT)) | PROPERTY_USAGE_READ_ONLY
	if property_name == &"data_poll_interval" and not _uses_data_poll_interval():
		property["usage"] = PROPERTY_USAGE_NO_EDITOR
	if property_name == &"data_changed_signal" and (not _uses_live_data_to_ui_updates() or data_update_source != DataUpdateSource.SIGNAL_ONLY):
		property["usage"] = PROPERTY_USAGE_NO_EDITOR


## Disconnects existing listeners, validates settings, reconnects listeners, and applies initial sync.
func rebuild() -> void:
	disconnect_binding()

	if Engine.is_editor_hint():
		return

	if not enabled:
		return

	var issues := validate()
	if warn_on_invalid:
		for issue in issues:
			push_warning("%s: %s" % [get_path(), issue])

	if issues.size() > 0:
		return

	if _should_connect_data_changed_signal():
		_connect_data_changed_signal()
	elif _should_poll_data():
		_start_data_polling()

	if _uses_ui_to_data():
		_connect_control_changed_signal()

	match initial_sync:
		InitialSync.DATA_TO_UI:
			if _can_read_data() and _can_write_control():
				refresh_from_data()
		InitialSync.UI_TO_DATA:
			if _can_read_control() and _can_write_data():
				commit_to_data()

	if _is_polling_data:
		_reset_data_poll_snapshot()


## Disconnects signal listeners created by rebuild().
func disconnect_binding() -> void:
	_stop_data_polling()

	if _connected_data_node != null and _connected_data_signal != &"" and not _connected_data_callable.is_null():
		if _connected_data_node.is_connected(_connected_data_signal, _connected_data_callable):
			_connected_data_node.disconnect(_connected_data_signal, _connected_data_callable)

	if _connected_control_node != null and _connected_control_signal != &"" and not _connected_control_callable.is_null():
		if _connected_control_node.is_connected(_connected_control_signal, _connected_control_callable):
			_connected_control_node.disconnect(_connected_control_signal, _connected_control_callable)

	_connected_data_node = null
	_connected_data_signal = &""
	_connected_control_node = null
	_connected_control_signal = &""
	_connected_control_callable = Callable()
	_connected_data_callable = Callable(self, "_on_data_changed")


## Pulls the current data value, converts it, and writes it to the control property.
func refresh_from_data() -> void:
	if _updating or not _can_read_data() or not _can_write_control():
		return

	var data_value := data_node.get(data_property)
	var target_value := _convert_to_target(data_value)
	if _values_equal(control_node.get(control_property), target_value):
		return

	_updating = true
	control_node.set(control_property, target_value)
	_updating = false


## Pulls the current control value, converts it, and writes it to the data property.
func commit_to_data() -> void:
	if _updating or not _can_read_control() or not _can_write_data():
		return

	var control_value := control_node.get(control_property)
	var source_value := _convert_to_source(control_value)
	if _values_equal(data_node.get(data_property), source_value):
		return

	_updating = true
	data_node.set(data_property, source_value)
	_updating = false


## Returns validation issues that would prevent this binding from connecting cleanly.
func validate() -> PackedStringArray:
	var issues := PackedStringArray()

	if data_node == null:
		issues.append("Data node is not assigned.")
	if control_node == null:
		issues.append("Control node is not assigned.")
	if data_property == &"":
		issues.append("Data property is empty.")
	if control_property == &"":
		issues.append("Control property is empty.")

	if data_node != null and data_property != &"" and not BindingReflectionCoreScript.has_property(data_node, data_property):
		issues.append("Data property '%s' was not found on %s." % [data_property, data_node.name])

	if control_node != null and control_property != &"" and not BindingReflectionCoreScript.has_property(control_node, control_property):
		issues.append("Control property '%s' was not found on %s." % [control_property, control_node.name])

	if _can_read_data() and _can_read_control() and not _selected_property_types_are_compatible():
		issues.append("Data property '%s' and control property '%s' have incompatible types for the selected converter." % [
			data_property,
			control_property,
		])

	if _uses_live_data_to_ui_updates():
		if data_update_source == DataUpdateSource.SIGNAL_ONLY:
			var signal_issue := _data_changed_signal_validation_issue()
			if signal_issue != "":
				issues.append(signal_issue)

	if _uses_ui_to_data():
		if converter != null and not converter.can_convert_back():
			issues.append("UI -> Data requires a reversible converter.")

		if control_node != null:
			var signal_name := _get_control_changed_signal()
			if signal_name == &"":
				issues.append("No control change signal is configured for this control property.")
			elif not control_node.has_signal(signal_name):
				issues.append("Control signal '%s' was not found on %s." % [signal_name, control_node.name])

	return issues


func _connect_data_changed_signal() -> void:
	var signal_name := _get_data_changed_signal()
	if data_node == null or signal_name == &"" or not data_node.has_signal(signal_name):
		return

	var callback := Callable(self, "_on_data_changed")
	var argument_count := ControlBindingAdaptersScript.get_signal_argument_count(data_node, signal_name)
	if argument_count > 0:
		callback = callback.unbind(argument_count)

	if not data_node.is_connected(signal_name, callback):
		data_node.connect(signal_name, callback)

	_connected_data_node = data_node
	_connected_data_signal = signal_name
	_connected_data_callable = callback


func _connect_control_changed_signal() -> void:
	var signal_name := _get_control_changed_signal()
	if control_node == null or signal_name == &"":
		return

	var callback := Callable(self, "_on_control_changed")
	var argument_count := ControlBindingAdaptersScript.get_signal_argument_count(control_node, signal_name)
	if argument_count > 0:
		callback = callback.unbind(argument_count)

	if not control_node.is_connected(signal_name, callback):
		control_node.connect(signal_name, callback)

		_connected_control_node = control_node
		_connected_control_signal = signal_name
		_connected_control_callable = callback


func _start_data_polling() -> void:
	if data_node == null or data_property == &"":
		return

	_is_polling_data = true
	_poll_elapsed = 0.0
	_reset_data_poll_snapshot()
	set_process(true)


func _stop_data_polling() -> void:
	_is_polling_data = false
	_poll_elapsed = 0.0
	_last_polled_value = null
	set_process(false)


func _poll_data_property() -> void:
	if _updating or not _can_read_data():
		return

	var current_value := data_node.get(data_property)
	if _values_equal(current_value, _last_polled_value):
		return

	_last_polled_value = _snapshot_value(current_value)
	refresh_from_data()


func _reset_data_poll_snapshot() -> void:
	if not _can_read_data():
		_last_polled_value = null
		return

	_last_polled_value = _snapshot_value(data_node.get(data_property))


func _on_data_changed() -> void:
	refresh_from_data()


func _on_control_changed() -> void:
	commit_to_data()


func _get_control_changed_signal() -> StringName:
	return ControlBindingAdaptersScript.resolve_changed_signal(
		control_node,
		control_property,
		control_changed_signal
	)


func _get_data_changed_signal() -> StringName:
	return data_changed_signal


func _data_changed_signal_validation_issue() -> String:
	if data_node == null:
		return ""

	var signal_name := _get_data_changed_signal()
	if signal_name == &"":
		return "No valid data changed signal selected."
	if not data_node.has_signal(signal_name):
		return "No valid data changed signal selected. Data signal '%s' was not found on %s." % [
			signal_name,
			data_node.name,
		]

	return ""


func _should_connect_data_changed_signal() -> bool:
	if not _uses_live_data_to_ui_updates():
		return false

	match data_update_source:
		DataUpdateSource.SIGNAL_ONLY:
			var signal_name := _get_data_changed_signal()
			return data_node != null and signal_name != &"" and data_node.has_signal(signal_name)
		_:
			return false


func _should_poll_data() -> bool:
	if not _uses_live_data_to_ui_updates():
		return false

	match data_update_source:
		DataUpdateSource.POLLING:
			return true
		_:
			return false


func _uses_data_poll_interval() -> bool:
	return _uses_live_data_to_ui_updates() and data_update_source == DataUpdateSource.POLLING


func _uses_data_to_ui() -> bool:
	return mode == BindingMode.DATA_TO_UI or mode == BindingMode.TWO_WAY or mode == BindingMode.INITIAL_SYNC_ONLY


func _uses_live_data_to_ui_updates() -> bool:
	return _uses_data_to_ui() and mode != BindingMode.INITIAL_SYNC_ONLY


func _uses_ui_to_data() -> bool:
	return mode == BindingMode.UI_TO_DATA or mode == BindingMode.TWO_WAY


func _can_read_data() -> bool:
	return data_node != null and data_property != &"" and BindingReflectionCoreScript.has_property(data_node, data_property)


func _can_write_data() -> bool:
	return _can_read_data()


func _can_read_control() -> bool:
	return control_node != null and control_property != &"" and BindingReflectionCoreScript.has_property(control_node, control_property)


func _can_write_control() -> bool:
	return _can_read_control()


func _selected_property_types_are_compatible() -> bool:
	var data_type := BindingReflectionCoreScript.get_property_type(data_node, data_property)
	var control_type := BindingReflectionCoreScript.get_property_type(control_node, control_property)
	return BindingTypeCompatibilityScript.are_types_compatible_for_mode(mode, data_type, control_type, converter)


func _convert_to_target(value: Variant) -> Variant:
	if converter == null:
		return value
	return converter.to_target(value)


func _convert_to_source(value: Variant) -> Variant:
	if converter == null:
		return value
	return converter.to_source(value)


func _values_equal(left: Variant, right: Variant) -> bool:
	return left == right


func _snapshot_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.duplicate(true)
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			return dictionary_value.duplicate(true)
		_:
			return value

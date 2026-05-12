@tool
extends EditorInspectorPlugin

## Inspector customizations for PropertyBinding and BindingHost nodes.
const BindingPropertyPicker := preload("res://addons/data_binding/editor/binding_property_picker.gd")
const BindingSignalPicker := preload("res://addons/data_binding/editor/binding_signal_picker.gd")

var _editor_plugin: EditorPlugin


## Supplies editor services used by custom inspector controls.
func setup(editor_plugin: EditorPlugin) -> void:
	_editor_plugin = editor_plugin


func _can_handle(object: Object) -> bool:
	return object is PropertyBinding or object is BindingHost


func _parse_property(
	object: Object,
	type: int,
	name: String,
	hint_type: int,
	hint_string: String,
	usage_flags: int,
	wide: bool
) -> bool:
	if object is PropertyBinding and name == "data_property":
		add_property_editor(name, _make_property_picker(object, name, "data_node", "data_node"))
		return true

	if object is PropertyBinding and name == "control_property":
		add_property_editor(name, _make_property_picker(object, name, "control_node", "control_node"))
		return true

	if object is PropertyBinding and name == "control_changed_signal":
		add_property_editor(name, _make_signal_picker(object))
		return true

	return false


func _parse_begin(object: Object) -> void:
	var issues := _status_issues(object)
	var status_panel := PanelContainer.new()
	if not issues.is_empty():
		status_panel.add_theme_stylebox_override("panel", _invalid_status_style())
	
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = _status_text(object, issues)
	if not issues.is_empty():
		status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28))
	status_panel.add_child(status)

	add_custom_control(status_panel)

	if object is BindingHost:
		add_custom_control(_make_create_binding_button(object))


func _status_issues(object: Object) -> PackedStringArray:
	if object is PropertyBinding:
		return object.validate()

	if object is BindingHost:
		return object.validate_bindings()

	return PackedStringArray()


func _status_text(object: Object, issues: PackedStringArray) -> String:
	var label := "Binding status"
	if object is BindingHost:
		label = "Binding host status"

	if issues.is_empty():
		return "%s: OK." % label

	return "%s: Invalid\n- %s" % [label, "\n- ".join(issues)]


func _invalid_status_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.45, 0.08, 0.06, 0.18)
	style.border_color = Color(1.0, 0.3, 0.22, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _make_create_binding_button(host: BindingHost) -> Control:
	var button := Button.new()
	button.text = "Add PropertyBinding Child"
	button.tooltip_text = "Create a new PropertyBinding node under this BindingHost."
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _editor_plugin == null or not is_instance_valid(host):
		button.disabled = true
	else:
		var add_icon := button.get_theme_icon("Add", "EditorIcons")
		if add_icon != null:
			button.icon = add_icon
		button.pressed.connect(_on_create_binding_pressed.bind(host))
	return button


func _on_create_binding_pressed(host: BindingHost) -> void:
	if _editor_plugin == null or not is_instance_valid(host):
		return

	var scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return

	var binding := PropertyBinding.new()
	binding.name = _get_next_binding_name(host)

	var owner := host.owner
	if owner == null:
		owner = scene_root

	var selection := _editor_plugin.get_editor_interface().get_selection()
	var undo_redo := _editor_plugin.get_undo_redo()
	undo_redo.create_action("Add PropertyBinding Child")
	undo_redo.add_do_method(host, "add_child", binding)
	undo_redo.add_do_method(binding, "set_owner", owner)
	undo_redo.add_do_method(selection, "clear")
	undo_redo.add_do_method(selection, "add_node", binding)
	undo_redo.add_undo_method(selection, "clear")
	undo_redo.add_undo_method(binding, "set_owner", null)
	undo_redo.add_undo_method(host, "remove_child", binding)
	undo_redo.add_do_reference(binding)
	undo_redo.commit_action()


func _get_next_binding_name(host: BindingHost) -> String:
	var base_name := "PropertyBinding"
	if not host.has_node(base_name):
		return base_name

	var index := 2
	while host.has_node("%s%d" % [base_name, index]):
		index += 1

	return "%s%d" % [base_name, index]


func _make_property_picker(
	binding: PropertyBinding,
	edited_property: String,
	target_property: String,
	target_label: String
) -> EditorProperty:
	var picker := BindingPropertyPicker.new()
	picker.setup(binding, edited_property, target_property, target_label)
	return picker


func _make_signal_picker(binding: PropertyBinding) -> EditorProperty:
	var picker := BindingSignalPicker.new()
	picker.setup(binding)
	return picker

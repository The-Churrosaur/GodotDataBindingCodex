@tool
extends EditorPlugin

## Registers the data binding runtime types and inspector extensions with the editor.
const BindableModelScript := preload("res://addons/data_binding/runtime/bindable_model.gd")
const BindingConverterScript := preload("res://addons/data_binding/runtime/binding_converter.gd")
const PropertyBindingScript := preload("res://addons/data_binding/runtime/property_binding.gd")
const BindingHostScript := preload("res://addons/data_binding/runtime/binding_host.gd")
const NumericScaleConverterScript := preload("res://addons/data_binding/runtime/converters/numeric_scale_converter.gd")
const BindingInspectorPluginScript := preload("res://addons/data_binding/editor/binding_inspector_plugin.gd")

var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	add_custom_type("BindableModel", "Node", BindableModelScript, null)
	add_custom_type("BindingConverter", "Resource", BindingConverterScript, null)
	add_custom_type("NumericScaleConverter", "Resource", NumericScaleConverterScript, null)
	add_custom_type("BindingHost", "Node", BindingHostScript, null)
	add_custom_type("PropertyBinding", "Node", PropertyBindingScript, null)

	_inspector_plugin = BindingInspectorPluginScript.new()
	_inspector_plugin.setup(self)
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null

	remove_custom_type("PropertyBinding")
	remove_custom_type("BindingHost")
	remove_custom_type("NumericScaleConverter")
	remove_custom_type("BindingConverter")
	remove_custom_type("BindableModel")

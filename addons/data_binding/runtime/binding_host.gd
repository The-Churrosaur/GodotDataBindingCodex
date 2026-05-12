@tool
extends Node
class_name BindingHost

## Enables runtime auto-binding for this host.
@export var enabled := true
## Rebuilds child PropertyBinding nodes from _ready() during runtime.
@export var auto_bind_children := true
## Allows get_bindings() to recurse into nested BindingHost nodes.
@export var include_nested_hosts := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if enabled and auto_bind_children:
		rebuild_bindings()


## Rebuilds all child PropertyBinding nodes owned by this host.
func rebuild_bindings() -> void:
	for binding in get_bindings():
		binding.rebuild()


## Disconnects all child PropertyBinding nodes owned by this host.
func disconnect_bindings() -> void:
	for binding in get_bindings():
		binding.disconnect_binding()


## Returns validation issues for all child PropertyBinding nodes.
func validate_bindings() -> PackedStringArray:
	var issues := PackedStringArray()
	for binding in get_bindings():
		for issue in binding.validate():
			issues.append("%s: %s" % [binding.name, issue])
	return issues


## Returns child PropertyBinding nodes, optionally including bindings under nested hosts.
func get_bindings() -> Array[PropertyBinding]:
	var bindings: Array[PropertyBinding] = []
	_collect_bindings(self, bindings)
	return bindings


func _collect_bindings(node: Node, bindings: Array[PropertyBinding]) -> void:
	for child in node.get_children():
		if child is PropertyBinding:
			bindings.append(child)
			continue

		if child is BindingHost and child != self and not include_nested_hosts:
			continue

		_collect_bindings(child, bindings)

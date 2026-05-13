# Godot Data Binding

Godot Data Binding is a Godot editor addon for connecting data node properties to UI `Control` node properties directly in the editor.

The addon provides node-based bindings, curated control property and signal pickers, optional converters, and runtime helpers for one-way, two-way, and initial-sync-only UI binding flows.

## Installation

1. Copy `addons/data_binding` into your Godot project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Data Binding**.

## Runtime Pieces

- `BindableModel` is an optional base class for data nodes that can notify bindings when a property changes.
- `PropertyBinding` is a node that connects one data property to one control property.
- `BindingHost` is a grouping node that can rebuild, disconnect, and validate child bindings.
- `BindingConverter` is a reusable `Resource` for translating values between data and UI representations.
- `NumericScaleConverter` maps numeric ranges, such as `0.0..1.0` in data to `0..100` in a slider.

## Editor Property Lists

Data node property pickers reflect editor-visible properties directly from the assigned data node.

Control node property pickers are intentionally curated so common controls do not expose every inherited `Control` property. Edit `res://addons/data_binding/config/control_bindings.json` to add or remove bindable properties for exact built-in control types.

Control changed signals are catalog-driven by exact control type and property. Add a `signals` array under a cataloged property in `res://addons/data_binding/config/control_bindings.json` to configure update signals. The first reflected-valid signal is the default, and `control_changed_signal` can still be used as a manual override for custom controls.

Leaving `control_changed_signal` empty means the binding will use the first configured signal for the selected control type and property.

Use the `Show all...` entries in the data property, control property, and control signal pickers to append fallback options without cluttering the inspector.

## Binding Modes

- `Data -> UI` listens to `property_changed(property, value)` on the data node and writes to the control.
- `UI -> Data` listens only to the control change signal and writes to the data node. The data node does not need to implement `property_changed`.
- `Two Way` connects both sides and uses a reentrancy guard to avoid echo loops.
- `Initial Sync Only` performs the configured initial sync without listening for later changes.

## Quick Start

1. Add a `BindingHost` near the UI controls it owns.
2. Add `PropertyBinding` children under the host.
3. Assign `data_node`, `data_property`, `control_node`, and `control_property`.
4. Use `UI -> Data` for plain nodes that do not emit `property_changed`.
5. Use `Data -> UI` or `Two Way` for nodes that extend `BindableModel` or otherwise emit `property_changed(property, value)`.

See `res://addons/data_binding/samples/data_binding_sample.tscn` for a small scene containing both observable data bindings and one-way UI-to-data bindings.

## License

MIT. See `LICENSE.md`.

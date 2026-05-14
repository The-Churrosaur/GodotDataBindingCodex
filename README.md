# Godot Data Binding

Godot Data Binding is a Godot editor addon for connecting data node properties to UI `Control` node properties directly in the editor.

The addon provides node-based bindings, curated control property and signal pickers, optional converters, and runtime helpers for one-way, two-way, and initial-sync-only UI binding flows.

## Installation

1. Copy `addons/data_binding` into your Godot project.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Data Binding**.

## Runtime Pieces

- `PropertyBinding` is a node that connects one data property to one control property.
- `BindingHost` is a grouping node that can rebuild, disconnect, and validate child bindings.
- `BindingConverter` is a reusable `Resource` for translating values between data and UI representations.

## Editor Property Lists

Data node property pickers reflect editor-visible `Export` tagged properties directly from the assigned data node.

Control node property pickers are intentionally curated so common controls do not expose every inherited `Control` property. Edit `res://addons/data_binding/config/control_bindings.json` to add or remove bindable properties for exact built-in control types.

Control changed signals are catalog-driven by exact control type and property. Add a `signals` array under a cataloged property in `res://addons/data_binding/config/control_bindings.json` to configure update signals. The first reflected-valid signal is the default, and `control_changed_signal` can still be used as a manual override for custom controls.

Leaving `control_changed_signal` empty means the binding will use the first configured signal for the selected control type and property.

Data changed signals are reflected from the selected data node's script class. `data_changed_signal` defaults to `property_changed`, but the selected signal is used only as a notification trigger: signal arguments are ignored and the binding reads `data_property` when the signal fires. Use the `Show all data signals` entry to include inherited engine signals.

Use the `Show all...` entries in the data property, data signal, control property, and control signal pickers to append fallback options without cluttering the inspector.

## Binding Modes

- `Data -> UI` listens for data changes and writes to the control.
- `UI -> Data` listens only to the control change signal and writes to the data node.
- `Two Way` connects both sides and uses a reentrancy guard to avoid echo loops.
- `Initial Sync Only` performs the configured initial sync without listening for later changes.

## Data Update Sources

`PropertyBinding.data_update_source` controls how live data-to-UI updates are detected:

- `Signal Only` requires the data node to expose the selected `data_changed_signal`. This is the default.
- `Polling` always checks the reflected data property at `data_poll_interval`. Use sparingly - incurs a performance cost.
- `Manual` does not connect a live listener; call `refresh_from_data()` when the UI should update.

## Quick Start

1. Add a `BindingHost` near the UI controls it owns.
2. Add `PropertyBinding` children under the host or press `BindingHost`'s `Add PropertyBinding Child` button in the inspector.
3. Assign `data_node`, `data_property`, `control_node`, and `control_property`.
4. Assign an appropriate (Binding) `Mode`.
5. Assign `data_update_source`, `data_changed_signal`, and `control_changed_signal` as necessary according to your `Mode`.


See `res://addons/data_binding/samples/data_binding_sample.tscn` for a small scene containing observable bindings, one-way UI-to-data bindings for signal-free plain data, and a custom data-signal binding.

## License

MIT. See `LICENSE.md`.

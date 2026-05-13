extends BindableModel

## Custom signal used by the sample to demonstrate data update signals beyond property_changed.
signal title_changed()

## Example string data property used by the sample LineEdit binding.
@export var player_name := "Ada":
	set(value):
		if player_name == value:
			return
		player_name = value
		notify_property_changed(&"player_name", player_name)

## Example numeric data property used by the sample slider binding.
@export var health := 75.0:
	set(value):
		if health == value:
			return
		health = value
		notify_property_changed(&"health", health)

## Example boolean data property used by the sample checkbox binding.
@export var invincible := false:
	set(value):
		if invincible == value:
			return
		invincible = value
		notify_property_changed(&"invincible", invincible)

## Example property that notifies through a custom signal instead of property_changed.
@export var title := "Custom signal ready":
	set(value):
		if title == value:
			return
		title = value
		title_changed.emit()

extends BindableModel

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

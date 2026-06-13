extends Node

# Power
var power: float = 100.0
var power_drain_base: float = 0.5   # per second
var doors_open: bool = false         # true = door is CLOSED

# Night timer
var current_hour: int = 12
var night_over: bool = false

# Animatronic locations (room names as strings)
var animatronic_positions: Dictionary = {
	"FreddyMarcus": "Show Stage",
	"BonnieJake": "Show Stage",
	"ChicaJasker": "Show Stage",
	"FoxyBlitz":  "Balls HQ"
}

func get_power_drain() -> float:
	var drain = power_drain_base
	if doors_open:
		drain += 0.3
	return drain

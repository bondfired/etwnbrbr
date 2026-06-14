extends Node

var power: float = 100.0
var power_drain_base: float = 0.5
var doors_open: bool = false
var camera_open: bool = false
var current_hour: int = 12
var night_number: int = 1
var nights_completed: Array = [false, false, false, false, false, false]
var is_custom_night: bool = false
var custom_ai: Dictionary = {
	"BonnieJake": 5,
	"ChicaJasker": 5,
	"FreddyMarcus": 5,
	"FoxyBlitz": 5,
	"Doggie": 5,
	"Astro": 5,
	"BFB": 5,
	"Goku": 5
}

func get_power_drain() -> float:
	var drain = power_drain_base
	if doors_open:
		drain += 0.3
	if camera_open:
		drain += 0.2
	return drain

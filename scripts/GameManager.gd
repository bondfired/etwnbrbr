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
	"Jake": 5,
	"Jasker": 5,
	"Marcus": 5,
	"Blitz": 5,
	"Doggie": 5,
	"Astro": 5,
	"BFB": 5,
	"Goku": 5,
	"Owen": 5,
	"Tung": 5,
	"Kolzaru": 5,
	"Jace": 5
}

func get_power_drain() -> float:
	var drain = power_drain_base
	if doors_open:
		drain += 0.3
	if camera_open:
		drain += 0.2
	return drain

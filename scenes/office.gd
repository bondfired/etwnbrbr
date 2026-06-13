extends Node2D

# @onready waits until the scene is fully loaded, then grabs the node
@onready var left_door   = $LeftDoor
@onready var right_door  = $RightDoor
@onready var power_label = $PowerLabel
@onready var hour_label  = $HourLabel
@onready var night_timer = $NightTimer

var left_door_closed  = false
var right_door_closed = false
var game_over: bool = false

func _ready():
	night_timer.wait_time = 45.0
	night_timer.start()
	night_timer.timeout.connect(_on_hour_passed)

func _process(delta):
	if game_over:
		return
	GameManager.power -= GameManager.get_power_drain() * delta
	GameManager.power = clamp(GameManager.power, 0, 100)

	power_label.text = "Power: %d%%" % int(GameManager.power)
	hour_label.text  = "%d AM" % GameManager.current_hour

	if GameManager.power <= 0:
		_power_out()

func _on_hour_passed():
	GameManager.current_hour += 1
	if GameManager.current_hour >= 6:
		_win()

func _on_left_door_button_pressed():
	left_door_closed  = !left_door_closed          # toggle true/false
	left_door.visible = left_door_closed           # show/hide the sprite
	GameManager.doors_open = left_door_closed or right_door_closed

func _on_right_door_button_pressed():
	right_door_closed  = !right_door_closed
	right_door.visible = right_door_closed
	GameManager.doors_open = left_door_closed or right_door_closed

func _on_camera_button_pressed():
	pass # camera not built yet - will be added in Phase 4

func _power_out():
	game_over = true
	night_timer.stop()
	left_door_closed  = false
	right_door_closed = false
	left_door.visible  = false
	right_door.visible = false

func _win():
	game_over = true
	night_timer.stop()

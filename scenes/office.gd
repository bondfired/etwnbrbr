extends Node2D

@onready var left_door   = $LeftDoor
@onready var right_door  = $RightDoor
@onready var power_label = $PowerLabel
@onready var hour_label  = $HourLabel
@onready var night_timer = $NightTimer

var left_door_closed  = false
var right_door_closed = false
var is_game_over: bool = false

# ── Camera ────────────────────────────────────────────────────────────────────
var camera_open: bool = false
var current_cam: int = 0
const CAM_ROOMS: Array = [
	"Show Stage",
	"Dining Hall",
	"Backstage",
	"West Hall",
	"Left Hall Corner",
	"East Hall",
	"East Hall Corner",
	"Pirate Cove"
]

# ── UI nodes built at runtime ─────────────────────────────────────────────────
var hud_layer: CanvasLayer
var power_warn_label: Label
var cam_overlay: Control
var cam_title_label: Label
var cam_anim_label: Label
var cam_list_label: Label
var gameover_overlay: Control
var caught_label: Label
var win_overlay: Control

# ── Animatronic definitions ───────────────────────────────────────────────────
# path: rooms to traverse; last entry is LEFT_DOOR or RIGHT_DOOR
# base_time: seconds between moves (scales down as night progresses)
# watch_cam: watching this room slows the animatronic (FoxyBlitz: resets timer)
# active_linear_hour: 0=12AM, 1=1AM, 2=2AM …
const ANIMATRONICS: Dictionary = {
	"BonnieJake": {
		"path": ["Show Stage", "Backstage", "West Hall", "Left Hall Corner", "LEFT_DOOR"],
		"base_time": 9.0,
		"watch_cam": "West Hall",
		"active_linear_hour": 0
	},
	"ChicaJasker": {
		"path": ["Show Stage", "Dining Hall", "East Hall", "East Hall Corner", "RIGHT_DOOR"],
		"base_time": 12.0,
		"watch_cam": "East Hall",
		"active_linear_hour": 0
	},
	"FreddyMarcus": {
		"path": ["Show Stage", "Dining Hall", "East Hall", "East Hall Corner", "RIGHT_DOOR"],
		"base_time": 18.0,
		"watch_cam": "",
		"active_linear_hour": 2
	},
	"FoxyBlitz": {
		"path": ["Pirate Cove", "West Hall", "LEFT_DOOR"],
		"base_time": 5.0,
		"watch_cam": "Pirate Cove",
		"active_linear_hour": 1
	}
}

# Runtime state per animatronic
var anim_state: Dictionary = {}

# ── Helpers ───────────────────────────────────────────────────────────────────
func _get_linear_hour() -> int:
	return 0 if GameManager.current_hour == 12 else GameManager.current_hour

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready():
	for name in ANIMATRONICS:
		anim_state[name] = {"index": 0, "timer": 0.0, "active": false}

	night_timer.wait_time = 45.0
	night_timer.start()
	night_timer.timeout.connect(_on_hour_passed)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	_build_power_warning()
	_build_camera_overlay()
	_build_gameover_overlay()
	_build_win_overlay()

func _process(delta: float):
	if is_game_over:
		return

	GameManager.power -= GameManager.get_power_drain() * delta
	GameManager.power = clamp(GameManager.power, 0.0, 100.0)

	power_label.text = "Power: %d%%" % int(GameManager.power)
	hour_label.text  = "%d AM" % GameManager.current_hour
	power_warn_label.visible = GameManager.power < 20.0

	if GameManager.power <= 0.0:
		_power_out()
		return

	_tick_animatronics(delta)

	if camera_open:
		_update_cam_display()

# ── Animatronic AI ────────────────────────────────────────────────────────────
func _tick_animatronics(delta: float):
	var linear_hour = _get_linear_hour()
	for anim_name in ANIMATRONICS:
		var data  = ANIMATRONICS[anim_name]
		var state = anim_state[anim_name]

		if not state["active"]:
			if linear_hour >= data["active_linear_hour"]:
				state["active"] = true
			else:
				continue

		# Speed up as night progresses
		var move_time = max(2.0, data["base_time"] - linear_hour * 0.35)

		# Camera watching effect
		var watch_cam    = data["watch_cam"]
		var watching_now = camera_open and watch_cam != "" and CAM_ROOMS[current_cam] == watch_cam

		if watching_now:
			if anim_name == "FoxyBlitz":
				state["timer"] = 0.0  # keep Foxy at bay while watched
				continue
			else:
				move_time *= 2.0  # other animatronics slow down when watched

		state["timer"] += delta
		if state["timer"] >= move_time:
			state["timer"] = 0.0
			_advance_animatronic(anim_name)

func _advance_animatronic(anim_name: String):
	var state = anim_state[anim_name]
	var path  = ANIMATRONICS[anim_name]["path"]

	if state["index"] >= path.size() - 1:
		_try_enter(anim_name)
		return

	state["index"] += 1
	if state["index"] == path.size() - 1:
		_try_enter(anim_name)

func _try_enter(anim_name: String):
	var path = ANIMATRONICS[anim_name]["path"]
	var door = path[-1]  # "LEFT_DOOR" or "RIGHT_DOOR"

	var blocked = (door == "LEFT_DOOR" and left_door_closed) or \
				  (door == "RIGHT_DOOR" and right_door_closed)

	if blocked:
		# Bounce back one room — the door held
		anim_state[anim_name]["index"] = max(0, anim_state[anim_name]["index"] - 1)
	else:
		_game_over(anim_name)

# ── Button handlers ───────────────────────────────────────────────────────────
func _on_left_door_button_pressed():
	left_door_closed  = !left_door_closed
	left_door.visible = left_door_closed
	GameManager.doors_open = left_door_closed or right_door_closed

func _on_right_door_button_pressed():
	right_door_closed  = !right_door_closed
	right_door.visible = right_door_closed
	GameManager.doors_open = left_door_closed or right_door_closed

func _on_camera_button_pressed():
	camera_open = !camera_open
	GameManager.camera_open = camera_open
	cam_overlay.visible = camera_open
	if camera_open:
		_update_cam_display()

func _on_cam_prev():
	current_cam = (current_cam - 1 + CAM_ROOMS.size()) % CAM_ROOMS.size()
	_update_cam_display()

func _on_cam_next():
	current_cam = (current_cam + 1) % CAM_ROOMS.size()
	_update_cam_display()

# ── Hour / win / loss ─────────────────────────────────────────────────────────
func _on_hour_passed():
	GameManager.current_hour += 1
	if GameManager.current_hour > 12:   # wrap 12 AM → 1 AM → 2 AM …
		GameManager.current_hour = 1
	if GameManager.current_hour >= 6:
		_win()

func _power_out():
	is_game_over = true
	night_timer.stop()
	left_door_closed  = false
	right_door_closed = false
	left_door.visible  = false
	right_door.visible = false
	# Freddy guaranteed attack after lights go out
	await get_tree().create_timer(3.0).timeout
	_game_over("FreddyMarcus")

func _game_over(anim_name: String):
	if gameover_overlay.visible:
		return
	is_game_over = true
	night_timer.stop()
	cam_overlay.visible = false
	camera_open = false
	GameManager.camera_open = false
	gameover_overlay.visible = true
	caught_label.text = "Caught by %s!" % anim_name

func _win():
	is_game_over = true
	night_timer.stop()
	cam_overlay.visible = false
	var idx = GameManager.night_number - 1
	if idx >= 0 and idx < GameManager.nights_completed.size():
		GameManager.nights_completed[idx] = true
	win_overlay.visible = true

func _restart():
	GameManager.power        = 100.0
	GameManager.current_hour = 12
	GameManager.doors_open   = false
	GameManager.camera_open  = false
	get_tree().reload_current_scene()

func _go_to_menu():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _next_night():
	GameManager.night_number  = min(GameManager.night_number + 1, 6)
	GameManager.power         = 100.0
	GameManager.current_hour  = 12
	GameManager.doors_open    = false
	GameManager.camera_open   = false
	get_tree().reload_current_scene()

# ── Camera display ────────────────────────────────────────────────────────────
func _update_cam_display():
	var room = CAM_ROOMS[current_cam]
	cam_title_label.text = "CAM %d  —  %s" % [current_cam + 1, room]

	var found: Array = []
	for anim_name in ANIMATRONICS:
		var state = anim_state[anim_name]
		if not state["active"]:
			continue
		var path = ANIMATRONICS[anim_name]["path"]
		var idx  = state["index"]
		if idx < path.size() and path[idx] == room:
			found.append(anim_name)

	cam_anim_label.text = ">> " + ", ".join(found) + " <<" if found.size() > 0 else "(empty)"

	# Room list with animatronic markers
	var list_text = ""
	for i in range(CAM_ROOMS.size()):
		var r        = CAM_ROOMS[i]
		var selected = ">" if i == current_cam else " "
		var occupied = false
		for anim_name in ANIMATRONICS:
			var state = anim_state[anim_name]
			if not state["active"]:
				continue
			var path = ANIMATRONICS[anim_name]["path"]
			var idx  = state["index"]
			if idx < path.size() and path[idx] == r:
				occupied = true
				break
		list_text += "%s CAM %d - %s%s\n" % [selected, i + 1, r, "  (!)" if occupied else ""]
	cam_list_label.text = list_text

# ── UI builders ───────────────────────────────────────────────────────────────
func _build_power_warning():
	power_warn_label = Label.new()
	power_warn_label.text = "!! LOW POWER !!"
	power_warn_label.set_position(Vector2(420, 578))
	power_warn_label.add_theme_font_size_override("font_size", 24)
	power_warn_label.add_theme_color_override("font_color", Color.RED)
	power_warn_label.visible = false
	hud_layer.add_child(power_warn_label)

func _build_camera_overlay():
	cam_overlay = Control.new()
	cam_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam_overlay.visible = false
	hud_layer.add_child(cam_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	cam_overlay.add_child(bg)

	cam_title_label = Label.new()
	cam_title_label.text = "CAM 1 — Show Stage"
	cam_title_label.set_position(Vector2(260, 70))
	cam_title_label.add_theme_font_size_override("font_size", 36)
	cam_overlay.add_child(cam_title_label)

	cam_anim_label = Label.new()
	cam_anim_label.text = "(empty)"
	cam_anim_label.set_position(Vector2(280, 150))
	cam_anim_label.add_theme_font_size_override("font_size", 28)
	cam_anim_label.add_theme_color_override("font_color", Color.YELLOW)
	cam_overlay.add_child(cam_anim_label)

	cam_list_label = Label.new()
	cam_list_label.set_position(Vector2(30, 70))
	cam_list_label.add_theme_font_size_override("font_size", 15)
	cam_overlay.add_child(cam_list_label)

	var prev_btn = Button.new()
	prev_btn.text = "< PREV"
	prev_btn.set_position(Vector2(160, 520))
	prev_btn.set_size(Vector2(130, 44))
	prev_btn.pressed.connect(_on_cam_prev)
	cam_overlay.add_child(prev_btn)

	var next_btn = Button.new()
	next_btn.text = "NEXT >"
	next_btn.set_position(Vector2(820, 520))
	next_btn.set_size(Vector2(130, 44))
	next_btn.pressed.connect(_on_cam_next)
	cam_overlay.add_child(next_btn)

	var close_btn = Button.new()
	close_btn.text = "[ LOWER CAMERA ]"
	close_btn.set_position(Vector2(430, 555))
	close_btn.set_size(Vector2(210, 44))
	close_btn.pressed.connect(_on_camera_button_pressed)
	cam_overlay.add_child(close_btn)

func _build_gameover_overlay():
	gameover_overlay = Control.new()
	gameover_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameover_overlay.visible = false
	hud_layer.add_child(gameover_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.45, 0.0, 0.0, 0.93)
	gameover_overlay.add_child(bg)

	var title = Label.new()
	title.text = "GAME OVER"
	title.set_position(Vector2(290, 170))
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color.RED)
	gameover_overlay.add_child(title)

	caught_label = Label.new()
	caught_label.set_position(Vector2(340, 290))
	caught_label.add_theme_font_size_override("font_size", 30)
	gameover_overlay.add_child(caught_label)

	var btn = Button.new()
	btn.text = "TRY AGAIN"
	btn.set_position(Vector2(335, 400))
	btn.set_size(Vector2(200, 52))
	btn.pressed.connect(_restart)
	gameover_overlay.add_child(btn)

	var menu_btn = Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.set_position(Vector2(555, 400))
	menu_btn.set_size(Vector2(200, 52))
	menu_btn.pressed.connect(_go_to_menu)
	gameover_overlay.add_child(menu_btn)

func _build_win_overlay():
	win_overlay = Control.new()
	win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.visible = false
	hud_layer.add_child(win_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.22, 0.0, 0.93)
	win_overlay.add_child(bg)

	var title = Label.new()
	title.text = "6 AM"
	title.set_position(Vector2(400, 130))
	title.add_theme_font_size_override("font_size", 90)
	title.add_theme_color_override("font_color", Color.YELLOW)
	win_overlay.add_child(title)

	var sub = Label.new()
	sub.text = "You survived the night!"
	sub.set_position(Vector2(265, 270))
	sub.add_theme_font_size_override("font_size", 38)
	win_overlay.add_child(sub)

	var next_btn = Button.new()
	next_btn.text = "NEXT NIGHT"
	next_btn.set_position(Vector2(290, 395))
	next_btn.set_size(Vector2(190, 52))
	next_btn.pressed.connect(_next_night)
	win_overlay.add_child(next_btn)

	var again_btn = Button.new()
	again_btn.text = "PLAY AGAIN"
	again_btn.set_position(Vector2(500, 395))
	again_btn.set_size(Vector2(190, 52))
	again_btn.pressed.connect(_restart)
	win_overlay.add_child(again_btn)

	var menu_btn = Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.set_position(Vector2(395, 460))
	menu_btn.set_size(Vector2(190, 48))
	menu_btn.pressed.connect(_go_to_menu)
	win_overlay.add_child(menu_btn)

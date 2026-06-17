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
	"Pirate Cove",
	"Music Room",
	"Jaces and Services",
	"Tung's Room"
]

# ── UI nodes built at runtime ─────────────────────────────────────────────────
var hud_layer: CanvasLayer
var power_warn_label: Label
var audio_warn_label: Label
var cam_overlay: Control
var cam_title_label: Label
var cam_anim_label: Label
var cam_list_label: Label
var gameover_overlay: Control
var caught_label: Label
var win_overlay: Control

# ── Animatronic definitions ───────────────────────────────────────────────────
# path: rooms to traverse; last entry is LEFT_DOOR / RIGHT_DOOR / BOTH_DOORS / DOOR
# BOTH_DOORS = requires BOTH doors closed to repel (Doggie)
# DOOR       = door side assigned randomly at runtime (Astro)
const ANIMATRONICS: Dictionary = {
	"Jake": {
		"path": ["Show Stage", "Backstage", "West Hall", "Left Hall Corner", "LEFT_DOOR"],
		"base_time": 16.0, "watch_cam": "West Hall",
		"active_linear_hour": 0, "min_night": 1
	},
	"Jasker": {
		"path": ["Show Stage", "Dining Hall", "East Hall", "East Hall Corner", "RIGHT_DOOR"],
		"base_time": 20.0, "watch_cam": "East Hall",
		"active_linear_hour": 0, "min_night": 1
	},
	"Marcus": {
		"path": ["Show Stage", "Dining Hall", "East Hall", "East Hall Corner", "RIGHT_DOOR"],
		"base_time": 28.0, "watch_cam": "",
		"active_linear_hour": 2, "min_night": 2
	},
	"Blitz": {
		"path": ["Pirate Cove", "West Hall", "LEFT_DOOR"],
		"base_time": 10.0, "watch_cam": "Pirate Cove",
		"active_linear_hour": 1, "min_night": 2
	},
	"Doggie": {
		"path": ["Music Room", "APPROACHING", "BOTH_DOORS"],
		"base_time": 24.0, "watch_cam": "",
		"active_linear_hour": 0, "min_night": 5
	},
	"Astro": {
		"path": ["SHADOW", "SHADOW_NEAR", "DOOR"],
		"base_time": 30.0, "watch_cam": "",
		"active_linear_hour": 1, "min_night": 3
	},
	"BFB": {
		"path": ["Dining Hall", "East Hall", "East Hall Corner", "RIGHT_DOOR"],
		"base_time": 22.0, "watch_cam": "",
		"active_linear_hour": 0, "min_night": 5
	},
	"Owen": {
		"path": ["Show Stage", "Backstage", "West Hall", "Left Hall Corner", "LEFT_DOOR"],
		"base_time": 22.0, "watch_cam": "",
		"active_linear_hour": 0, "min_night": 4
	},
	"Tung": {
		"path": ["Tung's Room", "East Hall", "East Hall Corner", "RIGHT_DOOR"],
		"base_time": 14.0, "watch_cam": "",
		"active_linear_hour": 0, "min_night": 4
	},
	"Jace": {
		"path": ["Jaces and Services", "Backstage", "West Hall", "Left Hall Corner", "DOOR"],
		"base_time": 18.0, "watch_cam": "",
		"active_linear_hour": 1, "min_night": 5
	}
}

# ── Dragon Ball system (Goku) ──────────────────────────────────────────────────
const DB_ROOMS: Array = [
	"Show Stage", "Dining Hall", "Backstage",
	"West Hall", "Left Hall Corner", "East Hall", "East Hall Corner"
]
var db_collected: Dictionary = {}
var db_found: int = 0
var db_given: bool = false

var db_hud_label: Label
var cam_db_label: Label
var cam_db_counter: Label
var db_collect_btn: Button
var db_give_btn: Button

# ── Owen state ────────────────────────────────────────────────────────────────
var owen_at_door: bool               = false
var owen_trapped: bool               = false
var owen_door_preemptively_closed: bool = false
var owen_flash_btn: Button
var owen_door_label: Label

# ── Tung / dodge state ────────────────────────────────────────────────────────
const TUNG_ATTACK_WINDOW: float = 2.5
var tung_attacking: bool   = false
var tung_attack_timer: float = 0.0
var tung_attack_label: Label
var head_lowered: bool     = false
var head_lower_btn: Button
var head_status_label: Label

# ── Kolzaru (Golden Freddy style) ─────────────────────────────────────────────
const KOLZARU_APPEAR_WINDOW: float = 3.0
var kolzaru_triggered: bool      = false
var kolzaru_appear_elapsed: float = 0.0
var kolzaru_timer: float          = 0.0
var kolzaru_next_appear: float    = 0.0
var kolzaru_label: Label

# ── Jace state ────────────────────────────────────────────────────────────────
const JACE_DOOR_WINDOW: float = 5.0
var jace_at_door: bool       = false
var jace_door_timer: float   = 0.0
var jace_door_label: Label

# ── Night intro ───────────────────────────────────────────────────────────────
const NIGHT_INTRO_DURATION: float = 3.5
var night_intro_active: bool = true
var night_intro_timer: float = 0.0
var night_intro_overlay: ColorRect
var night_intro_label: Label

# ── Power bar ─────────────────────────────────────────────────────────────────
var power_bar_bg: ColorRect
var power_bar_fill: ColorRect

# ── Per-night drain rates ──────────────────────────────────────────────────────
const NIGHT_DRAIN: Array = [0.12, 0.18, 0.24, 0.30, 0.36, 0.44]

# ── Sleep mechanic ─────────────────────────────────────────────────────────────
const SLEEP_IDLE_THRESHOLD: float   = 15.0
const SLEEP_DROWSY_WINDOW: float    = 5.0
const SLEEP_CLICKS_NEEDED: int      = 8
const SLEEP_BLACKOUT_DURATION: float = 15.0
enum SleepState { AWAKE, DROWSY, ASLEEP }
var sleep_state: SleepState         = SleepState.AWAKE
var sleep_idle_timer: float         = 0.0
var sleep_drowsy_timer: float       = 0.0
var sleep_blackout_timer: float     = 0.0
var sleep_clicks: int               = 0
var sleep_top: ColorRect
var sleep_bot: ColorRect
var sleep_label: Label

# ── Audio ─────────────────────────────────────────────────────────────────────
var sfx_ambient: AudioStreamPlayer
var sfx_door: AudioStreamPlayer
var sfx_camera_up: AudioStreamPlayer
var sfx_camera_down: AudioStreamPlayer
var sfx_flash: AudioStreamPlayer
var sfx_jumpscare: AudioStreamPlayer
var sfx_kolzaru: AudioStreamPlayer
var sfx_phone_ring: AudioStreamPlayer
var sfx_power_down: AudioStreamPlayer
var sfx_power_warning: AudioStreamPlayer
var sfx_six_am: AudioStreamPlayer
var sfx_sleep_snore: AudioStreamPlayer
var sfx_tung_swing: AudioStreamPlayer
var sfx_wake_up: AudioStreamPlayer
var _power_warn_playing: bool = false

# ── Office flashlight ─────────────────────────────────────────────────────────
var flashlight_btn_left: Button
var flashlight_btn_right: Button
var flashlight_reveal_label: Label
var flashlight_overlay: ColorRect
var sfx_appear: AudioStreamPlayer
const FLASHLIGHT_DURATION: float = 1.5
var flashlight_timer: float = 0.0
var flashlight_active: bool = false
const FLASHLIGHT_IMMUNE: Array = ["Jace", "Blitz", "Doggie", "Kolzaru", "Tung"]

# ── Office panning (FNAF 1 style) ────────────────────────────────────────────
const PAN_MAX: float = 250.0
const PAN_DEAD_ZONE: float = 0.3
const PAN_LERP_SPEED: float = 2.5
var office_cam: Camera2D
var pan_current: float = 0.0

func _is_goku_active() -> bool:
	if GameManager.is_custom_night:
		return GameManager.custom_ai.get("Goku", 0) > 0
	return GameManager.night_number >= 3

func _is_kolzaru_active() -> bool:
	if GameManager.is_custom_night:
		return GameManager.custom_ai.get("Kolzaru", 0) > 0
	return GameManager.night_number >= 2 and _get_linear_hour() >= 2

# Runtime state per animatronic
var anim_state: Dictionary = {}

# ── Helpers ───────────────────────────────────────────────────────────────────
func _get_linear_hour() -> int:
	return 0 if GameManager.current_hour == 12 else GameManager.current_hour

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready():
	for anim_name in ANIMATRONICS:
		anim_state[anim_name] = {"index": 0, "timer": 0.0, "active": false}
	for room in DB_ROOMS:
		db_collected[room] = false

	kolzaru_next_appear = randf_range(90.0, 180.0)

	# Scale power drain and Kolzaru rarity to night number
	var night_idx = clamp(GameManager.night_number - 1, 0, 5)
	GameManager.power_drain_base = NIGHT_DRAIN[night_idx]

	# Night timer starts after the intro finishes
	night_timer.wait_time = 45.0
	night_timer.timeout.connect(_on_hour_passed)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	_setup_office_pan()

	_build_power_warning()
	_build_audio_warning()
	_build_power_bar()
	_build_goku_ui()
	_build_owen_ui()
	_build_tung_ui()
	_build_kolzaru_jace_ui()
	_build_camera_overlay()
	_build_gameover_overlay()
	_build_win_overlay()
	_build_sleep_ui()
	_build_flashlight_ui()
	_build_audio()
	_build_night_intro()  # must be absolute last — covers everything

func _process(delta: float):
	if is_game_over:
		return

	# Show night intro, then start the game
	if night_intro_active:
		night_intro_timer += delta
		var fade = clamp((NIGHT_INTRO_DURATION - night_intro_timer) / 0.6, 0.0, 1.0)
		night_intro_overlay.color.a = fade
		if night_intro_timer >= NIGHT_INTRO_DURATION:
			night_intro_active = false
			night_intro_overlay.visible = false
			night_timer.start()
			sfx_phone_ring.play()
			sfx_ambient.play()
		return

	_update_office_pan(delta)

	GameManager.power -= GameManager.get_power_drain() * delta
	GameManager.power = clamp(GameManager.power, 0.0, 100.0)

	var pct = GameManager.power / 100.0
	power_label.text = "Power: %d%%" % int(GameManager.power)
	hour_label.text  = "Night %d  —  %d AM" % [GameManager.night_number, GameManager.current_hour]
	power_warn_label.visible = GameManager.power < 20.0
	if GameManager.power < 20.0 and not _power_warn_playing:
		_power_warn_playing = true
		sfx_power_warning.play()

	# Update power bar colour: green → yellow → red
	power_bar_fill.size.x = 180.0 * pct
	if pct > 0.5:
		power_bar_fill.color = Color(0.1, 0.75, 0.1)
	elif pct > 0.25:
		power_bar_fill.color = Color(0.9, 0.65, 0.0)
	else:
		power_bar_fill.color = Color(0.85, 0.1, 0.1)

	if GameManager.power <= 0.0:
		_power_out()
		return

	_tick_animatronics(delta)
	_update_astro_warning()
	_process_tung_attack(delta)
	_process_kolzaru(delta)
	_process_jace(delta)
	_process_sleep(delta)
	_process_flashlight(delta)

	if _is_goku_active():
		db_hud_label.text   = "Dragon Balls: %d / 7" % db_found
		db_hud_label.visible = not db_given
		db_give_btn.visible  = db_found >= 7 and not db_given and not camera_open
	else:
		db_hud_label.visible = false
		db_give_btn.visible  = false

	owen_door_label.visible = owen_at_door

	if camera_open:
		_update_cam_display()

# ── Animatronic AI ────────────────────────────────────────────────────────────
func _tick_animatronics(delta: float):
	var linear_hour = _get_linear_hour()
	for anim_name in ANIMATRONICS:
		var data  = ANIMATRONICS[anim_name]
		var state = anim_state[anim_name]

		if not state["active"]:
			var should_activate = false
			if GameManager.is_custom_night:
				should_activate = GameManager.custom_ai.get(anim_name, 0) > 0
			else:
				# Gate by both hour AND minimum night
				var min_n = data.get("min_night", 1)
				if GameManager.night_number < min_n:
					continue
				should_activate = linear_hour >= data["active_linear_hour"]

			if should_activate:
				state["active"] = true
				if anim_name == "Astro" or anim_name == "Jace":
					state["target_door"] = "LEFT_DOOR" if randi() % 2 == 0 else "RIGHT_DOOR"
			else:
				continue

		# Move time: custom night uses AI level; standard scales with hour AND night
		var move_time: float
		if GameManager.is_custom_night:
			var ai_lvl = GameManager.custom_ai.get(anim_name, 0)
			if ai_lvl == 0:
				continue
			move_time = lerpf(45.0, 1.5, float(ai_lvl - 1) / 19.0)
		else:
			var night_scale = 1.0 - float(GameManager.night_number - 1) * 0.07
			move_time = max(3.0, data["base_time"] * night_scale - linear_hour * 0.2)

		# Camera watching effect
		var watch_cam    = data["watch_cam"]
		var watching_now = camera_open and watch_cam != "" and CAM_ROOMS[current_cam] == watch_cam

		if watching_now:
			if anim_name == "Blitz":
				state["timer"] = 0.0  # keep Blitz at bay while watched
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
	var door = path[-1]

	# Doggie: only retreats when BOTH doors are closed; slips through any open one
	# If Owen is already at the left door, Doggie backs off — can't attack simultaneously
	if door == "BOTH_DOORS":
		if owen_at_door:
			anim_state[anim_name]["index"] = 0
			anim_state[anim_name]["timer"] = 0.0
			return
		if left_door_closed and right_door_closed:
			anim_state[anim_name]["index"] = 0
			anim_state[anim_name]["timer"] = 0.0
		else:
			_game_over(anim_name)
		return

	# Astro: door side was randomly assigned at activation
	if door == "DOOR":
		door = anim_state[anim_name].get("target_door", "LEFT_DOOR")

	# Owen: doors don't repel him; only closing AFTER he arrives traps him
	if anim_name == "Owen":
		if owen_at_door:
			return  # already processed, waiting to be flashed or door opened
		# If Doggie is currently threatening, Owen holds back
		var doggie_idx = anim_state.get("Doggie", {}).get("index", 0)
		if doggie_idx >= ANIMATRONICS["Doggie"]["path"].size() - 1:
			anim_state["Owen"]["index"] = 0
			return
		owen_at_door = true
		if left_door_closed:
			# Door was already closed before Owen arrived — not trapped, just waiting
			owen_door_preemptively_closed = true
		# Door open: Owen waits, player must flash him from Left Hall Corner
		return

	# Tung: dodge-based mechanic — doors don't repel him, player must lower head
	if anim_name == "Tung":
		if tung_attacking:
			return  # attack already in progress
		tung_attacking = true
		tung_attack_timer = 0.0
		tung_attack_label.text = "!! TUNG IS SWINGING !!"
		tung_attack_label.visible = true
		sfx_tung_swing.play()
		return

	# Jace: needs BOTH doors open to walk through; gives a timed window to react
	if anim_name == "Jace":
		if jace_at_door:
			return  # already waiting
		jace_at_door = true
		jace_door_timer = 0.0
		jace_door_label.text = "!! JACE IS AT THE DOOR — OPEN BOTH DOORS !!"
		jace_door_label.visible = true
		return

	var blocked = (door == "LEFT_DOOR" and left_door_closed) or \
				  (door == "RIGHT_DOOR" and right_door_closed)

	if blocked:
		anim_state[anim_name]["index"] = 0
		anim_state[anim_name]["timer"] = 0.0
	else:
		_game_over(anim_name)

# ── Button handlers ───────────────────────────────────────────────────────────
func _on_left_door_button_pressed():
	if owen_at_door:
		if left_door_closed:
			# Door is closed and player is opening it while Owen is outside — he enters
			_game_over("Owen")
			return
		else:
			# Door is open and player is closing it AFTER Owen arrived — traps him
			owen_trapped = true
	left_door_closed  = !left_door_closed
	left_door.visible = left_door_closed
	GameManager.doors_open = left_door_closed or right_door_closed
	sfx_door.play()

func _on_right_door_button_pressed():
	right_door_closed  = !right_door_closed
	right_door.visible = right_door_closed
	GameManager.doors_open = left_door_closed or right_door_closed
	sfx_door.play()

func _on_camera_button_pressed():
	camera_open = !camera_open
	GameManager.camera_open = camera_open
	cam_overlay.visible = camera_open
	flashlight_btn_left.visible = not camera_open
	flashlight_btn_right.visible = not camera_open
	if camera_open:
		sfx_camera_up.play()
		_update_cam_display()
		if kolzaru_triggered:
			# Raising the monitor dismisses Kolzaru
			kolzaru_triggered = false
			kolzaru_label.visible = false
			kolzaru_timer = 0.0
			kolzaru_next_appear = randf_range(40.0, 90.0)
			sfx_kolzaru.stop()
	else:
		sfx_camera_down.play()

func _on_cam_prev():
	current_cam = (current_cam - 1 + CAM_ROOMS.size()) % CAM_ROOMS.size()
	_update_cam_display()

func _on_cam_next():
	current_cam = (current_cam + 1) % CAM_ROOMS.size()
	_update_cam_display()

func _input(event: InputEvent):
	if is_game_over:
		return
	# During full blackout, block all input until player wakes naturally
	if sleep_state == SleepState.ASLEEP:
		get_viewport().set_input_as_handled()
		return
	# Mouse clicks reset idle timer and count toward waking up
	if event is InputEventMouseButton and event.pressed:
		sleep_idle_timer = 0.0
		if sleep_state == SleepState.DROWSY:
			sleep_clicks += 1
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_toggle_head_lower()
	if not camera_open:
		return
	if event.is_action_pressed("ui_left") or event is InputEventKey and event.pressed and event.keycode == KEY_A:
		_on_cam_prev()
	elif event.is_action_pressed("ui_right") or event is InputEventKey and event.pressed and event.keycode == KEY_D:
		_on_cam_next()

# ── Hour / win / loss ─────────────────────────────────────────────────────────
func _on_hour_passed():
	GameManager.current_hour += 1
	if GameManager.current_hour > 12:
		GameManager.current_hour = 1
	if GameManager.current_hour == 5 and _is_goku_active() and not db_given:
		_game_over("Goku")
		return
	if GameManager.current_hour >= 6:
		_win()

func _power_out():
	is_game_over = true
	sfx_ambient.stop()
	sfx_power_down.play()
	night_timer.stop()
	left_door_closed  = false
	right_door_closed = false
	left_door.visible  = false
	right_door.visible = false
	# Freddy guaranteed attack after lights go out
	await get_tree().create_timer(3.0).timeout
	_game_over("Marcus")

func _game_over(anim_name: String):
	if gameover_overlay.visible:
		return
	is_game_over = true
	sfx_ambient.stop()
	sfx_jumpscare.play()
	_wake_up()
	night_timer.stop()
	cam_overlay.visible = false
	camera_open = false
	GameManager.camera_open = false
	gameover_overlay.visible = true
	caught_label.text = "Caught by %s!" % anim_name

func _win():
	is_game_over = true
	sfx_ambient.stop()
	sfx_six_am.play()
	_wake_up()
	night_timer.stop()
	cam_overlay.visible = false
	if not GameManager.is_custom_night:
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
	if GameManager.is_custom_night:
		_go_to_menu()
		return
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

	# Dragon ball detection
	var has_uncollected_db = _is_goku_active() and (room in DB_ROOMS) and not db_collected.get(room, true)
	cam_db_label.visible   = has_uncollected_db
	db_collect_btn.visible = has_uncollected_db
	cam_db_counter.visible = _is_goku_active()
	cam_db_counter.text    = "★ Dragon Balls: %d / 7" % db_found

	# Owen flash button — visible when Owen is in this camera room, or at the door and
	# player is viewing Left Hall Corner (the hallway just outside the left door)
	var owen_st   = anim_state.get("Owen", {})
	var owen_idx  = owen_st.get("index", 0)
	var owen_path = ANIMATRONICS["Owen"]["path"]
	var owen_in_room = owen_st.get("active", false) and not owen_at_door \
		and owen_idx < owen_path.size() and owen_path[owen_idx] == room
	var owen_at_door_cam = owen_at_door and room == "Left Hall Corner"
	owen_flash_btn.visible = owen_in_room or owen_at_door_cam

	# Collect visible animatronics (Astro is never shown on any camera)
	var found: Array = []
	for anim_name in ANIMATRONICS:
		if anim_name == "Astro":
			continue
		var state = anim_state[anim_name]
		if not state["active"]:
			continue
		var path = ANIMATRONICS[anim_name]["path"]
		var idx  = state["index"]
		if idx < path.size() and path[idx] == room:
			var label = "Doggie (at desk)" if anim_name == "Doggie" else anim_name
			found.append(label)

	# Special Music Room display: warn loudly when Doggie has left
	var doggie_st    = anim_state.get("Doggie", {})
	var doggie_gone  = doggie_st.get("active", false) and doggie_st.get("index", 0) > 0
	if room == "Music Room" and doggie_gone:
		cam_anim_label.text = "!!! DOGGIE HAS LEFT HIS DESK !!!"
		cam_anim_label.add_theme_color_override("font_color", Color.RED)
	elif found.size() > 0:
		cam_anim_label.text = "[ ALERT: %s ]" % ", ".join(found)
		cam_anim_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	else:
		cam_anim_label.text = "[ NO ACTIVITY ]"
		cam_anim_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))

	# Room list
	var list_text = ""
	for i in range(CAM_ROOMS.size()):
		var r        = CAM_ROOMS[i]
		var selected = ">" if i == current_cam else " "
		var occupied = false
		for anim_name in ANIMATRONICS:
			if anim_name == "Astro":
				continue
			var state = anim_state[anim_name]
			if not state["active"]:
				continue
			var path = ANIMATRONICS[anim_name]["path"]
			var idx  = state["index"]
			if idx < path.size() and path[idx] == r:
				occupied = true
				break
		var marker = ""
		if r == "Music Room" and doggie_gone:
			marker = "  (!! GONE)"
		elif occupied:
			marker = "  (!)"
		list_text += "%s CAM %d - %s%s\n" % [selected, i + 1, r, marker]
	cam_list_label.text = list_text

# ── UI builders ───────────────────────────────────────────────────────────────
func _build_goku_ui():
	db_hud_label = Label.new()
	db_hud_label.set_position(Vector2(10, 32))
	db_hud_label.add_theme_font_size_override("font_size", 16)
	db_hud_label.add_theme_color_override("font_color", Color.ORANGE)
	db_hud_label.visible = false
	hud_layer.add_child(db_hud_label)

	db_give_btn = Button.new()
	db_give_btn.text = "GIVE DRAGON BALLS TO GOKU"
	db_give_btn.set_position(Vector2(380, 565))
	db_give_btn.set_size(Vector2(360, 48))
	db_give_btn.add_theme_font_size_override("font_size", 17)
	db_give_btn.visible = false
	db_give_btn.pressed.connect(_give_dragon_balls)
	hud_layer.add_child(db_give_btn)

func _build_owen_ui():
	owen_door_label = Label.new()
	owen_door_label.text = "!! OWEN IS AT THE LEFT DOOR — DO NOT OPEN IT !!"
	owen_door_label.set_position(Vector2(200, 58))
	owen_door_label.add_theme_font_size_override("font_size", 18)
	owen_door_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0))
	owen_door_label.visible = false
	hud_layer.add_child(owen_door_label)

func _build_tung_ui():
	tung_attack_label = Label.new()
	tung_attack_label.set_position(Vector2(226, 8))
	tung_attack_label.set_size(Vector2(700, 32))
	tung_attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tung_attack_label.add_theme_font_size_override("font_size", 22)
	tung_attack_label.add_theme_color_override("font_color", Color.RED)
	tung_attack_label.visible = false
	hud_layer.add_child(tung_attack_label)

	head_status_label = Label.new()
	head_status_label.text = "[ HEAD DOWN ]"
	head_status_label.set_position(Vector2(10, 96))
	head_status_label.add_theme_font_size_override("font_size", 14)
	head_status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	head_status_label.visible = false
	hud_layer.add_child(head_status_label)

	head_lower_btn = Button.new()
	head_lower_btn.text = "LOWER HEAD  [SPACE]"
	head_lower_btn.set_position(Vector2(820, 576))
	head_lower_btn.set_size(Vector2(240, 46))
	head_lower_btn.add_theme_font_size_override("font_size", 16)
	head_lower_btn.pressed.connect(_toggle_head_lower)
	hud_layer.add_child(head_lower_btn)

func _toggle_head_lower():
	head_lowered = !head_lowered
	head_lower_btn.text = "RAISE HEAD  [SPACE]" if head_lowered else "LOWER HEAD  [SPACE]"
	head_status_label.visible = head_lowered

func _process_tung_attack(delta: float):
	if not tung_attacking:
		return
	tung_attack_timer += delta
	var t = TUNG_ATTACK_WINDOW - tung_attack_timer
	tung_attack_label.text = "!! TUNG IS SWINGING — LOWER YOUR HEAD!! (%.1f)" % max(0.0, t)
	if tung_attack_timer >= TUNG_ATTACK_WINDOW:
		tung_attacking = false
		tung_attack_label.visible = false
		if head_lowered:
			anim_state["Tung"]["index"] = 0
			anim_state["Tung"]["timer"] = 0.0
		else:
			_game_over("Tung")

func _collect_dragon_ball():
	var room = CAM_ROOMS[current_cam]
	if room in DB_ROOMS and not db_collected.get(room, false):
		db_collected[room] = true
		db_found += 1
		_update_cam_display()

func _give_dragon_balls():
	db_given = true
	db_give_btn.visible = false

func _flash_owen():
	var state = anim_state.get("Owen", {})
	if not state.get("active", false):
		return
	sfx_flash.play()
	# Send Owen back to the Show Stage
	state["index"] = 0
	state["timer"] = 0.0
	owen_at_door   = false
	owen_trapped   = false
	owen_door_preemptively_closed = false
	_update_cam_display()

func _build_kolzaru_jace_ui():
	kolzaru_label = Label.new()
	kolzaru_label.set_position(Vector2(176, 240))
	kolzaru_label.set_size(Vector2(800, 64))
	kolzaru_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolzaru_label.add_theme_font_size_override("font_size", 26)
	kolzaru_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	kolzaru_label.visible = false
	hud_layer.add_child(kolzaru_label)

	jace_door_label = Label.new()
	jace_door_label.set_position(Vector2(176, 280))
	jace_door_label.set_size(Vector2(800, 32))
	jace_door_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jace_door_label.add_theme_font_size_override("font_size", 20)
	jace_door_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	jace_door_label.visible = false
	hud_layer.add_child(jace_door_label)

func _process_kolzaru(delta: float):
	if not _is_kolzaru_active():
		kolzaru_label.visible = false
		return
	if kolzaru_triggered:
		kolzaru_appear_elapsed += delta
		var t = KOLZARU_APPEAR_WINDOW - kolzaru_appear_elapsed
		kolzaru_label.text = "!! KOLZARU IS IN YOUR OFFICE — RAISE YOUR MONITOR!! (%.1f)" % max(0.0, t)
		if kolzaru_appear_elapsed >= KOLZARU_APPEAR_WINDOW:
			kolzaru_triggered = false
			kolzaru_label.visible = false
			_game_over("Kolzaru")
	else:
		kolzaru_timer += delta
		if kolzaru_timer >= kolzaru_next_appear:
			kolzaru_timer = 0.0
			if GameManager.is_custom_night:
				var ai = GameManager.custom_ai.get("Kolzaru", 0)
				kolzaru_next_appear = lerpf(120.0, 15.0, float(ai - 1) / 19.0)
			else:
				kolzaru_next_appear = randf_range(40.0, 90.0)
			kolzaru_triggered = true
			kolzaru_appear_elapsed = 0.0
			kolzaru_label.text = "!! KOLZARU IS IN YOUR OFFICE !!"
			kolzaru_label.visible = true
			sfx_kolzaru.play()

func _process_jace(delta: float):
	if not jace_at_door:
		return
	if not left_door_closed and not right_door_closed:
		# Both doors open — Jace walks through safely
		jace_at_door = false
		jace_door_label.visible = false
		anim_state["Jace"]["index"] = 0
		anim_state["Jace"]["timer"] = 0.0
		return
	jace_door_timer += delta
	var t = JACE_DOOR_WINDOW - jace_door_timer
	jace_door_label.text = "!! JACE IS AT THE DOOR — OPEN BOTH DOORS!! (%.1f)" % max(0.0, t)
	if jace_door_timer >= JACE_DOOR_WINDOW:
		jace_at_door = false
		jace_door_label.visible = false
		_game_over("Jace")

func _build_night_intro():
	night_intro_overlay = ColorRect.new()
	night_intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	night_intro_overlay.color = Color(0, 0, 0, 1)
	night_intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(night_intro_overlay)

	var night_lbl = Label.new()
	var is_custom = GameManager.is_custom_night
	night_lbl.text = "Custom Night" if is_custom else "Night %d" % GameManager.night_number
	night_lbl.set_position(Vector2(0, 224))
	night_lbl.set_size(Vector2(1152, 90))
	night_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	night_lbl.add_theme_font_size_override("font_size", 72)
	night_lbl.add_theme_color_override("font_color", Color(0.96, 0.78, 0.08))
	night_intro_overlay.add_child(night_lbl)

	night_intro_label = Label.new()
	night_intro_label.text = "Stack Validated's Emporium"
	night_intro_label.set_position(Vector2(0, 330))
	night_intro_label.set_size(Vector2(1152, 30))
	night_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	night_intro_label.add_theme_font_size_override("font_size", 20)
	night_intro_label.add_theme_color_override("font_color", Color(0.5, 0.35, 0.10))
	night_intro_overlay.add_child(night_intro_label)

func _build_power_bar():
	var bar_x = 10.0
	var bar_y = 556.0
	power_bar_bg = ColorRect.new()
	power_bar_bg.set_position(Vector2(bar_x, bar_y))
	power_bar_bg.set_size(Vector2(180, 10))
	power_bar_bg.color = Color(0.12, 0.10, 0.06)
	hud_layer.add_child(power_bar_bg)

	power_bar_fill = ColorRect.new()
	power_bar_fill.set_position(Vector2(bar_x, bar_y))
	power_bar_fill.set_size(Vector2(180, 10))
	power_bar_fill.color = Color(0.1, 0.75, 0.1)
	hud_layer.add_child(power_bar_fill)

func _build_sleep_ui():
	sleep_top = ColorRect.new()
	sleep_top.set_position(Vector2(0, 0))
	sleep_top.set_size(Vector2(1152, 0))
	sleep_top.color = Color(0.04, 0.01, 0.01)
	sleep_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(sleep_top)

	sleep_bot = ColorRect.new()
	sleep_bot.set_position(Vector2(0, 648))
	sleep_bot.set_size(Vector2(1152, 0))
	sleep_bot.color = Color(0.04, 0.01, 0.01)
	sleep_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(sleep_bot)

	sleep_label = Label.new()
	sleep_label.set_position(Vector2(176, 304))
	sleep_label.set_size(Vector2(800, 40))
	sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_label.add_theme_font_size_override("font_size", 26)
	sleep_label.add_theme_color_override("font_color", Color.WHITE)
	sleep_label.visible = false
	sleep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(sleep_label)

func _process_sleep(delta: float):
	match sleep_state:
		SleepState.AWAKE:
			sleep_idle_timer += delta
			if sleep_idle_timer >= SLEEP_IDLE_THRESHOLD:
				_enter_drowsy()
		SleepState.DROWSY:
			sleep_drowsy_timer += delta
			var progress = min(sleep_drowsy_timer / SLEEP_DROWSY_WINDOW, 1.0)
			var lid_h = (324 + 10) * progress  # H/2 + overlap
			sleep_top.size.y = lid_h
			sleep_bot.size.y = lid_h
			sleep_bot.position.y = 648 - lid_h
			var left = SLEEP_CLICKS_NEEDED - sleep_clicks
			sleep_label.text = "YOU'RE FALLING ASLEEP — CLICK RAPIDLY!! (%d more)" % left
			if sleep_clicks >= SLEEP_CLICKS_NEEDED:
				_wake_up()
			elif sleep_drowsy_timer >= SLEEP_DROWSY_WINDOW:
				_fall_asleep()
		SleepState.ASLEEP:
			sleep_blackout_timer += delta
			var t = SLEEP_BLACKOUT_DURATION - sleep_blackout_timer
			sleep_label.text = "Zzz...  (%.0f)" % max(0.0, t)
			if sleep_blackout_timer >= SLEEP_BLACKOUT_DURATION:
				_wake_up()

func _enter_drowsy():
	sleep_state = SleepState.DROWSY
	sleep_drowsy_timer = 0.0
	sleep_clicks = 0
	sleep_label.text = "YOU'RE FALLING ASLEEP — CLICK RAPIDLY!!"
	sleep_label.visible = true

func _fall_asleep():
	sleep_state = SleepState.ASLEEP
	sleep_blackout_timer = 0.0
	sfx_sleep_snore.play()
	var lid_h = 334.0
	sleep_top.size.y = lid_h
	sleep_bot.size.y = lid_h
	sleep_bot.position.y = 648 - lid_h
	sleep_label.text = "Zzz..."
	sleep_label.visible = true

func _wake_up():
	sleep_state = SleepState.AWAKE
	sleep_idle_timer = 0.0
	sleep_drowsy_timer = 0.0
	sleep_clicks = 0
	if sfx_sleep_snore != null:
		sfx_sleep_snore.stop()
	if sfx_wake_up != null:
		sfx_wake_up.play()
	if sleep_top != null:
		sleep_top.size.y = 0
	if sleep_bot != null:
		sleep_bot.size.y = 0
		sleep_bot.position.y = 648
	if sleep_label != null:
		sleep_label.visible = false

# ── Office panning ────────────────────────────────────────────────────────────
func _setup_office_pan():
	office_cam = Camera2D.new()
	office_cam.position = Vector2(576, 324)
	office_cam.enabled = true
	add_child(office_cam)

	# Stretch background to cover the full panning range
	var bg = $Background
	var tex_w = bg.texture.get_width() * bg.scale.x
	var needed_w = 1152.0 + PAN_MAX * 2.0
	bg.scale.x *= needed_w / tex_w
	bg.position.x = 576.0

	left_door.position.x -= PAN_MAX
	right_door.position.x += PAN_MAX
	$LeftDoorButton.position.x -= PAN_MAX
	$RightDoorButton.position.x += PAN_MAX

	$PowerLabel.visible = false
	$HourLabel.visible = false
	$CameraButton.visible = false

	var hud_power = Label.new()
	hud_power.set_position(Vector2(981, 631))
	hud_power.text = "Power: 100"
	hud_layer.add_child(hud_power)
	power_label = hud_power

	var hud_hour = Label.new()
	hud_hour.set_position(Vector2(0, 6))
	hud_hour.text = "12 AM"
	hud_layer.add_child(hud_hour)
	hour_label = hud_hour

	var hud_cam_btn = Button.new()
	hud_cam_btn.text = "CAM"
	hud_cam_btn.set_position(Vector2(539, 589))
	hud_cam_btn.set_size(Vector2(44, 31))
	hud_cam_btn.pressed.connect(_on_camera_button_pressed)
	hud_layer.add_child(hud_cam_btn)

func _update_office_pan(delta: float):
	if camera_open:
		return
	var mouse_x = get_viewport().get_mouse_position().x
	var vp_w = get_viewport().get_visible_rect().size.x
	if vp_w == 0:
		return
	var normalized = (mouse_x / vp_w) * 2.0 - 1.0
	var pan_target = 0.0
	if abs(normalized) > PAN_DEAD_ZONE:
		var sign_v = sign(normalized)
		pan_target = sign_v * (abs(normalized) - PAN_DEAD_ZONE) / (1.0 - PAN_DEAD_ZONE)
	pan_current = lerp(pan_current, pan_target, delta * PAN_LERP_SPEED)
	office_cam.position.x = 576.0 + pan_current * PAN_MAX

# ── Office flashlight ─────────────────────────────────────────────────────────
func _build_flashlight_ui():
	sfx_appear = AudioStreamPlayer.new()
	sfx_appear.stream = load("res://sounds/appear.ogg")
	add_child(sfx_appear)

	flashlight_btn_left = Button.new()
	flashlight_btn_left.text = "FLASH LEFT DOOR"
	flashlight_btn_left.set_position(Vector2(10, 576))
	flashlight_btn_left.set_size(Vector2(180, 40))
	flashlight_btn_left.add_theme_font_size_override("font_size", 14)
	flashlight_btn_left.pressed.connect(_flash_door.bind("LEFT_DOOR"))
	hud_layer.add_child(flashlight_btn_left)

	flashlight_btn_right = Button.new()
	flashlight_btn_right.text = "FLASH RIGHT DOOR"
	flashlight_btn_right.set_position(Vector2(962, 576))
	flashlight_btn_right.set_size(Vector2(180, 40))
	flashlight_btn_right.add_theme_font_size_override("font_size", 14)
	flashlight_btn_right.pressed.connect(_flash_door.bind("RIGHT_DOOR"))
	hud_layer.add_child(flashlight_btn_right)

	flashlight_overlay = ColorRect.new()
	flashlight_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flashlight_overlay.color = Color(1, 1, 1, 0.08)
	flashlight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flashlight_overlay.visible = false
	hud_layer.add_child(flashlight_overlay)

	flashlight_reveal_label = Label.new()
	flashlight_reveal_label.set_position(Vector2(176, 340))
	flashlight_reveal_label.set_size(Vector2(800, 40))
	flashlight_reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flashlight_reveal_label.add_theme_font_size_override("font_size", 28)
	flashlight_reveal_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	flashlight_reveal_label.visible = false
	hud_layer.add_child(flashlight_reveal_label)

func _flash_door(door_side: String):
	if camera_open or flashlight_active:
		return
	flashlight_active = true
	flashlight_timer = 0.0
	flashlight_overlay.visible = true
	sfx_flash.play()

	var found: Array = []
	for anim_name in ANIMATRONICS:
		if anim_name in FLASHLIGHT_IMMUNE:
			continue
		var state = anim_state[anim_name]
		if not state.get("active", false):
			continue
		var path = ANIMATRONICS[anim_name]["path"]
		var door = path[-1]
		if door == "DOOR":
			door = state.get("target_door", "LEFT_DOOR")
		if door != door_side:
			continue
		if state["index"] >= path.size() - 1:
			found.append(anim_name)

	if owen_at_door and door_side == "LEFT_DOOR" and "Owen" not in FLASHLIGHT_IMMUNE:
		if "Owen" not in found:
			found.append("Owen")

	if found.size() > 0:
		flashlight_reveal_label.text = "!! %s !!" % " & ".join(found)
		flashlight_reveal_label.visible = true
		sfx_appear.play()
	else:
		flashlight_reveal_label.text = "[ Clear ]"
		flashlight_reveal_label.visible = true

func _process_flashlight(delta: float):
	if not flashlight_active:
		return
	flashlight_timer += delta
	if flashlight_timer >= FLASHLIGHT_DURATION:
		flashlight_active = false
		flashlight_overlay.visible = false
		flashlight_reveal_label.visible = false
	flashlight_btn_left.visible = not camera_open and not flashlight_active
	flashlight_btn_right.visible = not camera_open and not flashlight_active

func _make_sfx(path: String, loop: bool = false, vol: float = 0.0) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.stream = load(path)
	if loop and player.stream is AudioStreamOggVorbis:
		player.stream.loop = true
	player.volume_db = vol
	add_child(player)
	return player

func _build_audio():
	sfx_ambient       = _make_sfx("res://sounds/ambient_loop.ogg", true, -12.0)
	sfx_door          = _make_sfx("res://sounds/door_open_close.ogg")
	sfx_camera_up     = _make_sfx("res://sounds/cam_open.ogg")
	sfx_camera_down   = _make_sfx("res://sounds/cam_down.ogg")
	sfx_flash         = _make_sfx("res://sounds/flash_light.ogg")
	sfx_jumpscare     = _make_sfx("res://sounds/jump_scare.ogg")
	sfx_kolzaru       = _make_sfx("res://sounds/kolzaru_appear.ogg")
	sfx_phone_ring    = _make_sfx("res://sounds/phone_ring.ogg")
	sfx_power_down    = _make_sfx("res://sounds/power_down.ogg")
	sfx_power_warning = _make_sfx("res://sounds/power_warning.ogg")
	sfx_six_am        = _make_sfx("res://sounds/six_am.ogg")
	sfx_sleep_snore   = _make_sfx("res://sounds/sleep_snore.ogg")
	sfx_tung_swing    = _make_sfx("res://sounds/tung_swing.ogg")
	sfx_wake_up       = _make_sfx("res://sounds/wake_up.ogg")

func _build_power_warning():
	power_warn_label = Label.new()
	power_warn_label.text = "!! LOW POWER !!"
	power_warn_label.set_position(Vector2(420, 578))
	power_warn_label.add_theme_font_size_override("font_size", 24)
	power_warn_label.add_theme_color_override("font_color", Color.RED)
	power_warn_label.visible = false
	hud_layer.add_child(power_warn_label)

func _build_audio_warning():
	audio_warn_label = Label.new()
	audio_warn_label.set_position(Vector2(300, 28))
	audio_warn_label.add_theme_font_size_override("font_size", 20)
	audio_warn_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.1))
	audio_warn_label.visible = false
	hud_layer.add_child(audio_warn_label)

func _update_astro_warning():
	var st = anim_state.get("Astro", {})
	if not st.get("active", false):
		audio_warn_label.visible = false
		return
	var idx  = st.get("index", 0)
	var path = ANIMATRONICS["Astro"]["path"]
	if idx >= path.size() - 2:  # SHADOW_NEAR or DOOR — he's close
		var door = st.get("target_door", "LEFT_DOOR")
		var side = "LEFT" if door == "LEFT_DOOR" else "RIGHT"
		audio_warn_label.text = "[ You hear something near the %s door... ]" % side
		audio_warn_label.visible = true
	else:
		audio_warn_label.visible = false

func _build_camera_overlay():
	cam_overlay = Control.new()
	cam_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam_overlay.visible = false
	hud_layer.add_child(cam_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.04, 0.01, 0.92)  # slight green tint — security camera look
	cam_overlay.add_child(bg)

	var header = Label.new()
	header.text = "STACK VALIDATED'S EMPORIUM  —  SECURITY CAMERAS"
	header.set_position(Vector2(0, 8))
	header.set_size(Vector2(1152, 26))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	cam_overlay.add_child(header)

	cam_title_label = Label.new()
	cam_title_label.text = "CAM 1 — Show Stage"
	cam_title_label.set_position(Vector2(260, 54))
	cam_title_label.add_theme_font_size_override("font_size", 34)
	cam_title_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	cam_overlay.add_child(cam_title_label)

	cam_anim_label = Label.new()
	cam_anim_label.text = "[ NO ACTIVITY ]"
	cam_anim_label.set_position(Vector2(260, 130))
	cam_anim_label.add_theme_font_size_override("font_size", 26)
	cam_anim_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	cam_overlay.add_child(cam_anim_label)

	cam_list_label = Label.new()
	cam_list_label.set_position(Vector2(18, 54))
	cam_list_label.add_theme_font_size_override("font_size", 13)
	cam_list_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
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

	# Dragon Ball UI (inside camera overlay)
	cam_db_label = Label.new()
	cam_db_label.text = "★  DRAGON BALL IS HERE!"
	cam_db_label.set_position(Vector2(370, 310))
	cam_db_label.add_theme_font_size_override("font_size", 24)
	cam_db_label.add_theme_color_override("font_color", Color.ORANGE)
	cam_db_label.visible = false
	cam_overlay.add_child(cam_db_label)

	db_collect_btn = Button.new()
	db_collect_btn.text = "COLLECT"
	db_collect_btn.set_position(Vector2(470, 356))
	db_collect_btn.set_size(Vector2(190, 44))
	db_collect_btn.add_theme_font_size_override("font_size", 18)
	db_collect_btn.visible = false
	db_collect_btn.pressed.connect(_collect_dragon_ball)
	cam_overlay.add_child(db_collect_btn)

	cam_db_counter = Label.new()
	cam_db_counter.set_position(Vector2(260, 102))
	cam_db_counter.add_theme_font_size_override("font_size", 16)
	cam_db_counter.add_theme_color_override("font_color", Color.ORANGE)
	cam_overlay.add_child(cam_db_counter)

	# Owen flash button
	owen_flash_btn = Button.new()
	owen_flash_btn.text = "FLASH LIGHT"
	owen_flash_btn.set_position(Vector2(460, 420))
	owen_flash_btn.set_size(Vector2(210, 44))
	owen_flash_btn.add_theme_font_size_override("font_size", 18)
	owen_flash_btn.add_theme_color_override("font_color", Color.WHITE)
	owen_flash_btn.visible = false
	owen_flash_btn.pressed.connect(_flash_owen)
	cam_overlay.add_child(owen_flash_btn)

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

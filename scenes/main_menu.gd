extends Control

const W = 1152.0
const H = 648.0

var static_overlay: ColorRect
var static_timer: Timer

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_title()
	_build_night_selector()
	_build_new_game_button()
	_build_footer()
	_build_static_overlay()

# ── Background ─────────────────────────────────────────────────────────────────
func _build_background():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.02, 0.01)
	add_child(bg)

	# Subtle vignette gradient panels (top and bottom darkening)
	var top_fade = ColorRect.new()
	top_fade.set_position(Vector2(0, 0))
	top_fade.set_size(Vector2(W, 80))
	top_fade.color = Color(0.0, 0.0, 0.0, 0.5)
	add_child(top_fade)

	var bot_fade = ColorRect.new()
	bot_fade.set_position(Vector2(0, H - 80))
	bot_fade.set_size(Vector2(W, 80))
	bot_fade.color = Color(0.0, 0.0, 0.0, 0.5)
	add_child(bot_fade)

# ── Title ──────────────────────────────────────────────────────────────────────
func _build_title():
	_separator(34)

	var title = Label.new()
	title.text = "FIVE NIGHTS AT STACK"
	title.set_position(Vector2(0, 50))
	title.set_size(Vector2(W, 90))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.08))
	add_child(title)

	var sub = Label.new()
	sub.text = "STACK VALIDATED'S EMPORIUM"
	sub.set_position(Vector2(0, 142))
	sub.set_size(Vector2(W, 34))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.65, 0.45, 0.10))
	add_child(sub)

	_separator(178)

# ── Night selector ─────────────────────────────────────────────────────────────
func _build_night_selector():
	var hdr = Label.new()
	hdr.text = "— SELECT NIGHT —"
	hdr.set_position(Vector2(0, 202))
	hdr.set_size(Vector2(W, 30))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.add_theme_color_override("font_color", Color(0.75, 0.55, 0.18))
	add_child(hdr)

	var btn_w   = 140.0
	var gap     = 18.0
	var row_w   = btn_w * 6 + gap * 5
	var start_x = (W - row_w) / 2.0
	var btn_y   = 244.0

	for i in range(6):
		var night_num = i + 1
		var col_x  = start_x + i * (btn_w + gap)
		# Night 1 always open; every other night requires the previous one complete
		var unlocked = (i == 0) or GameManager.nights_completed[i - 1]

		var night_lbl = Label.new()
		night_lbl.text = "NIGHT %d" % night_num
		night_lbl.set_position(Vector2(col_x, btn_y))
		night_lbl.set_size(Vector2(btn_w, 22))
		night_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		night_lbl.add_theme_font_size_override("font_size", 13)
		night_lbl.add_theme_color_override(
			"font_color",
			Color(0.75, 0.60, 0.25) if unlocked else Color(0.35, 0.28, 0.18)
		)
		add_child(night_lbl)

		var btn = Button.new()
		btn.text  = str(night_num) if unlocked else "[LOCK]"
		btn.set_position(Vector2(col_x + 30, btn_y + 24))
		btn.set_size(Vector2(btn_w - 60, 52))
		btn.add_theme_font_size_override("font_size", 28)
		btn.disabled = not unlocked
		if unlocked:
			btn.pressed.connect(_start_night.bind(night_num))
		add_child(btn)

		var completed = GameManager.nights_completed[i]
		var star_lbl = Label.new()
		star_lbl.text = "★★★" if completed else "☆☆☆"
		star_lbl.set_position(Vector2(col_x + 18, btn_y + 82))
		star_lbl.set_size(Vector2(btn_w, 26))
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.add_theme_font_size_override("font_size", 20)
		star_lbl.add_theme_color_override(
			"font_color",
			Color.YELLOW if completed else (Color(0.30, 0.28, 0.22) if unlocked else Color(0.18, 0.16, 0.12))
		)
		add_child(star_lbl)

# ── New Game / Custom Night buttons ───────────────────────────────────────────
func _build_new_game_button():
	var new_btn = Button.new()
	new_btn.text = "NEW GAME"
	new_btn.set_position(Vector2(W / 2.0 - 240.0, 400))
	new_btn.set_size(Vector2(210, 54))
	new_btn.add_theme_font_size_override("font_size", 22)
	new_btn.pressed.connect(_new_game)
	add_child(new_btn)

	# Custom Night unlocks after completing Night 5
	var custom_unlocked = GameManager.nights_completed[4]
	var custom_btn = Button.new()
	custom_btn.text = "CUSTOM NIGHT" if custom_unlocked else "[LOCK] CUSTOM"
	custom_btn.set_position(Vector2(W / 2.0 + 30.0, 400))
	custom_btn.set_size(Vector2(210, 54))
	custom_btn.add_theme_font_size_override("font_size", 18)
	custom_btn.disabled = not custom_unlocked
	if custom_unlocked:
		custom_btn.pressed.connect(_open_custom_night)
	add_child(custom_btn)

# ── Footer ─────────────────────────────────────────────────────────────────────
func _build_footer():
	_separator(490)

	var flavor = Label.new()
	flavor.text = '"The show must go on..."'
	flavor.set_position(Vector2(0, 504))
	flavor.set_size(Vector2(W, 26))
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_font_size_override("font_size", 15)
	flavor.add_theme_color_override("font_color", Color(0.45, 0.32, 0.10))
	add_child(flavor)

	_separator(536)

	var ver = Label.new()
	ver.text = "v0.1"
	ver.set_position(Vector2(W - 60, H - 30))
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
	add_child(ver)

# ── CRT static flicker ────────────────────────────────────────────────────────
func _build_static_overlay():
	static_overlay = ColorRect.new()
	static_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(static_overlay)

	static_timer = Timer.new()
	static_timer.wait_time = 0.07
	static_timer.autostart = true
	static_timer.timeout.connect(_flicker)
	add_child(static_timer)

func _flicker():
	static_overlay.color.a = randf_range(0.01, 0.05) if randf() < 0.12 else 0.0

# ── Helpers ───────────────────────────────────────────────────────────────────
func _separator(y: float):
	var sep = Label.new()
	sep.text = "─".repeat(72)
	sep.set_position(Vector2(30, y))
	sep.add_theme_font_size_override("font_size", 13)
	sep.add_theme_color_override("font_color", Color(0.50, 0.35, 0.08))
	add_child(sep)

# ── Navigation ────────────────────────────────────────────────────────────────
func _new_game():
	_start_night(1)

func _start_night(night: int):
	GameManager.is_custom_night = false
	GameManager.night_number    = night
	GameManager.power           = 100.0
	GameManager.current_hour    = 12
	GameManager.doors_open      = false
	GameManager.camera_open     = false
	get_tree().change_scene_to_file("res://scenes/Office.tscn")

func _open_custom_night():
	get_tree().change_scene_to_file("res://scenes/CustomNight.tscn")

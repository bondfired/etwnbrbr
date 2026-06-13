extends Control

const W = 1152.0
const H = 648.0

const ANIM_KEYS   = ["BonnieJake", "ChicaJasker", "FreddyMarcus", "FoxyBlitz"]
const ANIM_LABELS = ["BONNIE JAKE", "CHICA JASKER", "FREDDY MARCUS", "FOXY BLITZ"]

var ai_displays: Dictionary = {}   # anim_name -> Label showing the number
var static_overlay: ColorRect

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_title()
	_build_animatronic_controls()
	_build_presets()
	_build_action_buttons()
	_build_static()

# ── Background ─────────────────────────────────────────────────────────────────
func _build_background():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.02, 0.01)
	add_child(bg)

	var top = ColorRect.new()
	top.set_position(Vector2(0, 0))
	top.set_size(Vector2(W, 70))
	top.color = Color(0, 0, 0, 0.5)
	add_child(top)

	var bot = ColorRect.new()
	bot.set_position(Vector2(0, H - 70))
	bot.set_size(Vector2(W, 70))
	bot.color = Color(0, 0, 0, 0.5)
	add_child(bot)

# ── Title ──────────────────────────────────────────────────────────────────────
func _build_title():
	_separator(30)

	var title = Label.new()
	title.text = "CUSTOM NIGHT"
	title.set_position(Vector2(0, 46))
	title.set_size(Vector2(W, 76))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.08))
	add_child(title)

	var sub = Label.new()
	sub.text = "Set each animatronic's AI level  (0 = inactive  /  20 = maximum)"
	sub.set_position(Vector2(0, 124))
	sub.set_size(Vector2(W, 26))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.55, 0.42, 0.15))
	add_child(sub)

	_separator(152)

# ── Per-animatronic controls ───────────────────────────────────────────────────
func _build_animatronic_controls():
	var col_w   = 240.0
	var total_w = col_w * 4
	var start_x = (W - total_w) / 2.0
	var top_y   = 172.0

	for i in range(4):
		var key   = ANIM_KEYS[i]
		var label = ANIM_LABELS[i]
		var cx    = start_x + i * col_w

		# Name
		var name_lbl = Label.new()
		name_lbl.text = label
		name_lbl.set_position(Vector2(cx, top_y))
		name_lbl.set_size(Vector2(col_w - 8, 28))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 0.18))
		add_child(name_lbl)

		# Big AI number
		var num_lbl = Label.new()
		num_lbl.text = str(GameManager.custom_ai[key])
		num_lbl.set_position(Vector2(cx + 70, top_y + 34))
		num_lbl.set_size(Vector2(100, 80))
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 62)
		num_lbl.add_theme_color_override("font_color", Color.WHITE)
		add_child(num_lbl)
		ai_displays[key] = num_lbl

		# Decrease button
		var dec = Button.new()
		dec.text = "-"
		dec.set_position(Vector2(cx + 14, top_y + 50))
		dec.set_size(Vector2(52, 52))
		dec.add_theme_font_size_override("font_size", 32)
		dec.pressed.connect(_change_ai.bind(key, -1))
		add_child(dec)

		# Increase button
		var inc = Button.new()
		inc.text = "+"
		inc.set_position(Vector2(cx + col_w - 66, top_y + 50))
		inc.set_size(Vector2(52, 52))
		inc.add_theme_font_size_override("font_size", 32)
		inc.pressed.connect(_change_ai.bind(key, 1))
		add_child(inc)

		# AI level bar (visual indicator)
		var bar_bg = ColorRect.new()
		bar_bg.set_position(Vector2(cx + 14, top_y + 112))
		bar_bg.set_size(Vector2(col_w - 28, 10))
		bar_bg.color = Color(0.18, 0.14, 0.08)
		add_child(bar_bg)

		var bar_fill = ColorRect.new()
		bar_fill.set_position(Vector2(cx + 14, top_y + 112))
		var fill_w = (col_w - 28) * GameManager.custom_ai[key] / 20.0
		bar_fill.set_size(Vector2(fill_w, 10))
		bar_fill.color = Color(0.90, 0.65, 0.10)
		add_child(bar_fill)
		# Store bar ref so _change_ai can update it
		ai_displays[key + "_bar"] = bar_fill
		ai_displays[key + "_bar_max_w"] = col_w - 28

	_separator(310)

# ── Presets ────────────────────────────────────────────────────────────────────
func _build_presets():
	var hdr = Label.new()
	hdr.text = "— PRESETS —"
	hdr.set_position(Vector2(0, 324))
	hdr.set_size(Vector2(W, 26))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", Color(0.65, 0.45, 0.10))
	add_child(hdr)

	var presets = [
		["ALL 0",  [0,  0,  0,  0 ]],
		["ALL 5",  [5,  5,  5,  5 ]],
		["ALL 10", [10, 10, 10, 10]],
		["ALL 20", [20, 20, 20, 20]],
	]

	var btn_w   = 170.0
	var gap     = 16.0
	var total_w = btn_w * 4 + gap * 3
	var start_x = (W - total_w) / 2.0

	for i in range(presets.size()):
		var p   = presets[i]
		var btn = Button.new()
		btn.text = p[0]
		btn.set_position(Vector2(start_x + i * (btn_w + gap), 356))
		btn.set_size(Vector2(btn_w, 42))
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(_apply_preset.bind(p[1]))
		add_child(btn)

	_separator(412)

# ── Start / Back buttons ───────────────────────────────────────────────────────
func _build_action_buttons():
	var start_btn = Button.new()
	start_btn.text = "START NIGHT"
	start_btn.set_position(Vector2(W / 2.0 - 230.0, 430))
	start_btn.set_size(Vector2(210, 54))
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.pressed.connect(_start_custom)
	add_child(start_btn)

	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.set_position(Vector2(W / 2.0 + 20.0, 430))
	back_btn.set_size(Vector2(210, 54))
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

# ── Static flicker ─────────────────────────────────────────────────────────────
func _build_static():
	static_overlay = ColorRect.new()
	static_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_overlay.color = Color(1, 1, 1, 0)
	static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(static_overlay)

	var timer = Timer.new()
	timer.wait_time = 0.07
	timer.autostart = true
	timer.timeout.connect(_flicker)
	add_child(timer)

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

func _change_ai(key: String, delta: int):
	GameManager.custom_ai[key] = clamp(GameManager.custom_ai[key] + delta, 0, 20)
	var val = GameManager.custom_ai[key]
	ai_displays[key].text = str(val)
	var max_w = ai_displays[key + "_bar_max_w"]
	ai_displays[key + "_bar"].size.x = max_w * val / 20.0

func _apply_preset(values: Array):
	for i in range(ANIM_KEYS.size()):
		var key = ANIM_KEYS[i]
		GameManager.custom_ai[key] = values[i]
		ai_displays[key].text = str(values[i])
		var max_w = ai_displays[key + "_bar_max_w"]
		ai_displays[key + "_bar"].size.x = max_w * values[i] / 20.0

# ── Navigation ────────────────────────────────────────────────────────────────
func _start_custom():
	GameManager.is_custom_night = true
	GameManager.night_number    = 7
	GameManager.power           = 100.0
	GameManager.current_hour    = 12
	GameManager.doors_open      = false
	GameManager.camera_open     = false
	get_tree().change_scene_to_file("res://scenes/Office.tscn")

func _go_back():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

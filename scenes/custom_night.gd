extends Control

const W = 1152.0
const H = 648.0

const ANIM_KEYS   = ["BonnieJake", "ChicaJasker", "FreddyMarcus", "FoxyBlitz", "Doggie", "Astro", "BFB", "Goku"]
const ANIM_LABELS = ["BONNIE JAKE", "CHICA JASKER", "FREDDY MARCUS", "FOXY BLITZ", "DOGGIE", "ASTRO", "BFB", "GOKU"]

var ai_displays: Dictionary = {}
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
	for y_pos in [0.0, H - 70.0]:
		var fade = ColorRect.new()
		fade.set_position(Vector2(0, y_pos))
		fade.set_size(Vector2(W, 70))
		fade.color = Color(0, 0, 0, 0.5)
		add_child(fade)

# ── Title ──────────────────────────────────────────────────────────────────────
func _build_title():
	_separator(28)

	var title = Label.new()
	title.text = "CUSTOM NIGHT"
	title.set_position(Vector2(0, 42))
	title.set_size(Vector2(W, 68))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.08))
	add_child(title)

	var sub = Label.new()
	sub.text = "Set each animatronic's AI level  (0 = inactive  /  20 = maximum)"
	sub.set_position(Vector2(0, 112))
	sub.set_size(Vector2(W, 24))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.55, 0.42, 0.15))
	add_child(sub)

	_separator(138)

# ── Per-animatronic controls (2 rows of 3) ────────────────────────────────────
func _build_animatronic_controls():
	var col_w   = 264.0
	var total_w = col_w * 4
	var start_x = (W - total_w) / 2.0

	for i in range(8):
		var key   = ANIM_KEYS[i]
		var label = ANIM_LABELS[i]
		var row   = i / 4       # 0 = top row, 1 = bottom row
		var col   = i % 4
		var cx    = start_x + col * col_w
		var cy    = 152.0 + row * 120.0

		# Name
		var name_lbl = Label.new()
		name_lbl.text = label
		name_lbl.set_position(Vector2(cx, cy))
		name_lbl.set_size(Vector2(col_w - 8, 24))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 0.18))
		add_child(name_lbl)

		# Big AI number
		var num_lbl = Label.new()
		num_lbl.text = str(GameManager.custom_ai[key])
		num_lbl.set_position(Vector2(cx + 120, cy + 26))
		num_lbl.set_size(Vector2(100, 58))
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 48)
		num_lbl.add_theme_color_override("font_color", Color.WHITE)
		add_child(num_lbl)
		ai_displays[key] = num_lbl

		# Decrease button
		var dec = Button.new()
		dec.text = "-"
		dec.set_position(Vector2(cx + 50, cy + 34))
		dec.set_size(Vector2(48, 48))
		dec.add_theme_font_size_override("font_size", 28)
		dec.pressed.connect(_change_ai.bind(key, -1))
		add_child(dec)

		# Increase button
		var inc = Button.new()
		inc.text = "+"
		inc.set_position(Vector2(cx + col_w - 106, cy + 34))
		inc.set_size(Vector2(48, 48))
		inc.add_theme_font_size_override("font_size", 28)
		inc.pressed.connect(_change_ai.bind(key, 1))
		add_child(inc)

		# Fill bar
		var bar_w = col_w - 80.0
		var bar_bg = ColorRect.new()
		bar_bg.set_position(Vector2(cx + 50, cy + 92))
		bar_bg.set_size(Vector2(bar_w, 8))
		bar_bg.color = Color(0.18, 0.14, 0.08)
		add_child(bar_bg)

		var bar_fill = ColorRect.new()
		bar_fill.set_position(Vector2(cx + 50, cy + 92))
		bar_fill.set_size(Vector2(bar_w * GameManager.custom_ai[key] / 20.0, 8))
		bar_fill.color = Color(0.90, 0.65, 0.10)
		add_child(bar_fill)
		ai_displays[key + "_bar"]     = bar_fill
		ai_displays[key + "_bar_max"] = bar_w

	_separator(410)

# ── Presets ────────────────────────────────────────────────────────────────────
func _build_presets():
	var hdr = Label.new()
	hdr.text = "— PRESETS —"
	hdr.set_position(Vector2(0, 422))
	hdr.set_size(Vector2(W, 24))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", Color(0.65, 0.45, 0.10))
	add_child(hdr)

	var presets = [
		["ALL 0",  [0,  0,  0,  0,  0,  0,  0,  0]],
		["ALL 5",  [5,  5,  5,  5,  5,  5,  5,  5]],
		["ALL 10", [10, 10, 10, 10, 10, 10, 10, 10]],
		["ALL 20", [20, 20, 20, 20, 20, 20, 20, 20]],
	]

	var btn_w   = 160.0
	var gap     = 16.0
	var total_w = btn_w * 4 + gap * 3
	var start_x = (W - total_w) / 2.0

	for i in range(presets.size()):
		var p   = presets[i]
		var btn = Button.new()
		btn.text = p[0]
		btn.set_position(Vector2(start_x + i * (btn_w + gap), 450))
		btn.set_size(Vector2(btn_w, 38))
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_apply_preset.bind(p[1]))
		add_child(btn)

	_separator(496)

# ── Start / Back ───────────────────────────────────────────────────────────────
func _build_action_buttons():
	var start_btn = Button.new()
	start_btn.text = "START NIGHT"
	start_btn.set_position(Vector2(W / 2.0 - 230.0, 512))
	start_btn.set_size(Vector2(210, 50))
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_start_custom)
	add_child(start_btn)

	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.set_position(Vector2(W / 2.0 + 20.0, 512))
	back_btn.set_size(Vector2(210, 50))
	back_btn.add_theme_font_size_override("font_size", 20)
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
	timer.timeout.connect(func(): static_overlay.color.a = randf_range(0.01, 0.05) if randf() < 0.12 else 0.0)
	add_child(timer)

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
	ai_displays[key + "_bar"].size.x = ai_displays[key + "_bar_max"] * val / 20.0

func _apply_preset(values: Array):
	for i in range(ANIM_KEYS.size()):
		var key = ANIM_KEYS[i]
		GameManager.custom_ai[key] = values[i]
		ai_displays[key].text = str(values[i])
		ai_displays[key + "_bar"].size.x = ai_displays[key + "_bar_max"] * values[i] / 20.0

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

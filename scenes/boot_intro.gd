extends Control

const W = 1152.0
const H = 648.0

# Boot lines printed one-by-one, then the logo appears, then "Press any key"
const BOOT_LINES: Array = [
	"SVE-OS v2.31 (C) 1987 Stack Validated Systems Inc.",
	"Initialising memory banks......... OK",
	"Loading security subsystem......... OK",
	"Detecting animatronic units......... 10 found",
	"Calibrating camera network......... OK",
	"Mounting drive C:\\SVE\\NIGHT\\......... OK",
	"",
	"WARNING: Do not tamper with animatronic hardware.",
	"",
	"Starting night-watch software......",
]

const LINE_DELAY   : float = 0.18   # seconds between boot lines
const LOGO_DELAY   : float = 0.9    # pause after last line before logo appears
const PROMPT_DELAY : float = 0.5    # pause after logo before prompt blinks
const BLINK_RATE   : float = 0.55   # prompt blink period

var _line_index    : int   = 0
var _phase         : int   = 0      # 0=booting, 1=logo, 2=prompt
var _elapsed       : float = 0.0
var _blink_elapsed : float = 0.0
var _blink_on      : bool  = true

var _text_label    : RichTextLabel
var _logo_label    : Label
var _sub_label     : Label
var _prompt_label  : Label
var _static_overlay: ColorRect
var _sfx_beep      : AudioStreamPlayer

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_audio()
	_build_ui()

func _build_audio():
	_sfx_beep = AudioStreamPlayer.new()
	_sfx_beep.stream = load("res://sounds/boot_beep.ogg")
	add_child(_sfx_beep)
	_sfx_beep.play()

func _build_ui():
	# Dark CRT background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.02)
	add_child(bg)

	# Scanline overlay
	var scan = ColorRect.new()
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan.color = Color(0.0, 0.0, 0.0, 0.18)
	add_child(scan)

	# Boot text output — left-aligned, monospace-looking via small font
	_text_label = RichTextLabel.new()
	_text_label.set_position(Vector2(60, 60))
	_text_label.set_size(Vector2(W - 120, 300))
	_text_label.add_theme_font_size_override("normal_font_size", 15)
	_text_label.add_theme_color_override("default_color", Color(0.25, 0.9, 0.25))
	_text_label.bbcode_enabled = false
	_text_label.scroll_active = false
	add_child(_text_label)

	# Venue logo (hidden until phase 1)
	_logo_label = Label.new()
	_logo_label.text = "STACK VALIDATED'S EMPORIUM"
	_logo_label.set_position(Vector2(0, 340))
	_logo_label.set_size(Vector2(W, 80))
	_logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo_label.add_theme_font_size_override("font_size", 56)
	_logo_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.08))
	_logo_label.visible = false
	add_child(_logo_label)

	_sub_label = Label.new()
	_sub_label.text = "FIVE NIGHTS AT STACK"
	_sub_label.set_position(Vector2(0, 424))
	_sub_label.set_size(Vector2(W, 32))
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 20)
	_sub_label.add_theme_color_override("font_color", Color(0.55, 0.38, 0.10))
	_sub_label.visible = false
	add_child(_sub_label)

	# "Press any key" prompt (hidden until phase 2)
	_prompt_label = Label.new()
	_prompt_label.text = "PRESS ANY KEY TO CONTINUE"
	_prompt_label.set_position(Vector2(0, 490))
	_prompt_label.set_size(Vector2(W, 30))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_prompt_label.visible = false
	add_child(_prompt_label)

	# Static flicker on top
	_static_overlay = ColorRect.new()
	_static_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_static_overlay.color = Color(1, 1, 1, 0)
	_static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_static_overlay)

	var flicker_timer = Timer.new()
	flicker_timer.wait_time = 0.07
	flicker_timer.autostart = true
	flicker_timer.timeout.connect(func(): _static_overlay.color.a = randf_range(0.01, 0.04) if randf() < 0.15 else 0.0)
	add_child(flicker_timer)

func _process(delta: float):
	_elapsed += delta

	match _phase:
		0:  # printing boot lines
			if _line_index < BOOT_LINES.size():
				if _elapsed >= LINE_DELAY:
					_elapsed -= LINE_DELAY
					_text_label.text += BOOT_LINES[_line_index] + "\n"
					_line_index += 1
			else:
				if _elapsed >= LOGO_DELAY:
					_elapsed = 0.0
					_phase = 1
					_logo_label.visible = true
					_sub_label.visible  = true
		1:  # logo shown, short pause then prompt
			if _elapsed >= PROMPT_DELAY:
				_elapsed = 0.0
				_phase = 2
				_prompt_label.visible = true
		2:  # blinking prompt — wait for any input
			_blink_elapsed += delta
			if _blink_elapsed >= BLINK_RATE:
				_blink_elapsed -= BLINK_RATE
				_blink_on = not _blink_on
				_prompt_label.visible = _blink_on

func _input(event: InputEvent):
	if _phase < 2:
		return
	if event is InputEventKey and event.pressed:
		_go_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_menu()

func _go_to_menu():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

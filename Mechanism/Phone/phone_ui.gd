extends Control

signal close_requested

const DATA_PATH := "res://Resources/Data/phone_data.json"
const LCD_SHADER := preload("res://Assets/UI/phone_lcd.gdshader")

## The 3x3 menu, row by row: name, colour, icon and what each one opens.
@export var apps: Array[PhoneApp] = []

@export_group("Icons")
## Message list: not read yet / already read.
@export var icon_envelope_new: Texture2D
@export var icon_envelope_read: Texture2D
## Call history arrows.
@export var icon_call_missed: Texture2D
@export var icon_call_incoming: Texture2D
@export var icon_call_outgoing: Texture2D
## Little person on contact rows.
@export var icon_contact: Texture2D
## Big picture on contact and call pages (shown 3x).
@export var icon_avatar: Texture2D
## Sign in the "App stopped working" popup (shown 2x).
@export var icon_warning: Texture2D
## Logo on the boot screen (pops in at 1x, 2x, 3x).
@export var icon_boot_logo: Texture2D
## Sprite strips: 5 frames side by side = 0, 1, 2, 3, 4 bars.
@export var signal_strip: Texture2D
@export var battery_strip: Texture2D

# Screen colours
const TEXT := Color("#e8f0ff")
const TEXT_DIM := Color("#8696b8")
const TEXT_DARK := Color("#0b1022")
const MISSED := Color("#ff5a5a")   # missed-call names
const BUBBLE := Color("#26314f")
const SECTION := Color("#141b33")
const BACKLIGHT := Color("#cfe0ff")
const LED_ON := Color("#4dff7a")
const LED_OFF := Color("#1b2a1f")

## WASD works like the arrow keys while the phone is open.
const WASD := {
	"move_forward": "ui_up",
	"move_back": "ui_down",
	"move_left": "ui_left",
	"move_right": "ui_right",
}

## The Call app keypad, row by row, and the letters printed on each key.
const KEYPAD := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
const KEY_LETTERS := {"2": "ABC", "3": "DEF", "4": "GHI", "5": "JKL", "6": "MNO", "7": "PQRS", "8": "TUV", "9": "WXYZ"}
const MAX_DIGITS := 20
const KEY_LOWEST_PITCH := 0.8
const KEY_PITCH_STEP := 0.05
## How long a secret code rings before someone picks up (and before the scare starts).
const ONE_RING_TIME := 2.2
## The scare: after this many wrong numbers, for about this many seconds. Once per game.
const SCARE_AFTER := 3
const SCARE_TIME := 5.0
const SCARE_RED := Color("#ff1414")
const SCARE_TEXT := "I SEE YOU"
const SCARE_GLITCHES := ["I S EE YOU", "I SEE Y0U", "I 5EE YOU", "1 SEE YOU", "I SEE  YOU", "I SE3 YOU", "I SEE YO U", "I SEE YOU I SEE", "SEE YOU"]

# "static" = remembered for the whole game, even after the phone window closes.
static var _booted := false
static var _read_threads := {}          # sender name -> true once the thread was opened
static var _seen_missed_calls := false
static var _sms_received: Array[Dictionary] = []   # secret texts the Call app already sent
static var _wrong_calls := 0              # wrong numbers dialled this game
static var _scared := false               # the "I SEE YOU" scare already happened

@onready var _header: Panel = %Header
@onready var _header_title: Label = %HeaderTitle
@onready var _header_right: Label = %HeaderRight
@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: VBoxContainer = %Content
@onready var _popup: Control = %Popup
@onready var _splash: ColorRect = %Splash

var _data := {}
var _screen_id := ""                     # which screen is showing ("home", "menu", "messages"...)
var _current := Callable()               # the function that draws that screen
var _history: Array[Dictionary] = []     # screens to go back to
var _items: Array[Control] = []          # things you can highlight on this screen
var _accent := Color.WHITE               # colour of the open app
var _menu_buttons: Array[Control] = []
var _photo_index := 0
var _booting := false
var _stick_to_bottom := false
var _start_at: Control = null           # where a chat with new messages opens
var _popup_focus := 0
var _popup_tween: Tween
var _clock := 0.0
static var _photo_cache := {}
var _lcd_material: ShaderMaterial
var _static_material: ShaderMaterial
var _header_style: StyleBoxFlat
var _title_style: StyleBoxFlat
var _dialed := ""                        # what is typed on the Call keypad
var _dial_display: Label
var _call_status: Label
var _call_tween: Tween
var _call_connected_at := -1             # when someone picked up (ms); -1 = not connected
var _scare: ColorRect                    # the black screen while the scare is on
var _scare_noise: ColorRect
var _scare_lines: Array[Label] = []
var _scare_tick := 0.0
var _screaming := false
var _window_home := Vector2i.ZERO


func _ready() -> void:
	_data = _load_data()
	for sms: Dictionary in _sms_received:   # texts that already arrived earlier in the game
		_put_sms_in_inbox(sms)
	_lcd_material = _make_lcd_material(false)
	_static_material = _make_lcd_material(true)

	# Own copies of these boxes so each app can recolour them.
	_header_style = _header.get_theme_stylebox("panel").duplicate()
	_header.add_theme_stylebox_override("panel", _header_style)
	_title_style = %DialogTitleBar.get_theme_stylebox("panel").duplicate()
	%DialogTitleBar.add_theme_stylebox_override("panel", _title_style)

	_fill_phone_info()
	_build_menu()
	%SoftLeft.pressed.connect(_on_soft_left)
	%SoftCenter.pressed.connect(_on_soft_center)
	%SoftRight.pressed.connect(_back)
	%TabAll.pressed.connect(_switch_calls_tab.bind("all"))
	%TabMissed.pressed.connect(_switch_calls_tab.bind("missed"))
	%DialogOk.pressed.connect(_close_popup)
	_scroll.get_v_scroll_bar().changed.connect(_on_scroll_range_changed)

	_popup.visible = false
	_go_home()
	if _booted:
		_splash.visible = false
	else:
		_play_boot()


func _process(delta: float) -> void:
	_warm_next_photo()
	_clock += delta
	# The ":" in the clock blinks every half second.
	%ClockColon.modulate.a = 1.0 if fmod(_clock, 1.0) < 0.5 else 0.0
	# The little light above the screen flashes while something is unread.
	var something_new := _unread_count() + _missed_count() > 0
	%Led.color = LED_ON if something_new and fmod(_clock, 2.0) < 0.12 else LED_OFF
	if _call_connected_at >= 0:   # call timer, like 00:07
		var seconds := int((Time.get_ticks_msec() - _call_connected_at) / 1000.0)
		_call_status.text = "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	if _screaming:
		_glitch_scare(delta)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# Number keys type on the Call keypad. This comes first because 1 also
	# opens/closes the phone (use_phone), and on the keypad it should type a 1.
	var typed := _typed_key(event)
	if typed != "" and _screen_id == "dial" and not (_popup.visible or _scare or _booting):
		_dial_press(typed)
		if not _items[-1].has_focus():
			_items[-1].grab_focus()   # jump to CALL, so Enter rings the number
		get_viewport().set_input_as_handled()
		return
	# Q, Esc, Tab or 1 put the phone away, even while it boots.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit") or event.is_action_pressed("use_phone"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _scare:
		get_viewport().set_input_as_handled()   # nothing works while it screams
		return
	if _booting:
		return

	# Mouse. Buttons only react to the left button, so right click is caught here.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if _screen_id == "home" and not _popup.visible:
				_open(_show_menu)
			else:
				_back()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and _screen_id == "home" and not _popup.visible and %Screen.get_global_rect().has_point(event.position):
			_open(_show_menu)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		if _screen_id == "dial" and _dialed != "" and not _popup.visible:
			_dial_delete()   # on the keypad, Backspace rubs out the last digit first
		elif not event.echo:
			_back()
		get_viewport().set_input_as_handled()
		return

	# Turn W/A/S/D into the arrow-key actions the menus already understand.
	for action: String in WASD:
		if event.is_action_pressed(action, true):
			var arrow := InputEventAction.new()
			arrow.action = WASD[action]
			arrow.pressed = true
			get_viewport().push_input.call_deferred(arrow)
			get_viewport().set_input_as_handled()
			return

	if _popup.visible:
		# Don't let the arrows move the highlight behind the popup.
		for arrow: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action_pressed(arrow, true):
				get_viewport().set_input_as_handled()
		return

	var handled := true
	if _screen_id == "home" and event.is_action_pressed("ui_accept"):
		_open(_show_menu)
	elif _screen_id == "calls" and event.is_action_pressed("ui_left"):
		_switch_calls_tab("all")
	elif _screen_id == "calls" and event.is_action_pressed("ui_right"):
		_switch_calls_tab("missed")
	elif _screen_id == "photo" and event.is_action_pressed("ui_left"):
		_step_photo(-1)
	elif _screen_id == "photo" and event.is_action_pressed("ui_right"):
		_step_photo(1)
	elif _items.is_empty() and _screen_id != "home" and event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= 12   # pages with nothing to highlight just scroll
	elif _items.is_empty() and _screen_id != "home" and event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += 12
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_soft_left() -> void:
	if _screen_id == "photo":
		_step_photo(-1)
	elif _screen_id == "dial":
		_dial_delete()


func _on_soft_center() -> void:
	if _popup.visible:
		if %DialogOk.visible:
			_close_popup()
		return
	match _screen_id:
		"home":
			_open(_show_menu)
		"photo":
			_step_photo(1)
		"dial":
			_place_call()
		_:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is BaseButton and focused in _items:
				(focused as BaseButton).pressed.emit()


# ---------------------------------------------------------------- navigation

## Go to a new screen and remember where we came from.
func _open(screen: Callable) -> void:
	if _current.is_valid():
		_history.append({"show": _current, "focus": _focus_index(), "id": _screen_id})
	_current = screen
	screen.call(0)


## Swap the current screen without adding a step to "back" (tabs, next photo).
func _replace(screen: Callable, focus := 0) -> void:
	_current = screen
	screen.call(focus)


func _back() -> void:
	if _popup.visible:
		_close_popup()
		return
	if _history.is_empty():
		return
	var last: Dictionary = _history.pop_back()
	_current = last.show
	_current.call(last.focus)


func _go_home() -> void:
	_history.clear()
	_current = _show_home
	_show_home(0)


func _focus_index() -> int:
	return maxi(_items.find(get_viewport().gui_get_focus_owner()), 0)


func _set_items(items: Array[Control], focus: int) -> void:
	_items = items
	_focus_item(focus)


func _focus_item(index: int) -> void:
	get_viewport().gui_release_focus()
	if not _items.is_empty():
		_items[clampi(index, 0, _items.size() - 1)].grab_focus()


# ---------------------------------------------------------------- boot splash

func _play_boot() -> void:
	_booting = true
	_splash.visible = true
	_splash.color = Color.BLACK
	_splash.modulate = Color.WHITE
	%SplashStar.visible = false
	%SplashName.visible_characters = 0
	%SplashTagline.modulate.a = 0.0
	%SplashBar.visible = false
	_set_boot_progress(0.0)

	var tw := create_tween()
	tw.tween_interval(0.4)                                    # screen still off
	tw.tween_callback(%BootSound.play)						#boot sound play
	tw.tween_callback(_splash.set.bind("color", BACKLIGHT))   # backlight flicks on...
	tw.tween_interval(0.06)
	tw.tween_callback(_splash.set.bind("color", Color.BLACK)) # ...and settles
	tw.tween_interval(0.3)
	tw.tween_callback(%SplashStar.show)
	for zoom: int in [1, 2, 3]:                               # logo pops in 1x, 2x, 3x
		tw.tween_callback(%SplashStar.set.bind("custom_minimum_size", _scaled(icon_boot_logo, zoom)))
		tw.tween_interval(0.07)
	var letters: int = %SplashName.text.length()
	tw.tween_property(%SplashName, "visible_characters", letters, 0.08 * letters)
	tw.tween_property(%SplashTagline, "modulate:a", 1.0, 0.3)
	tw.tween_callback(%SplashBar.show)
	for i in 10:                                              # loading bar, chunk by chunk
		tw.tween_callback(_set_boot_progress.bind((i + 1) / 10.0))
		tw.tween_interval(randf_range(0.04, 0.16))
	tw.tween_interval(0.35)
	for alpha: float in [0.66, 0.33, 0.0]:                    # fade out in steps, like old screens
		tw.tween_callback(_splash.set.bind("modulate", Color(1, 1, 1, alpha)))
		tw.tween_interval(0.06)
	tw.tween_callback(_finish_boot)


func _set_boot_progress(amount: float) -> void:
	%SplashFill.size.x = roundf((%SplashBar.size.x - 4.0) * amount)


func _finish_boot() -> void:
	_booted = true
	_booting = false
	_splash.visible = false


# ---------------------------------------------------------------- home + menu

func _show_home(_focus: int) -> void:
	_screen_id = "home"
	_show_page(%Home, false)
	_set_softkeys("", "MENU", "")
	var nothing: Array[Control] = []
	_set_items(nothing, 0)

	# Old phones listed what you missed right on the idle screen.
	_clear(%Notices)
	var unread := _unread_count()
	if unread > 0:
		_add_notice(icon_envelope_new, "%d NEW MESSAGE%s" % [unread, "" if unread == 1 else "S"])
	var missed := _missed_count()
	if missed > 0:
		_add_notice(icon_call_missed, "%d MISSED CALL%s" % [missed, "" if missed == 1 else "S"])


func _add_notice(icon: Texture2D, text: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(picture)
	row.add_child(_label(text, 10))
	%Notices.add_child(row)


func _build_menu() -> void:
	var cell: Vector2 = (%MenuGrid.size / 3.0).floor()   # 3x3 cells fill the grid area
	for app: PhoneApp in apps:
		var button := Button.new()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.theme_type_variation = "PhoneItem"
		button.custom_minimum_size = cell
		button.focus_mode = Control.FOCUS_ALL

		var glow := Panel.new()
		glow.name = "Highlight"
		glow.theme_type_variation = "MenuHighlight"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.visible = false
		_fill(glow, 3, 2, 3, 2)
		button.add_child(glow)

		var center := CenterContainer.new()
		center.name = "Center"
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill(center)
		button.add_child(center)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = app.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.custom_minimum_size = _scaled(app.icon, 2)   # 16px PNG shown at 32px
		center.add_child(icon)

		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_on_menu_focus.bind(button, app, true))
		button.focus_exited.connect(_on_menu_focus.bind(button, app, false))
		button.pressed.connect(_open_app.bind(app), CONNECT_DEFERRED)
		%MenuGrid.add_child(button)
		_menu_buttons.append(button)


func _on_menu_focus(button: Control, app: PhoneApp, on: bool) -> void:
	button.get_node("Highlight").visible = on
	# The highlighted icon grows from 2x to 3x, like on the old menus.
	var icon: TextureRect = button.get_node("Center/Icon")
	icon.custom_minimum_size = _scaled(app.icon, 3 if on else 2)
	if on:
		_set_header(app.title, app.color)
		%SelectSound.play()


func _show_menu(focus: int) -> void:
	_screen_id = "menu"
	_show_page(%Menu, true)
	_set_softkeys("", "SELECT", "BACK")
	_set_items(_menu_buttons.duplicate(), focus)


func _open_app(app: PhoneApp) -> void:
	match app.opens:
		"calls":
			_open(_show_calls.bind("all"))
		"messages":
			_open(_show_messages)
		"contacts":
			_open(_show_contacts)
		"gallery":
			_open(_show_gallery)
		"dial":
			_dialed = ""
			_open(_show_dial)
		_:
			_show_crash(app)


# ---------------------------------------------------------------- messages

func _show_messages(focus: int) -> void:
	var threads: Array = _data.get("messages", [])
	var unread := _unread_count()
	_begin_app("messages", "messages", "Messages", "%d NEW" % unread if unread > 0 else "")
	_set_softkeys("", "OPEN", "BACK")
	for i in threads.size():
		var thread: Dictionary = threads[i]
		var days: Array = thread.get("days", [])
		var texts: Array = days[-1].get("messages", []) if not days.is_empty() else []
		var preview := str(texts[-1].get("text", "")) if not texts.is_empty() else ""
		var icon := icon_envelope_new if _is_unread(thread) else icon_envelope_read
		var row := _add_row(str(thread.get("from", "?")), preview, str(thread.get("time", "")), icon)
		row.pressed.connect(_open.bind(_show_thread.bind(i)), CONNECT_DEFERRED)
	if _items.is_empty():
		_add_note("No messages")
	_focus_item(focus)


func _show_thread(_focus: int, index: int) -> void:
	var thread: Dictionary = _data.get("messages", [])[index]
	var has_new := _is_unread(thread)   # check before the chat counts as read
	_read_threads[str(thread.get("from", ""))] = true
	_begin_app("messages", "thread", str(thread.get("from", "?")))
	_set_softkeys("", "", "BACK")
	for day: Dictionary in thread.get("days", []):
		var date_tag := _add_date(str(day.get("date", "")))
		for text: Dictionary in day.get("messages", []):
			if has_new and _start_at == null and text.get("new", false):
				_add_section("NEW MESSAGES")
				_start_at = date_tag   # open on the day the new messages begin
			_add_bubble(str(text.get("text", "")), bool(text.get("from_me", false)), str(text.get("time", "")))
	_stick_to_bottom = _start_at == null   # nothing new: open at the newest message


func _add_bubble(text: String, mine: bool, time: String) -> void:
	var side := MarginContainer.new()
	side.add_theme_constant_override("margin_left", 4)
	side.add_theme_constant_override("margin_right", 4)
	side.add_theme_constant_override("margin_top", 2)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	side.add_child(stack)

	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _flat(_accent if mine else BUBBLE, 4, 2, 3))
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	var words := _label(text, 12, _ink_on(_accent) if mine else TEXT)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Short texts get a small bubble, long ones wrap at 128px.
	var font := get_theme_font("font", "Label")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	words.custom_minimum_size.x = minf(ceilf(width) + 1.0, 128.0)
	bubble.add_child(words)
	stack.add_child(bubble)

	var stamp := _label(time, 10, TEXT_DIM)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT
	stack.add_child(stamp)
	_content.add_child(side)


## A small date tag in the middle of the chat, like "11/2/2001".
func _add_date(date: String) -> Control:
	var pad := _margin(0, 6, 0, 2)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _flat(SECTION, 4, 1, 2))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_child(_label(date, 10, TEXT_DIM))
	pad.add_child(tag)
	_content.add_child(pad)
	return pad


func _on_scroll_range_changed() -> void:
	if _start_at:
		_scroll.scroll_vertical = int(_start_at.position.y)
	elif _stick_to_bottom:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


# ---------------------------------------------------------------- call history

func _show_calls(focus: int, tab: String) -> void:
	_seen_missed_calls = true
	_begin_app("calls", "calls", "Call History")
	_set_softkeys("", "OPEN", "BACK")
	%Tabs.visible = true
	_scroll.offset_top = %Tabs.size.y
	_style_tab(%TabAll, tab == "all")
	_style_tab(%TabMissed, tab == "missed")

	var calls: Array = _data.get("calls", [])
	for i in calls.size():
		var call: Dictionary = calls[i]
		var kind := str(call.get("type", "incoming"))
		if tab == "missed" and kind != "missed":
			continue
		var row := _add_row(str(call.get("name", "?")), str(call.get("number", "")),
				str(call.get("time", "")), _call_icon(kind), MISSED if kind == "missed" else TEXT)
		row.pressed.connect(_open.bind(_show_call.bind(i)), CONNECT_DEFERRED)
	if _items.is_empty():
		_add_note("No missed calls" if tab == "missed" else "No calls yet")
	_focus_item(focus)


func _switch_calls_tab(tab: String) -> void:
	_replace(_show_calls.bind(tab))


func _style_tab(tab: Button, selected: bool) -> void:
	var box: StyleBox = _flat(_accent) if selected else StyleBoxEmpty.new()
	var ink := _ink_on(_accent) if selected else TEXT_DIM
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		tab.add_theme_stylebox_override(state, box)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		tab.add_theme_color_override(colour, ink)


func _show_call(_focus: int, index: int) -> void:
	var call: Dictionary = _data.get("calls", [])[index]
	var kind := str(call.get("type", "incoming"))
	_begin_app("calls", "call", str(call.get("name", "?")))
	_set_softkeys("", "", "BACK")
	_add_profile(str(call.get("name", "?")), str(call.get("number", "")))
	_add_field("CALL", kind.capitalize() + " call", MISSED if kind == "missed" else TEXT)
	_add_field("TIME", str(call.get("time", "")))


func _call_icon(kind: String) -> Texture2D:
	match kind:
		"missed":
			return icon_call_missed
		"outgoing":
			return icon_call_outgoing
	return icon_call_incoming


# ---------------------------------------------------------------- call (dial a number)

func _show_dial(focus: int) -> void:
	_begin_app("dial", "dial", "Call")
	_set_softkeys("", "CALL", "BACK")

	var pad := _margin(4, 4, 4, 2)
	_dial_display = _label("")
	_dial_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dial_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dial_display.custom_minimum_size.y = 26
	pad.add_child(_dial_display)
	_content.add_child(pad)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	_content.add_child(grid)
	for key: String in KEYPAD:
		var button := _add_key(grid, key, KEY_LETTERS.get(key, " "), 34)
		button.pressed.connect(_dial_press.bind(key))

	var bottom := _margin(0, 2, 0, 0)
	_content.add_child(bottom)
	var call_key := _add_key(bottom, "CALL", "", 18, LED_ON)
	call_key.pressed.connect(_place_call)

	_update_dial_display()
	_focus_item(focus)


## A keypad key you can highlight and press: a big character with small letters under it.
func _add_key(parent: Control, top: String, bottom: String, height: int, colour := TEXT) -> Button:
	var key := Button.new()
	key.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	key.theme_type_variation = "PhoneItem"
	key.focus_mode = Control.FOCUS_ALL
	key.custom_minimum_size.y = height
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var face := Panel.new()                # the key itself
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", _flat(SECTION, 0, 0, 3))
	_fill(face, 1, 1, 1, 1)
	key.add_child(face)

	var glow := Panel.new()                # coloured when highlighted
	glow.name = "Highlight"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _flat(_accent, 0, 0, 3))
	glow.visible = false
	_fill(glow, 1, 1, 1, 1)
	key.add_child(glow)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(stack)
	key.add_child(stack)
	var big := _label(top, 12, colour)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(big)
	if bottom != "":
		var small := _label(bottom, 10, TEXT_DIM)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(small)

	parent.add_child(key)
	_register_item(key)
	return key


## Shows the typed number (smaller when it gets long) and the CLEAR softkey.
func _update_dial_display() -> void:
	var empty := _dialed == ""
	var size := 10 if empty else 20
	var font := get_theme_font("font", "Label")
	if not empty and font.get_string_size(_dialed, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 166:
		size = 12
	_dial_display.text = "Enter number" if empty else _dialed
	_dial_display.add_theme_font_size_override("font_size", size)
	_dial_display.add_theme_color_override("font_color", TEXT_DIM if empty else TEXT)
	%SoftLeft.text = "" if empty else "CLEAR"


## Adds one key to the number.
func _dial_press(key: String) -> void:
	if _dialed.length() < MAX_DIGITS:
		_dialed += key
		%KeySound.default_pitch = KEY_LOWEST_PITCH + KEYPAD.find(key) * KEY_PITCH_STEP
		%KeySound.play()
	_update_dial_display()


## Rubs out the last key (CLEAR softkey or Backspace).
func _dial_delete() -> void:
	_dialed = _dialed.left(-1)
	_update_dial_display()


## The keypad key a keyboard key types ("0" to "9", "*", "#"), or "" for any other key.
func _typed_key(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and event.unicode > 0:
		var typed := char(event.unicode)
		if typed in KEYPAD:
			return typed
	return ""


func _place_call() -> void:
	if _dialed != "":
		_open(_show_calling.bind(_dialed))


## The calling screen. A wrong number rings, then says it is unavailable
## (the 3rd wrong number sets off the scare instead, once per game).
## A secret code from phone_data.json rings once, then plays its sound and/or sends its text.
func _show_calling(_focus: int, number: String) -> void:
	_begin_app("dial", "calling", "Call")
	_set_softkeys("", "", "END")
	var who := _contact_name(number)
	_add_profile(who if who != "" else number, number if who != "" else "")
	var pad := _margin(0, 8, 0, 0)
	_call_status = _label("Calling...", 12, TEXT_DIM)
	_call_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad.add_child(_call_status)
	_content.add_child(pad)

	var secret := _find_secret(number)
	_call_tween = create_tween()
	_call_tween.tween_callback(%RingSound.play)
	if secret.is_empty():
		_wrong_calls += 1
		if _wrong_calls >= SCARE_AFTER and not _scared:
			_call_tween.tween_interval(ONE_RING_TIME)
			_call_tween.tween_callback(_start_scare)
			return
		_call_tween.tween_interval(%RingSound.get_length())
		_call_tween.tween_callback(_set_call_status.bind("Number unavailable", MISSED))
		_call_tween.tween_callback(%UnavailableSound.play)
		_call_tween.tween_interval(%UnavailableSound.get_length())
	else:
		_call_tween.tween_interval(ONE_RING_TIME)
		_call_tween.tween_callback(%RingSound.stop)
		var sound := _load_sound(str(secret.get("sound", "")))
		if sound:   # someone picks up: the line is quiet for a moment, then the sound plays
			%CallerSound.audio_stream = sound
			_call_tween.tween_callback(_connect_call)
			_call_tween.tween_interval(float(secret.get("wait", 0.0)))
			_call_tween.tween_callback(%CallerSound.play)
			_call_tween.tween_interval(sound.get_length())
		if str(secret.get("text", "")) != "":
			_call_tween.tween_callback(_receive_sms.bind(secret))
	_call_tween.tween_callback(_set_call_status.bind("Call ended", TEXT_DIM))
	_call_tween.tween_interval(1.0)
	_call_tween.tween_callback(_back)


func _set_call_status(text: String, colour: Color) -> void:
	_call_connected_at = -1   # stops the call timer
	_call_status.text = text
	_call_status.add_theme_color_override("font_color", colour)


## Someone picked up: the status shows how long the call has lasted.
func _connect_call() -> void:
	_set_call_status("00:00", TEXT)
	_call_connected_at = Time.get_ticks_msec()


## Hangs up: stops the call sounds and whatever the call was about to do.
func _end_call() -> void:
	if _call_tween:
		_call_tween.kill()
		_call_tween = null
	_call_connected_at = -1
	%RingSound.stop()
	%UnavailableSound.stop()
	%CallerSound.stop()


## The sound a secret code plays on the call ("sound" in phone_data.json), or null.
func _load_sound(path: String) -> AudioStream:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		push_warning("Phone data: there is no sound file at " + path)
		return null
	return load(path) as AudioStream


## The secret in phone_data.json whose code was dialled, or {} for a wrong number.
func _find_secret(number: String) -> Dictionary:
	var dial: Dictionary = _data.get("dial", {})
	for secret: Dictionary in dial.get("secrets", []):
		var code := _to_keypad(str(secret.get("code", "")))
		if code != "" and code == number:
			return secret
	return {}


## Turns a word into the keys you press for it with multi-tap, like on old phones:
## "WOLF" -> "9666555333" (W=9, O=666, L=555, F=333).
## Digits, * and # stay as they are; spaces, + and - are dropped.
func _to_keypad(text: String) -> String:
	var keys := ""
	for letter in text.to_upper():
		if letter in KEYPAD:
			keys += letter
		else:
			for key: String in KEY_LETTERS:
				var index: int = KEY_LETTERS[key].find(letter)
				if index != -1:
					keys += key.repeat(index + 1)
					break
	return keys


## The contact saved with this number ("Dad"), or "" when nobody is.
## Works with or without the country code: 01117211827 finds +6011-1721-1827.
func _contact_name(number: String) -> String:
	var book: Dictionary = _data.get("contacts", {})
	for person: Dictionary in book.get("friends", []):
		var saved := _to_keypad(str(person.get("number", "")))
		if number.length() >= 7 and saved.ends_with(number):
			return str(person.get("name", ""))
	return ""


## The right code was dialled: its text arrives in Messages (only the first time).
func _receive_sms(secret: Dictionary) -> void:
	for sms: Dictionary in _sms_received:
		if sms.get("code") == secret.get("code"):
			return
	_sms_received.append(secret)
	_put_sms_in_inbox(secret)
	_read_threads.erase(str(secret.get("from", "")))   # that chat has something new again
	var tw := create_tween()
	tw.tween_interval(1.8)   # a moment after "Call ended", the phone beeps
	tw.tween_callback(_announce_sms.bind(secret))


## Puts a received text into Messages. Its chat moves to the top of the list.
func _put_sms_in_inbox(sms: Dictionary) -> void:
	var from := str(sms.get("from", "Unknown"))
	var time := str(sms.get("time", ""))
	var threads: Array = _data.get_or_add("messages", [])
	var thread := {"from": from, "days": []}
	for i in threads.size():
		if str(threads[i].get("from", "")) == from:
			thread = threads.pop_at(i)
			break
	threads.push_front(thread)
	thread["time"] = time
	var days: Array = thread.get_or_add("days", [])
	for day: Dictionary in days:   # older texts in this chat stop counting as new
		for text: Dictionary in day.get("messages", []):
			text.erase("new")
	var date := str(sms.get("date", ""))
	if days.is_empty() or str(days[-1].get("date", "")) != date:
		days.append({"date": date, "messages": []})
	days[-1].get_or_add("messages", []).append(
			{"from_me": false, "time": time, "text": str(sms.get("text", "")), "new": true})


## Beep, buzz and a "1 new message" popup.
func _announce_sms(secret: Dictionary) -> void:
	%SmsSound.play()
	if _popup.visible or _screen_id == "calling":
		return   # no popup now, the LED and the home screen still show it
	_open_popup("Messages", _app_color("messages"), icon_envelope_new,
			"1 new message\n" + str(secret.get("from", "")))
	%DialogOk.visible = true
	%DialogOk.grab_focus()
	_set_softkeys("", "OK", "")
	_buzz()


# ---------------------------------------------------------------- the "I SEE YOU" scare

## The 3rd wrong number: the whole phone goes black, red "I SEE YOU" fills it from top
## to bottom, everything glitches and a woman screams. Then it is all back to normal.
func _start_scare() -> void:
	_scared = true
	%RingSound.stop()
	_window_home = get_window().position
	_scare = ColorRect.new()                 # covers the whole phone and eats the clicks
	_scare.color = Color.BLACK
	_fill(_scare)
	add_child(_scare)
	_scare_noise = ColorRect.new()           # TV static that flashes now and then
	_scare_noise.material = _static_material
	_scare_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scare_noise.modulate.a = 0.5
	_scare_noise.visible = false
	_fill(_scare_noise)
	_scare.add_child(_scare_noise)
	_scare_lines.clear()

	var line_height := get_theme_font("font", "Label").get_height(20) + 2.0
	var lines := ceili(size.y / line_height)
	var tw := create_tween()
	tw.tween_interval(0.6)                   # a moment of black and silence...
	tw.tween_callback(_scream)               # ...then the scream
	for i in lines:                          # "I SEE YOU" fills the phone, top to bottom
		tw.tween_callback(_add_scare_line.bind(i * line_height))
		tw.tween_interval(0.07)
	tw.tween_interval(maxf(SCARE_TIME - lines * 0.07, 0.0))
	tw.tween_callback(_end_scare)


func _scream() -> void:
	%ScreamSound.play()
	_screaming = true


func _add_scare_line(y: float) -> void:
	var line := _label(SCARE_TEXT, 20, SCARE_RED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.position.y = y
	line.size.x = size.x
	line.add_theme_color_override("font_shadow_color", Color(0, 1, 1, 0.5))   # colour fringe
	_scare.add_child(line)
	_scare_lines.append(line)


## Every few frames: lines jump sideways, letters break, colours flip, static flashes
## and the phone window shakes.
func _glitch_scare(delta: float) -> void:
	_scare_tick -= delta
	if _scare_tick > 0.0:
		return
	_scare_tick = 0.05
	var flip := randf() < 0.1                # a frame of red screen with black words
	_scare.color = SCARE_RED if flip else Color.BLACK
	_scare_noise.visible = randf() < 0.15
	for line in _scare_lines:
		line.position.x = randi_range(-10, 10) if randf() < 0.35 else 0
		line.text = SCARE_GLITCHES.pick_random() if randf() < 0.2 else SCARE_TEXT
		line.visible = randf() > 0.05
		line.add_theme_color_override("font_color", Color.BLACK if flip else SCARE_RED)
		line.add_theme_constant_override("shadow_offset_x", randi_range(-3, 3))
	get_window().position = _window_home + Vector2i(randi_range(-6, 6), randi_range(-6, 6))


func _end_scare() -> void:
	_screaming = false
	%ScreamSound.stop()
	get_window().position = _window_home
	_scare.queue_free()
	_scare = null
	_scare_lines.clear()
	if _screen_id == "calling":
		_back()   # the call is over: back on the keypad as if nothing happened


# ---------------------------------------------------------------- contacts

func _show_contacts(focus: int) -> void:
	var book: Dictionary = _data.get("contacts", {})
	var me: Dictionary = book.get("me", {})
	var friends: Array = book.get("friends", [])
	_begin_app("contacts", "contacts", "Contacts")
	_set_softkeys("", "OPEN", "BACK")

	_add_section("MY PROFILE")
	var mine := _add_row(str(me.get("name", "Me")), str(me.get("number", "")), "", icon_contact)
	mine.pressed.connect(_open.bind(_show_contact.bind(-1)), CONNECT_DEFERRED)

	_add_section("FRIENDS (%d)" % friends.size())
	for i in friends.size():
		var friend: Dictionary = friends[i]
		var row := _add_row(str(friend.get("name", "?")), str(friend.get("number", "")), "", icon_contact)
		row.pressed.connect(_open.bind(_show_contact.bind(i)), CONNECT_DEFERRED)
	_focus_item(focus)


## index -1 = My Profile, 0+ = a friend.
func _show_contact(_focus: int, index: int) -> void:
	var book: Dictionary = _data.get("contacts", {})
	var person: Dictionary = book.get("me", {}) if index < 0 else book.get("friends", [])[index]
	var name_text := str(person.get("name", "?"))
	_begin_app("contacts", "contact", "My Profile" if index < 0 else name_text)
	_set_softkeys("", "", "BACK")
	_add_profile(name_text, str(person.get("number", "")))
	var note := str(person.get("note", ""))
	if note != "":
		_add_field("NOTE", note)


# ---------------------------------------------------------------- gallery

func _show_gallery(focus: int) -> void:
	var photos: Array = _data.get("gallery", [])
	_begin_app("gallery", "gallery", "Gallery")
	_set_softkeys("", "VIEW", "BACK")
	if photos.is_empty():
		_add_note("No photos")
		return

	var pad := _margin(3, 3, 3, 3)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	pad.add_child(grid)
	_content.add_child(pad)

	for i in photos.size():
		var tile := Button.new()
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.theme_type_variation = "PhoneItem"
		tile.focus_mode = Control.FOCUS_ALL
		tile.custom_minimum_size = Vector2(55, 55)
		var glow := Panel.new()                 # coloured frame when highlighted
		glow.name = "Highlight"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.add_theme_stylebox_override("panel", _flat(_accent))
		glow.visible = false
		_fill(glow)
		tile.add_child(glow)
		var picture := _make_photo(photos[i], Vector2i(51, 51))
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill(picture, 2, 2, 2, 2)
		tile.add_child(picture)
		grid.add_child(tile)
		_register_item(tile)
		tile.focus_entered.connect(_header_right.set.bind("text", "%d/%d" % [i + 1, photos.size()]))
		tile.pressed.connect(_open.bind(_show_photo.bind(i)), CONNECT_DEFERRED)
	_focus_item(focus)


func _show_photo(_focus: int, index: int) -> void:
	var photos: Array = _data.get("gallery", [])
	var photo: Dictionary = photos[index]
	_photo_index = index
	_begin_app("gallery", "photo", str(photo.get("title", "")), "%d/%d" % [index + 1, photos.size()])
	_set_softkeys("< PREV", "NEXT >", "BACK")
	# Going back lands on the photo you were last looking at.
	if not _history.is_empty() and _history[-1].id == "gallery":
		_history[-1].focus = index

	var pad := _margin(3, 3, 3, 0)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	pad.add_child(stack)
	var picture := _make_photo(photo, Vector2i(170, 128))
	picture.custom_minimum_size = Vector2(170, 128)
	stack.add_child(picture)
	stack.add_child(_label(str(photo.get("title", "")), 12))
	stack.add_child(_label(str(photo.get("date", "")), 10, TEXT_DIM))
	_content.add_child(pad)


func _step_photo(direction: int) -> void:
	var count: int = _data.get("gallery", []).size()
	if count > 1:
		_replace(_show_photo.bind(wrapi(_photo_index + direction, 0, count)))


## A photo at its real screen size, or TV static when the picture is missing.
func _make_photo(photo: Dictionary, box: Vector2i) -> Control:
	var texture := _photo_texture(str(photo.get("image", "")), box)
	if texture == null:
		var noise := ColorRect.new()
		noise.material = _static_material
		return noise
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.material = _lcd_material
	return picture


## Loads a picture, crops it to the box shape and shrinks it to the box's real
## pixel size, so it looks like it was taken with a 2002 camera phone.
func _photo_texture(path: String, box: Vector2i) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var key := "%s@%s" % [path, box]
	if _photo_cache.has(key):
		return _photo_cache[key]
	var source := load(path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	var want := float(box.x) / float(box.y)
	var crop := Rect2i(Vector2i.ZERO, image.get_size())
	if float(crop.size.x) / float(crop.size.y) > want:
		crop.size.x = int(crop.size.y * want)
		crop.position.x = int((image.get_width() - crop.size.x) * 0.5)
	else:
		crop.size.y = int(crop.size.x / want)
		crop.position.y = int((image.get_height() - crop.size.y) * 0.5)
	image = image.get_region(crop)
	image.resize(box.x, box.y, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	_photo_cache[key] = texture
	return texture


# ---------------------------------------------------------------- "App stopped working"

func _show_crash(app: PhoneApp) -> void:
	_open_popup(app.title, app.color, app.icon, "Loading")
	%DialogOk.visible = false
	_set_softkeys("", "", "")

	_popup_tween = create_tween()
	for dots: String in ["Loading.", "Loading..", "Loading..."]:
		_popup_tween.tween_interval(0.22)
		_popup_tween.tween_callback(%DialogText.set.bind("text", dots))
	_popup_tween.tween_interval(0.25)
	_popup_tween.tween_callback(_show_crash_message)


func _show_crash_message() -> void:
	%DialogIcon.texture = icon_warning
	%DialogIcon.custom_minimum_size = _scaled(icon_warning, 2)
	%DialogText.text = "App stopped working."
	%DialogOk.visible = true
	%DialogOk.grab_focus()
	_set_softkeys("", "OK", "")
	_buzz()
	%ErrorPopupSound.play()


## The little window in the middle of the screen, with a coloured title bar.
func _open_popup(title: String, colour: Color, icon: Texture2D, text: String) -> void:
	_popup_focus = _focus_index()
	_popup.visible = true
	_title_style.bg_color = colour
	%DialogTitle.text = title
	%DialogTitle.add_theme_color_override("font_color", _ink_on(colour))
	%DialogIcon.texture = icon
	%DialogIcon.custom_minimum_size = _scaled(icon, 2)
	%DialogText.text = text
	get_viewport().gui_release_focus()


## A quick shake of the popup, like the phone vibrating.
func _buzz() -> void:
	var holder: Control = %DialogHolder
	var start := holder.position.x
	var tw := create_tween()
	for shove: float in [2.0, -2.0, 2.0, -1.0, 1.0, 0.0]:
		tw.tween_callback(holder.set_indexed.bind(NodePath("position:x"), start + shove))
		tw.tween_interval(0.035)


func _close_popup() -> void:
	if _popup_tween:
		_popup_tween.kill()
	_popup.visible = false
	_current.call(_popup_focus)


# ---------------------------------------------------------------- building blocks

## app_screen = which app this page belongs to ("calls", "messages"...), for its colour.
func _begin_app(app_screen: String, screen_id: String, title: String, right := "") -> void:
	_screen_id = screen_id
	_accent = _app_color(app_screen)
	_show_page(%AppPage, true)
	_set_header(title, _accent, right)
	%Tabs.visible = false
	_scroll.offset_top = 0
	_scroll.scroll_vertical = 0
	_stick_to_bottom = false
	_start_at = null
	_clear(_content)
	_items = []


func _show_page(page: Control, with_header: bool) -> void:
	_end_call()
	for each: Control in [%Home, %Menu, %AppPage]:
		each.visible = each == page
	_header.visible = with_header
	%StatusTime.visible = page != %Home


func _set_header(title: String, colour: Color, right := "") -> void:
	_header_style.bg_color = colour
	var ink := _ink_on(colour)
	_header_title.text = title
	_header_title.add_theme_color_override("font_color", ink)
	_header_right.text = right
	_header_right.add_theme_color_override("font_color", ink)


func _set_softkeys(left: String, center: String, right: String) -> void:
	%SoftLeft.text = left
	%SoftCenter.text = center
	%SoftRight.text = right


## A list row you can highlight: icon, title, optional second line and right-hand text.
func _add_row(title: String, sub := "", right := "", icon: Texture2D = null, title_colour := TEXT) -> Button:
	var row := Button.new()
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.theme_type_variation = "PhoneItem"
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size.y = 24 if sub != "" else 15

	var glow := Panel.new()                # the coloured bar behind a highlighted row
	glow.name = "Highlight"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _flat(_accent))
	glow.visible = false
	_fill(glow)
	row.add_child(glow)

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 3)
	_fill(line, 3, 2, 3, 1)
	row.add_child(line)

	if icon:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		picture.custom_minimum_size = Vector2(icon.get_width(), 11)
		picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(picture)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(texts)
	var top := _label(title, 12, title_colour)
	top.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(top)
	if sub != "":
		var bottom := _label(sub, 10, TEXT_DIM)
		bottom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texts.add_child(bottom)

	if right != "":
		var side := _label(right, 10, TEXT_DIM)
		side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(side)

	_content.add_child(row)
	_register_item(row)
	return row


func _register_item(item: Control) -> void:
	item.mouse_entered.connect(item.grab_focus)
	item.focus_entered.connect(_on_item_focus.bind(item, true))
	item.focus_exited.connect(_on_item_focus.bind(item, false))
	_items.append(item)


func _on_item_focus(item: Control, on: bool) -> void:
	var glow := item.get_node_or_null("Highlight") as CanvasItem
	if glow:
		glow.visible = on
	if on:
		%SelectSound.play()
	var ink := _ink_on(_accent)
	for label: Label in item.find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", ink if on else label.get_meta("colour", TEXT))


func _add_section(text: String) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _flat(SECTION, 3, 1))
	bar.add_child(_label(text, 10, _accent))
	_content.add_child(bar)


func _add_note(text: String) -> void:
	var note := _label(text, 10, TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.custom_minimum_size.y = 40
	_content.add_child(note)


## Big avatar + name + number, for the top of a detail page.
func _add_profile(title: String, sub: String) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	stack.add_child(gap)
	var avatar := TextureRect.new()
	avatar.texture = icon_avatar
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = _scaled(icon_avatar, 3)
	stack.add_child(avatar)
	var name_label := _label(title, 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(name_label)
	if sub != "":
		var number := _label(sub, 10, TEXT_DIM)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(number)
	_content.add_child(stack)


## A small coloured title with a value under it (detail pages).
func _add_field(title: String, value: String, value_colour := TEXT) -> void:
	var pad := _margin(6, 5, 6, 0)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	stack.add_child(_label(title, 10, _accent))
	var text := _label(value, 12, value_colour)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(text)
	pad.add_child(stack)
	_content.add_child(pad)


func _label(text: String, font_size := 12, colour := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.set_meta("colour", colour)   # remembered so highlight can switch back
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", left)
	pad.add_theme_constant_override("margin_top", top)
	pad.add_theme_constant_override("margin_right", right)
	pad.add_theme_constant_override("margin_bottom", bottom)
	return pad


func _flat(colour: Color, margin_x := 0, margin_y := 0, radius := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false   # crisp pixel corners
	return box


## Stretch a control over its parent, pushed in by the given number of pixels.
func _fill(control: Control, left := 0, top := 0, right := 0, bottom := 0) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = -right
	control.offset_bottom = -bottom


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Dark text on light colours, white text on dark ones.
func _ink_on(colour: Color) -> Color:
	return TEXT_DARK if colour.get_luminance() > 0.55 else Color.WHITE


## Size of a texture blown up by a whole number (keeps pixel art sharp).
func _scaled(texture: Texture2D, zoom: int) -> Vector2:
	return texture.get_size() * zoom if texture else Vector2.ZERO


## Cuts frame `index` out of a sprite strip with `frames` equal frames side by side.
func _strip_frame(strip: Texture2D, frames: int, index: int) -> Texture2D:
	if strip == null:
		return null
	var frame := AtlasTexture.new()
	frame.atlas = strip
	var width := float(strip.get_width()) / frames
	frame.region = Rect2(width * clampi(index, 0, frames - 1), 0, width, strip.get_height())
	return frame


func _make_lcd_material(tv_static: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LCD_SHADER
	material.set_shader_parameter("show_static", tv_static)
	return material


# ---------------------------------------------------------------- data

func _load_data() -> Dictionary:
	var json := JSON.new()
	var error := json.parse(FileAccess.get_file_as_string(DATA_PATH))
	if error != OK:
		push_error("Phone data: %s line %d: %s" % [DATA_PATH, json.get_error_line(), json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


func _phone(key: String, fallback: Variant) -> Variant:
	var info: Dictionary = _data.get("phone", {})
	return info.get(key, fallback)


func _fill_phone_info() -> void:
	var time := str(_phone("time", "11:32"))
	var am_pm := str(_phone("ampm", "PM"))
	var parts := time.split(":")
	%ClockHours.text = parts[0]
	%ClockMinutes.text = parts[1] if parts.size() > 1 else "00"
	%ClockAmPm.text = am_pm
	%StatusTime.text = "%s %s" % [time, am_pm]
	%Date.text = str(_phone("date", ""))
	%Carrier.text = str(_phone("carrier", ""))
	var brand := str(_phone("brand", "NOVAKIA"))
	%Logo.text = brand
	%SplashName.text = brand
	%SplashTagline.text = str(_phone("boot_tagline", ""))
	%SplashStar.texture = icon_boot_logo
	%Signal.texture = _strip_frame(signal_strip, 5, int(_phone("signal", 3)))
	%Battery.texture = _strip_frame(battery_strip, 5, int(_phone("battery", 3)))


## Colour of the app that opens this screen (set in the Apps list).
func _app_color(app_screen: String) -> Color:
	for app: PhoneApp in apps:
		if app.opens == app_screen:
			return app.color
	return Color("#3270d6")


func _is_unread(thread: Dictionary) -> bool:
	return _new_count(thread) > 0


## How many messages in this chat are new: the one marked "new": true and every one after it.
## Once the chat has been opened, none of them are new any more.
func _new_count(thread: Dictionary) -> int:
	if _read_threads.has(str(thread.get("from", ""))):
		return 0
	var count := 0
	for day: Dictionary in thread.get("days", []):
		for text: Dictionary in day.get("messages", []):
			if count > 0 or text.get("new", false):
				count += 1
	return count


func _unread_count() -> int:
	var count := 0
	for thread: Dictionary in _data.get("messages", []):
		count += _new_count(thread)
	return count


func _missed_count() -> int:
	if _seen_missed_calls:
		return 0
	var count := 0
	for call: Dictionary in _data.get("calls", []):
		if str(call.get("type", "")) == "missed":
			count += 1
	return count

var _warm_index:= 0
 #it loads when the boot plays
func _warm_next_photo() -> void:
	var photos: Array = _data.get("gallery", [])
	if _warm_index < photos.size():
		_photo_texture(str(photos[_warm_index].get("image", "")), Vector2i(51,51))
		_warm_index+=1

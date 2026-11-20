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

# "static" = remembered for the whole game, even after the phone window closes.
static var _booted := false
static var _read_threads := {}          # sender name -> true once the thread was opened
static var _seen_missed_calls := false

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
var _popup_focus := 0
var _popup_tween: Tween
var _clock := 0.0
var _photo_cache := {}
var _lcd_material: ShaderMaterial
var _static_material: ShaderMaterial
var _header_style: StyleBoxFlat
var _title_style: StyleBoxFlat


func _ready() -> void:
	_data = _load_data()
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
	_clock += delta
	# The ":" in the clock blinks every half second.
	%ClockColon.modulate.a = 1.0 if fmod(_clock, 1.0) < 0.5 else 0.0
	# The little light above the screen flashes while something is unread.
	var something_new := _unread_count() + _missed_count() > 0
	%Led.color = LED_ON if something_new and fmod(_clock, 2.0) < 0.12 else LED_OFF


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# Q or Esc always puts the phone away, even while it boots.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit") or event.is_action_pressed("use_phone"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
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
		elif event.button_index == MOUSE_BUTTON_LEFT and _screen_id == "home" and not _popup.visible:
			_open(_show_menu)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
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
		var texts: Array = thread.get("messages", [])
		var preview := str(texts[-1].get("text", "")) if not texts.is_empty() else ""
		var icon := icon_envelope_new if _is_unread(thread) else icon_envelope_read
		var row := _add_row(str(thread.get("from", "?")), preview, str(thread.get("time", "")), icon)
		row.pressed.connect(_open.bind(_show_thread.bind(i)), CONNECT_DEFERRED)
	if _items.is_empty():
		_add_note("No messages")
	_focus_item(focus)


func _show_thread(_focus: int, index: int) -> void:
	var thread: Dictionary = _data.get("messages", [])[index]
	_read_threads[str(thread.get("from", ""))] = true
	_begin_app("messages", "thread", str(thread.get("from", "?")))
	_set_softkeys("", "", "BACK")
	for text: Dictionary in thread.get("messages", []):
		_add_bubble(str(text.get("text", "")), bool(text.get("from_me", false)), str(text.get("time", "")))
	_stick_to_bottom = true   # open at the newest message


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


func _on_scroll_range_changed() -> void:
	if _stick_to_bottom:
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
	_popup_focus = _focus_index()
	_popup.visible = true
	_title_style.bg_color = app.color
	%DialogTitle.text = app.title
	%DialogTitle.add_theme_color_override("font_color", _ink_on(app.color))
	%DialogIcon.texture = app.icon
	%DialogIcon.custom_minimum_size = _scaled(app.icon, 2)
	%DialogText.text = "Loading"
	%DialogOk.visible = false
	get_viewport().gui_release_focus()
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
	# A quick buzz, like the phone vibrating.
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
	_clear(_content)
	_items = []


func _show_page(page: Control, with_header: bool) -> void:
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
	return bool(thread.get("unread", false)) and not _read_threads.has(str(thread.get("from", "")))


func _unread_count() -> int:
	var count := 0
	for thread: Dictionary in _data.get("messages", []):
		if _is_unread(thread):
			count += 1
	return count


func _missed_count() -> int:
	if _seen_missed_calls:
		return 0
	var count := 0
	for call: Dictionary in _data.get("calls", []):
		if str(call.get("type", "")) == "missed":
			count += 1
	return count

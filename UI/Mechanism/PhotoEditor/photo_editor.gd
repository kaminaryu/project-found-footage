extends GameWindow
enum Filter { NORMAL, GRAYSCALE, NEGATIVE, SEPIA, BLUR } #normal is 0, grayscale is 1 and so on

const THUMBNAIL_SCENE: PackedScene = preload("res://UI/Mechanism/PhotoEditor/photo_thumbnail.tscn")
@export var photos: Array[PhotoEntry] = []

var thumbnail_group := ButtonGroup.new()
var current_entry: PhotoEntry
const MAX_ZOOM := 8.0 #The max zoom of the image
var zoom := 1.0 #1 means the whole photo
var pan := Vector2(0.5, 0.5) #the point of the photo is in the middle of the view

@onready var gallery_list: VBoxContainer = %LibraryList
@onready var photo: TextureRect = %Photo
@onready var caption: Label = %Caption
@onready var filter_material: ShaderMaterial = %Photo.material
@onready var filter_tabs: Array[Button] = [%NormalTab, %GrayscaleTab, %NegativeTab, %SepiaTab, %BlurTab]

func _window_ready() -> void:
	_init_thumbnails()
	_add_shitton_of_signals()


func _init_thumbnails() -> void :
	for entry in photos:
		if entry == null:
			continue
		var thumb: PhotoThumbnail = THUMBNAIL_SCENE.instantiate()

		thumb.button_group = thumbnail_group
		gallery_list.add_child(thumb) #this will add more thumbnail child in the gallery
		thumb.setup(entry)
		thumb.picked.connect(_on_photo_picked)



func _add_shitton_of_signals() -> void :
	%ExposureSlider.value_changed.connect(_on_slider_changed.bind("exposure"))
	%ContrastSlider.value_changed.connect(_on_slider_changed.bind("contrast"))
	%NoiseSlider.value_changed.connect(_on_slider_changed.bind("noise"))
	
	%NormalTab.pressed.connect(_on_filter_picked.bind(Filter.NORMAL))
	%GrayscaleTab.pressed.connect(_on_filter_picked.bind(Filter.GRAYSCALE))
	%NegativeTab.pressed.connect(_on_filter_picked.bind(Filter.NEGATIVE))
	%SepiaTab.pressed.connect(_on_filter_picked.bind(Filter.SEPIA))
	%BlurTab.pressed.connect(_on_filter_picked.bind(Filter.BLUR))
	%GuideButton.pressed.connect(_on_guide_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	photo.gui_input.connect(_on_photo_gui_input)



func set_selected_photo(index: int) -> void :
	var is_index_out_of_bounds := index > gallery_list.get_child_count() - 1
	if (is_index_out_of_bounds) :
		return

	var selected_thumb: PhotoThumbnail = gallery_list.get_child(index)

	selected_thumb.button_pressed = true
	if current_entry == null:
		_on_photo_picked(selected_thumb.entry)



func _on_photo_picked(entry: PhotoEntry) -> void:
	current_entry = entry
	photo.texture = entry.image
	caption.text = entry.caption
	_reset_zoom()
	_show_edits()

#slider and filter func
func _on_slider_changed(value: float, setting: String) -> void:
	filter_material.set_shader_parameter(setting, value)
	if current_entry:
		current_entry.set(setting, value)
		current_entry.emit_changed() #saved the change

func _on_filter_picked(filter: Filter) -> void:
	filter_material.set_shader_parameter("filter_mode", filter)
	if current_entry:
		current_entry.filter = filter
		current_entry.emit_changed() #saved the change

#guide
func _on_guide_pressed()-> void:
	%GuideDialog.popup_centered()

func _on_reset_pressed()-> void:
	if current_entry:
		current_entry.reset()
		_show_edits()

func _show_edits() -> void:
	%ExposureSlider.value = current_entry.exposure
	%ContrastSlider.value = current_entry.contrast
	%NoiseSlider.value = current_entry.noise
	filter_tabs[current_entry.filter].button_pressed = true
	filter_material.set_shader_parameter("filter_mode", current_entry.filter)
	current_entry.emit_changed() #saved the change


func _on_photo_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, zoom * 1.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, zoom / 1.25)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_reset_zoom()

	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pan -= event.relative / _photo_draw_rect().size / zoom
		_apply_zoom()


func _zoom_at(mouse_pos: Vector2, new_zoom: float) -> void:
	new_zoom = clampf(new_zoom, 1.0, MAX_ZOOM)
	var rect := _photo_draw_rect()
	var mouse_uv := (mouse_pos - rect.position) / rect.size   # where the mouse is on the picture 
	var spot := (mouse_uv - Vector2(0.5, 0.5)) / zoom + pan    # the bit of the photo under the mouse
	zoom = new_zoom
	pan = spot - (mouse_uv - Vector2(0.5, 0.5)) / zoom         
	_apply_zoom()


func _reset_zoom() -> void:
	zoom = 1.0
	pan = Vector2(0.5, 0.5)
	_apply_zoom()


func _apply_zoom() -> void:
	var half := 0.5 / zoom                                     # half of the visible part
	pan = pan.clamp(Vector2(half, half), Vector2(1.0 - half, 1.0 - half))
	filter_material.set_shader_parameter("zoom", zoom)
	filter_material.set_shader_parameter("pan", pan)



func _photo_draw_rect() -> Rect2:
	if photo.texture == null:
		return Rect2(Vector2.ZERO, photo.size)
	var tex_size := photo.texture.get_size()
	var fit := minf(photo.size.x / tex_size.x, photo.size.y / tex_size.y)
	var drawn := tex_size * fit
	return Rect2((photo.size - drawn) / 2.0, drawn)

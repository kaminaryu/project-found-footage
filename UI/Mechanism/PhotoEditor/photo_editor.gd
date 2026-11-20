extends CanvasLayer
enum Filter { NORMAL, GRAYSCALE, NEGATIVE, SEPIA, BLUR } #normal is 0, grayscale is 1 and so on

const THUMBNAIL_SCENE: PackedScene = preload("res://UI/Mechanism/PhotoEditor/photo_thumbnail.tscn")
@export var photos: Array[PhotoEntry] = []

var thumbnail_group := ButtonGroup.new()

@onready var gallery_list: VBoxContainer = %LibraryList
@onready var photo: TextureRect = %Photo
@onready var caption: Label = %Caption
@onready var filter_material: ShaderMaterial = %Photo.material

func _ready() -> void:
	for entry in photos:
		if entry == null:
			continue
		var thumb: PhotoThumbnail = THUMBNAIL_SCENE.instantiate()
		thumb.button_group = thumbnail_group
		gallery_list.add_child(thumb) #this will add more thumbnail child in the gallery
		thumb.setup(entry)
		thumb.picked.connect(_on_photo_picked)
	if gallery_list.get_child_count() > 0:
		var first: PhotoThumbnail = gallery_list.get_child(0)
		first.button_pressed = true
	%ExposureSlider.value_changed.connect(_on_slider_changed.bind("exposure"))
	%ContrastSlider.value_changed.connect(_on_slider_changed.bind("contrast"))
	%NoiseSlider.value_changed.connect(_on_slider_changed.bind("noise"))
	
	%NormalTab.pressed.connect(_on_filter_picked.bind(Filter.NORMAL))
	%GrayscaleTab.pressed.connect(_on_filter_picked.bind(Filter.GRAYSCALE))
	%NegativeTab.pressed.connect(_on_filter_picked.bind(Filter.NEGATIVE))
	%SepiaTab.pressed.connect(_on_filter_picked.bind(Filter.SEPIA))
	%BlurTab.pressed.connect(_on_filter_picked.bind(Filter.BLUR))
	%GuideButton.pressed.connect(_on_guide_pressed)
	
func _on_photo_picked(entry: PhotoEntry) -> void:
	photo.texture = entry.image
	caption.text = entry.caption

#slider and filter func
func _on_slider_changed(value: float, setting: String) -> void:
	filter_material.set_shader_parameter(setting, value)

func _on_filter_picked(filter: Filter) -> void:
	filter_material.set_shader_parameter("filter_mode", filter)

#guide
func _on_guide_pressed()-> void:
	%GuideDialog.popup_centered()

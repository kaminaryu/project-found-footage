extends CharacterBody3D

#Some variable bla bla
@export var walk_speed: float = 3.0
@export var crouch_speed: float = 1.5
@export var crouch_transition: float = 10.0 #This is basically signifies how fast you go from crouch to uncrouch
@export var mouse_sensitivty: float = 0.002
@export var phone_window_scene: PackedScene

#Load this when the scene finish loading typa shiii
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Node3D = $CameraPivot
@onready var body: Node3D = $Body
@onready var interact_Ray: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/InteractRay
@onready var interact_label: Label = $CanvasLayer/InteractLabel
@onready var phone_hint: Label = $CanvasLayer/PhoneHint
@onready var held_phone: Node3D= $CameraPivot/SpringArm3D/Camera3D/HeldPhone
@onready var anim: AnimationPlayer = $AnimationPlayer

var inventory: Array[String] = []

#initial value for crouching
var is_crouching: bool = false
#value if the player is frozen and what the player is lookat
var is_frozen: bool = false
var looked_at: Node = null

#getting mouse input
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	held_phone.visible = false
	GameMaster.freezing_main_window.connect(_on_main_window_freezing)

func _unhandled_input(event: InputEvent) -> void:
	#if frozen , ignore
	if is_frozen:
		return
	#pressing Escape will free the mouse (for the pause menu)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		#shit will left and turn the whole player
		rotate_y(-event.screen_relative.x *mouse_sensitivty)
		#up and down will only tilt the camera and the body shouldn't do any effect
		camera.rotate_x(-event.screen_relative.y * mouse_sensitivty)
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

func _physics_process(delta:float)-> void:
		#if frozen, ignore
		if is_frozen:
			return
		#If nothing is under, the person will fall
		if not is_on_floor():
			velocity += get_gravity()*delta
		#Crouch while the key is held
		is_crouching = Input.is_action_pressed("crouch")
				
		#Basic movement control
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var speed: float = crouch_speed if is_crouching else walk_speed
		
		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)
		move_and_slide()
		update_crouch(delta)
		update_interaction()
		#if the phone is in the inventory, then the function plays
		if "phone" in inventory and Input.is_action_just_pressed("use_phone"):
			use_phone()

func update_crouch(delta:float)-> void:
	#eye height: 1.6 standing, 1.0 crouching 
	var target_eye: float = 1.0 if is_crouching else 1.6
	camera.position.y = lerpf(camera.position.y, target_eye, crouch_transition*delta)

#function for updating interactions tuf tuff
func update_interaction() -> void:
	var target: Node = null
	if interact_Ray.is_colliding():
		var hit := interact_Ray.get_collider() as Node
		if hit and hit.has_method("interact"):
			target = hit
	
	#if the player looking at something else, it will swap the glow
	if target != looked_at:
		if looked_at:
			looked_at.set_highlight(false)
		if target:
			target.set_highlight(true)
		looked_at = target
	
	#if the player press e while looking at it, it will INTERAAAAKKK
	if looked_at and Input.is_action_just_pressed("interact"):
		var thing := looked_at
		thing.set_highlight(false)
		looked_at = null
		thing.interact(self)




func _process(_delta: float) -> void:
	interact_label.visible = looked_at != null
	phone_hint.visible = "phone" in inventory and not is_frozen

func add_item(item:String) -> void:
	inventory.append(item)

#this is when the user use phone, the main game will freeze temporarily
func use_phone() -> void:
	GameMaster.freeze_main_window(true)
	held_phone.visible = true
	anim.play("open_phone")
	await anim.animation_finished
	
	var window := phone_window_scene.instantiate() as Window
	window.close_requested.connect(_on_phone_window_closed.bind(window))
	get_tree().root.add_child(window)
	
#when the phone window closed, it will unfreeze and play the animation backward
func _on_phone_window_closed(window: Window) -> void:
	window.hide()
	window.queue_free()
	anim.play_backwards("open_phone")
	await anim.animation_finished
	held_phone.visible = false
	GameMaster.freeze_main_window(false)


# Freeze signal listener
func _on_main_window_freezing(frozen: bool) -> void:
	is_frozen = frozen
	velocity = Vector3.ZERO
	if frozen:
		if looked_at:
			looked_at.set_highlight(false)
			looked_at = null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		get_window().grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

extends CharacterBody3D

#Some variable bla bla
@export var walk_speed: float = 3.0
@export var crouch_speed: float = 1.5
@export var crouch_transition: float = 10.0 #This is basically signifies how fast you go from crouch to uncrouch
@export var mouse_sensitivty: float = 0.002

#Load this when the scene finish loading typa shiii
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Node3D = $CameraPivot
@onready var body: Node3D = $Body

#initial value for crouching
var is_crouching: bool = false

#getting mouse input
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
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

func update_crouch(delta:float)-> void:
	#eye height: 1.6 standing, 1.0 crouching 
	var target_eye: float = 1.0 if is_crouching else 1.6
	camera.position.y = lerpf(camera.position.y, target_eye, crouch_transition*delta)

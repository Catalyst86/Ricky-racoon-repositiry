extends CharacterBody3D
## First-person walker. WASD + mouse look. Space to jump. Shift to sprint. Esc to release mouse.

@export var walk_speed: float = 3.6
@export var sprint_mult: float = 1.8
@export var jump_velocity: float = 4.6
@export var mouse_sensitivity: float = 0.0022
@export var air_accel: float = 8.0
@export var ground_accel: float = 30.0
@export var friction: float = 14.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

@onready var _head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		_yaw -= mm.relative.x * mouse_sensitivity
		_pitch -= mm.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -1.3, 1.3)
		rotation.y = _yaw
		if _head:
			_head.rotation.x = _pitch
	elif event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_vec := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_vec.y -= 1.0
	if Input.is_action_pressed("move_back"):
		input_vec.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vec.x += 1.0
	if input_vec.length_squared() > 0.0:
		input_vec = input_vec.normalized()

	var speed := walk_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_mult

	var wish_dir := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	var target_velocity := wish_dir * speed

	var accel: float = ground_accel if is_on_floor() else air_accel
	var t: float = clampf(accel * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target_velocity.x, t)
	velocity.z = lerpf(velocity.z, target_velocity.z, t)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.1)
		if Input.is_action_pressed("move_up"):
			velocity.y = jump_velocity

	move_and_slide()

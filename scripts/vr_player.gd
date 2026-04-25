extends XROrigin3D
## VR locomotion for the Ricky's Rants studio.
## - Left thumbstick: smooth move (relative to where you're looking)
## - Right thumbstick (left/right): snap turn
## - Trigger / grip: reserved for interactions you add later
##
## Designed for any OpenXR-compatible headset with two controllers (Quest, Index,
## Vive, WMR, etc.). Uses the standard OpenXR action map names.

@export var move_speed: float = 2.5
@export var sprint_mult: float = 2.0
@export var snap_turn_degrees: float = 30.0
@export var snap_cooldown_seconds: float = 0.35
@export var deadzone: float = 0.15

@onready var camera: XRCamera3D = $XRCamera3D
@onready var left_controller: XRController3D = $LeftController
@onready var right_controller: XRController3D = $RightController

var _snap_cooldown: float = 0.0


func _process(delta: float) -> void:
	_snap_cooldown = maxf(_snap_cooldown - delta, 0.0)

	# ---- Locomotion: left stick ----
	var move_axis: Vector2 = left_controller.get_vector2("primary")
	if move_axis.length() > deadzone:
		var cam_basis: Basis = camera.global_transform.basis
		var forward: Vector3 = -cam_basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0001:
			forward = forward.normalized()
		var right: Vector3 = cam_basis.x
		right.y = 0.0
		if right.length_squared() > 0.0001:
			right = right.normalized()
		var move_vec: Vector3 = right * move_axis.x + forward * move_axis.y
		var speed: float = move_speed
		# Sprint when grip is squeezed on either controller
		if left_controller.is_button_pressed("grip_click") or right_controller.is_button_pressed("grip_click"):
			speed *= sprint_mult
		global_position += move_vec * speed * delta

	# ---- Snap turn: right stick X ----
	var turn_axis: Vector2 = right_controller.get_vector2("primary")
	if absf(turn_axis.x) > 0.7 and _snap_cooldown <= 0.0:
		var dir: float = signf(turn_axis.x)
		# Pivot around the camera position (where the head is) so the world
		# rotates around the player, not around the play-space origin.
		var pivot: Vector3 = camera.global_position
		var angle: float = deg_to_rad(-snap_turn_degrees * dir)
		var offset: Vector3 = global_position - pivot
		offset = offset.rotated(Vector3.UP, angle)
		global_position = pivot + offset
		rotate_y(angle)
		_snap_cooldown = snap_cooldown_seconds

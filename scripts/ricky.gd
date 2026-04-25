extends CharacterBody3D
## Minimal Ricky controller with rigged walk animation.
## The rigged walk GLB (with baked walk cycle) is instanced as RickyMesh.
## At runtime we find its AnimationPlayer and play/pause the walk clip based on movement.
##
## API:
##   ricky.walk_to(Vector3(x, y, z))  # move toward target
##   ricky.stop()                      # cancel movement
##   ricky.is_walking()                # bool

@export var walk_speed: float = 1.8
@export var turn_speed: float = 6.0
@export var arrival_tolerance: float = 0.25

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _anim: AnimationPlayer = null
var _walk_clip: String = ""


func _ready() -> void:
	# Find the AnimationPlayer inside RickyMesh and pick the walk clip.
	_anim = _find_anim_player(self)
	if _anim:
		for n in _anim.get_animation_list():
			if "walk" in n.to_lower():
				_walk_clip = n
				break
		if _walk_clip == "" and _anim.get_animation_list().size() > 0:
			_walk_clip = _anim.get_animation_list()[0]
		if _walk_clip != "":
			_anim.play(_walk_clip)
			_anim.seek(0.0, true)
			_anim.pause()  # standing still until walk_to is called


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null


func walk_to(target: Vector3) -> void:
	_target = target
	_has_target = true
	if _anim and _walk_clip != "":
		if _anim.current_animation != _walk_clip:
			_anim.play(_walk_clip)
		elif not _anim.is_playing():
			_anim.play()


func stop() -> void:
	_has_target = false
	if _anim and _walk_clip != "":
		_anim.seek(0.0, true)
		_anim.pause()


func is_walking() -> bool:
	return _has_target


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.1)

	if _has_target:
		var diff := _target - global_position
		diff.y = 0.0
		var dist := diff.length()
		if dist < arrival_tolerance:
			stop()
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var dir := diff / dist
			var target_yaw := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
			velocity.x = dir.x * walk_speed
			velocity.z = dir.z * walk_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

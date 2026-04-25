extends Node
## Boots OpenXR if a headset is connected. When VR is active, switches the main
## viewport to render through the XRCamera3D and disables the flat-screen Player
## so it doesn't fight for camera control.
##
## Headset support: anything that exposes an OpenXR runtime — Meta Quest (Link
## or AirLink), Valve Index/Vive (SteamVR), Windows Mixed Reality, Pico, Varjo.
## Make sure your headset's OpenXR runtime is the active one (Steam: Settings →
## OpenXR → Set as active; Oculus: Devices → Set Oculus as active OpenXR runtime).

signal vr_ready
signal vr_unavailable(reason: String)

var xr_interface: XRInterface
var vr_active: bool = false


func _ready() -> void:
	# Godot auto-initializes OpenXR at engine start when `xr/openxr/enabled` is
	# true (set in project.godot). By the time this autoload runs, the interface
	# is either ready, or failed during boot.
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null or not xr_interface.is_initialized():
		print("[xr] OpenXR not initialized — running in flat-screen mode (no headset / runtime not active?)")
		vr_unavailable.emit("OpenXR interface missing or not initialized")
		return
	# VR is up. Route the viewport through the XRCamera and let the headset
	# drive frame timing instead of the desktop monitor's vsync.
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vr_active = true
	print("[xr] OpenXR active — VR enabled")
	# The flat-screen Player node lives in the main scene which loads after this
	# autoload. Defer the disable so we run after every node's _ready.
	call_deferred("_disable_flat_player")
	vr_ready.emit()


func _disable_flat_player() -> void:
	# If the flat-screen Player exists in the current scene, freeze it so its
	# camera and input handling don't compete with the VR rig.
	var root := get_tree().current_scene
	if root == null:
		return
	var player := root.get_node_or_null("Player")
	if player == null:
		return
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	# Stop the flat camera from being current
	for cam in player.find_children("*", "Camera3D", true, false):
		(cam as Camera3D).current = false
	# Release the mouse if the flat player captured it
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[xr] flat-screen Player disabled (VR rig will drive view)")

extends Node
## Simple Ricky director — sends him to a small patrol of spots behind the desk.
## Demonstrates how external code drives the ricky.walk_to() API.
## Edit WAYPOINTS or replace this script to script different scenes.

const WAYPOINTS: Array[Vector3] = [
	Vector3(-1.2, 0.35, -2.1),
	Vector3( 1.2, 0.35, -2.1),
	Vector3( 1.2, 0.35, -1.4),
	Vector3(-1.2, 0.35, -1.4),
]

@export var dwell_seconds: float = 2.5

var _index: int = 0
var _dwell: float = 0.0
var _ricky: Node = null


func _ready() -> void:
	_ricky = get_node_or_null("../Ricky")
	if _ricky:
		_send_next()


func _process(delta: float) -> void:
	if _ricky == null:
		return
	# If Ricky has stopped (reached the point), wait then send him to the next
	var walking: bool = _ricky.call("is_walking") if _ricky.has_method("is_walking") else false
	if not walking:
		_dwell += delta
		if _dwell >= dwell_seconds:
			_dwell = 0.0
			_send_next()


func _send_next() -> void:
	var target: Vector3 = WAYPOINTS[_index]
	_index = (_index + 1) % WAYPOINTS.size()
	if _ricky.has_method("walk_to"):
		_ricky.walk_to(target)

extends RefCounted
## Test rig: a FakeResolver, one recording listener, and the GDD's named fixtures.
## T tower, S slot, H hero, B burst button, Z its sink, A arc disc, K arc backdrop.

const FakeResolver := preload("res://tests/unit/input_gesture_resolver/helpers/fake_resolver.gd")
const Listener := preload("res://tests/unit/input_gesture_resolver/helpers/recording_listener.gd")

const T_POS: Vector2 = Vector2(270.0, 480.0)
const S_POS: Vector2 = Vector2(270.0, 600.0)
const H_POS: Vector2 = Vector2(100.0, 100.0)
const B_POS: Vector2 = Vector2(440.0, 880.0)
const A_POS: Vector2 = Vector2(270.0, 540.0)
const K_POS: Vector2 = Vector2(270.0, 480.0)
const GROUND: Vector2 = Vector2(500.0, 100.0)

var r: FakeResolver
var l: Listener
var t: int = -1
var s: int = -1
var h: int = -1
var b: int = -1
var z: int = -1
var a: int = -1
var k: int = -1


func _init(drag_slop: float = 15.0, tap_slop: float = 28.0, auto_connect: bool = true) -> void:
	r = FakeResolver.new(drag_slop, tap_slop)
	l = Listener.new()
	if auto_connect:
		connect_listener(l)


func connect_listener(lst: Listener) -> void:
	r.pressed.connect(lst.on_pressed)
	r.tapped.connect(lst.on_tapped)
	r.ground_tapped.connect(lst.on_ground_tapped)
	r.drag_started.connect(lst.on_drag_started)
	r.drag_moved.connect(lst.on_drag_moved)
	r.drag_ended.connect(lst.on_drag_ended)
	r.drag_cancelled.connect(lst.on_drag_cancelled)
	r.became_idle.connect(lst.on_became_idle)


func add_target(label: String, centre: Vector2, radius: float, accepts: InputResolver.Accepts,
		priority: int, sink: bool = false) -> int:
	var id: int = r.register(centre, radius, accepts, priority, sink)
	l.names[id] = label
	return id


func add_tower() -> int:
	t = add_target("T", T_POS, 36.0, InputResolver.Accepts.TAP, 200)
	return t


func add_slot() -> int:
	s = add_target("S", S_POS, 36.0, InputResolver.Accepts.TAP, 200)
	return s


func add_hero(centre: Vector2 = H_POS) -> int:
	h = add_target("H", centre, 36.0, InputResolver.Accepts.DRAG, 200)
	return h


func add_button() -> void:
	b = add_target("B", B_POS, 48.0, InputResolver.Accepts.DRAG, 100)
	z = add_target("Z", B_POS, 48.0, InputResolver.Accepts.TAP, 400, true)


func add_arc_disc() -> int:
	a = add_target("A", A_POS, 36.0, InputResolver.Accepts.TAP, 300)
	return a


func add_backdrop() -> int:
	k = add_target("K", K_POS, 1200.0, InputResolver.Accepts.TAP, 250, true)
	return k


## Press and release in place at a position, pointer 0.
func tap_at(p: Vector2) -> void:
	r.press(0, p)
	r.release(0, p)


func joined() -> String:
	return l.joined()

extends SceneTree
class Ent extends RefCounted:
	var ctx
class Ctx extends RefCounted:
	var ent: WeakRef
class Base extends RefCounted:
	func f() -> float:
		return 1.0
class Sub extends Base:
	var v := 5.0
	func f() -> float:
		return v
class Spy extends RefCounted:
	var causes: Array[String] = []
	func fatal(c: String) -> void:
		causes.append(c)
const T := {&"tower": {&"cost": TYPE_INT, &"damage": TYPE_FLOAT}}
func _init() -> void:
	for n in ["StatAccessor", "ReadContext", "StatKeys", "StatSpy"]:
		print(n, " class_exists=", ClassDB.class_exists(n))
	var e := Ent.new(); var c := Ctx.new(); e.ctx = c; c.ent = weakref(e)
	var w: WeakRef = weakref(e); var wc: WeakRef = weakref(c)
	e = null; c = null
	print("cycle freed (ent,ctx): ", w.get_ref() == null, " ", wc.get_ref() == null)
	var b: Base = Sub.new(); (b as Sub).v = 7.0
	print("override via base type: ", b.f())
	var s := Spy.new(); var cb: Callable = s.fatal; cb.call("x"); print("spy: ", s.causes)
	var k: StringName = &"cost"
	print("const dict, String key into StringName dict: ", T[&"tower"].get("cost", -1), " sn:", T[&"tower"].get(k, -1), " type int? ", T[&"tower"][k] == TYPE_INT)
	var t0 := Time.get_ticks_usec()
	var d := {&"a": 1.0, &"b": 2.0}; var acc := 0.0
	for i in 100000:
		acc += d[&"a"]
	print("100k dict reads usec (desktop debug): ", Time.get_ticks_usec() - t0)
	quit()

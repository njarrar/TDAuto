extends SceneTree
# R2: do draw_primitive (3/4 points), draw_multiline and mixed rect+line+primitive batch? Mobile renderer, windowed.
class Probe extends Node2D:
	var mode := 0
	func _draw() -> void:
		var tri := PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(4, 8)])
		var quad := PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)])
		var cols := PackedColorArray([Color.RED, Color.RED, Color.RED, Color.RED])
		match mode:
			1:
				for i in 48: draw_primitive(tri, cols, PackedVector2Array())
			2:
				for i in 48:
					draw_set_transform(Vector2(i * 10, 0))
					draw_primitive(quad, cols, PackedVector2Array())
			3:
				var pts := PackedVector2Array()
				for i in 48: pts.append_array([Vector2(i * 10, 0), Vector2(i * 10 + 8, 8)])
				draw_multiline(pts, Color.RED, 2.0, false)
			4:
				for i in 48: draw_rect(Rect2(i * 10, 0, 8, 8), Color.RED)
				for i in 48: draw_line(Vector2(i * 10, 0), Vector2(i * 10 + 8, 8), Color.GREEN, 2.0, false)
				for i in 48: draw_primitive(tri, cols, PackedVector2Array())
			5:
				for i in 48: draw_line(Vector2(i * 10, 0), Vector2(i * 10 + 8, 8), Color.RED, 2.0, true)
			6:
				for i in 48: draw_circle(Vector2(i * 10, 50), 4.0, Color.RED, true)
var p: Probe
var frame := 0
func _init() -> void:
	p = Probe.new()
	root.add_child(p)
func _process(_d: float) -> bool:
	frame += 1
	if frame % 4 == 0:
		print("R2 mode=", p.mode, " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		p.mode += 1
		p.queue_redraw()
		if p.mode > 6:
			quit()
	return false

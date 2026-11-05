extends SceneTree
# R1: windowed draw-call count per primitive mix, Mobile renderer, desktop. Scenes drawn one after the other.
class Probe extends Node2D:
	var mode := 0
	func _draw() -> void:
		var tri := PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(4, 8)])
		match mode:
			1: draw_colored_polygon(tri, Color.RED)
			2:
				for i in 48: draw_colored_polygon(tri, Color.RED)
			3:
				for i in 48:
					draw_set_transform(Vector2(i * 10, 0))
					draw_colored_polygon(tri, Color(0.01 * i, 0.5, 0.5))
			4:
				for i in 48: draw_arc(Vector2(i * 10, 50), 6.0, 0.0, TAU, 16, Color.GREEN, 2.0, false)
			5:
				for i in 48: draw_colored_polygon(tri, Color.RED)
				for i in 48: draw_arc(Vector2(i * 10, 50), 6.0, 0.0, TAU, 16, Color.GREEN, 2.0, false)
			6: draw_string(ThemeDB.fallback_font, Vector2(10, 100), "123", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			7:
				for i in 48: draw_rect(Rect2(i * 10, 0, 8, 8), Color.RED)
			8:
				for i in 48: draw_line(Vector2(i * 10, 0), Vector2(i * 10 + 8, 8), Color.RED, 2.0, false)
var p: Probe
var frame := 0
func _init() -> void:
	p = Probe.new()
	root.add_child(p)
func _process(_d: float) -> bool:
	frame += 1
	if frame % 4 == 0:
		print("R1 mode=", p.mode, " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		p.mode += 1
		p.queue_redraw()
		if p.mode > 8:
			quit()
	return false

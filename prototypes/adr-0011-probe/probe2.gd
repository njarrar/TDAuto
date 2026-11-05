extends SceneTree
func _init() -> void:
	var a := PackedInt32Array([1, 2, 3])
	var b := PackedInt32Array([1, 2, 3])
	var c := PackedInt32Array([1, 2, 4])
	print("Q1 a==b ", a == b, " a==c ", a == c, " a!=c ", a != c)
	for m in ["draw_arc", "draw_polyline", "draw_circle", "draw_colored_polygon", "draw_string", "draw_multiline", "draw_set_transform"]:
		for d in ClassDB.class_get_method_list("CanvasItem", true):
			if d.name == m:
				var names := []
				for arg in d.args:
					names.append(arg.name)
				print("Q2 ", m, " args=", names)
	print("Q3 monitor TOTAL_DRAW_CALLS_IN_FRAME=", RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME, " Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME=", Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	quit()

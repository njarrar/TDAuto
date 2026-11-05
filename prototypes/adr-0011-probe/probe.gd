extends SceneTree
func _init() -> void:
	var ri = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("P1 draw_calls_in_frame headless = ", ri)
	var base := Color(0.4, 0.6, 0.8)
	var g := base.get_luminance()
	var desat := base.lerp(Color(g, g, g), 0.6)
	print("P2 lum=", g, " desat60=", desat, " darkened4=", desat.darkened(0.04), " lightened4=", base.lightened(0.04))
	print("P3 lerp(black,white,.25)=", Color.BLACK.lerp(Color.WHITE, 0.25))
	quit()

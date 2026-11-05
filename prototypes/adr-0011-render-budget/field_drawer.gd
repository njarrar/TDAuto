# PROTOTYPE - NOT FOR PRODUCTION. ADR-0011 V1 to V5.
extends Node2D
## One drawer node. kind picks what _draw paints. _draw reads only the
## RenderData buffers, as ADR-0011 Decision 2 says. draw_usec is the time
## the last _draw took on the CPU (command recording only).

const RenderData := preload("res://render_data.gd")

enum Kind { BACKDROP, TOWERS, ENEMIES, COMBAT, HERO, HUD_FIELD, DISCS, ONE_DISC, FLASH_ONLY, PATH_POLYLINE, PATH_QUADS, LINE_TEST }

const FIELD := Color(0.10, 0.12, 0.20)
const KEYLINE := Color(0.02, 0.02, 0.05)
const ENEMY_COLORS: PackedColorArray = [Color(0.95, 0.45, 0.35), Color(0.9, 0.3, 0.3), Color(0.7, 0.2, 0.25)]
const TOWER_COLOR := Color(0.45, 0.8, 0.95)
const HERO_COLOR := Color(1.0, 0.93, 0.6)
const WHITE := Color(1, 1, 1)

var kind: Kind = Kind.BACKDROP
var data: RenderData
var disc_count: int = 0
var disc_index: int = 0
var draw_usec: int = 0


func _draw() -> void:
	var t0: int = Time.get_ticks_usec()
	match kind:
		Kind.BACKDROP:
			_draw_backdrop()
		Kind.TOWERS:
			_draw_towers()
		Kind.ENEMIES:
			_draw_enemies()
		Kind.COMBAT:
			_draw_combat()
		Kind.HERO:
			_draw_hero()
		Kind.HUD_FIELD:
			_draw_hud_field()
		Kind.DISCS:
			for i in disc_count:
				draw_circle(_disc_pos(i), 11.0, ENEMY_COLORS[i % 3])
		Kind.ONE_DISC:
			draw_circle(_disc_pos(disc_index), 11.0, ENEMY_COLORS[disc_index % 3])
		Kind.FLASH_ONLY:
			_draw_flashes()
		Kind.PATH_POLYLINE:
			_draw_path_polyline()
		Kind.PATH_QUADS:
			_draw_path_quads()
		Kind.LINE_TEST:
			_draw_line_test()
	draw_usec = Time.get_ticks_usec() - t0


func _w(stated: float) -> float:
	return maxf(stated + data.line_bias, 2.0)


func _aa() -> bool:
	return data.antialiased


func _disc_pos(i: int) -> Vector2:
	return Vector2(40.0 + float(i % 8) * 64.0, 120.0 + float(i / 8) * 70.0)


func _draw_backdrop() -> void:
	draw_rect(Rect2(0, 0, 540, 960), FIELD)
	draw_multiline(data.grid_lines, Color(1, 1, 1, 0.04), _w(1.0), _aa())
	_draw_path_quads()
	for s: Vector2 in RenderData.SLOTS:
		draw_rect(Rect2(s - Vector2(28, 28), Vector2(56, 56)), Color(1, 1, 1, 0.35), false, _w(2.0), _aa())
	for i in 3:
		var base: Vector2 = Vector2(270.0, 880.0 + 22.0 * float(i))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-18, -8), base + Vector2(0, 6), base + Vector2(18, -8), base + Vector2(0, 0)]), Color(1, 0.5, 0.4, 0.8))


func _draw_path_quads() -> void:
	_quads(data.path_edge, FIELD.lightened(0.10))
	_quads(data.path_body, FIELD.lightened(0.05))


func _quads(strip: PackedVector2Array, color: Color) -> void:
	var cols: PackedColorArray = [color, color, color, color]
	var uvs: PackedVector2Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for q in strip.size() / 4:
		var pts: PackedVector2Array = [strip[4 * q], strip[4 * q + 1], strip[4 * q + 2], strip[4 * q + 3]]
		draw_primitive(pts, cols, uvs)


func _path_points() -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in RenderData.PATH_POINTS.size() / 2:
		pts.append(Vector2(RenderData.PATH_POINTS[2 * i], RenderData.PATH_POINTS[2 * i + 1]))
	return pts


func _draw_path_polyline() -> void:
	var pts: PackedVector2Array = _path_points()
	draw_polyline(pts, FIELD.lightened(0.10), 72.0, _aa())
	draw_polyline(pts, FIELD.lightened(0.05), 68.0, _aa())


func _draw_towers() -> void:
	var first: Vector2 = RenderData.SLOTS[0]
	draw_arc(first, 150.0, 0.0, TAU, 64, Color(1, 1, 1, 0.3), _w(2.0), _aa())
	for i in RenderData.SLOTS.size():
		var c: Vector2 = RenderData.SLOTS[i]
		var poly: PackedVector2Array = _tower_poly(c, i % 3)
		draw_colored_polygon(poly, TOWER_COLOR)
		var inset: PackedVector2Array = _tower_poly(c, i % 3, 0.6)
		inset.append(inset[0])
		draw_polyline(inset, FIELD, _w(3.0), _aa())
		draw_arc(c, 34.0, -PI / 2.0, -PI / 2.0 + TAU * data.tower_cool[i], 32, WHITE, _w(2.0), _aa())


func _tower_poly(c: Vector2, role: int, scale_f: float = 1.0) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var sides: int = [3, 6, 4][role]
	var r: float = 28.0 * scale_f
	for k in sides:
		var a: float = -PI / 2.0 + TAU * float(k) / float(sides) + (PI / 4.0 if sides == 4 else 0.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_enemies() -> void:
	if data.tri_array:
		_draw_enemies_tri()
		return
	var n: int = data.enemy_pos.size()
	if data.interleaved:
		for i in n:
			var s: int = data.enemy_style[i]
			draw_circle(data.enemy_pos[i], RenderData.ENEMY_RADIUS[s] + 2.0, KEYLINE)
			draw_circle(data.enemy_pos[i], RenderData.ENEMY_RADIUS[s], ENEMY_COLORS[s])
		return
	for i in n:
		draw_circle(data.enemy_pos[i], RenderData.ENEMY_RADIUS[data.enemy_style[i]] + 2.0, KEYLINE)
	for pass_style in 3:
		for i in n:
			if data.enemy_style[i] == pass_style:
				draw_circle(data.enemy_pos[i], RenderData.ENEMY_RADIUS[pass_style], ENEMY_COLORS[pass_style])


## V2 branch: every keyline and body as one triangle array, one submit.
func _draw_enemies_tri() -> void:
	var pts: PackedVector2Array = []
	var cols: PackedColorArray = []
	var idx: PackedInt32Array = []
	var seg: int = 12
	for layer in 2:
		for i in data.enemy_pos.size():
			var s: int = data.enemy_style[i]
			var r: float = RenderData.ENEMY_RADIUS[s] + (2.0 if layer == 0 else 0.0)
			var col: Color = KEYLINE if layer == 0 else ENEMY_COLORS[s]
			var c0: int = pts.size()
			pts.append(data.enemy_pos[i])
			cols.append(col)
			for k in seg:
				var a: float = TAU * float(k) / float(seg)
				pts.append(data.enemy_pos[i] + Vector2(cos(a), sin(a)) * r)
				cols.append(col)
			for k in seg:
				idx.append(c0)
				idx.append(c0 + 1 + k)
				idx.append(c0 + 1 + (k + 1) % seg)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


func _draw_combat() -> void:
	for i in data.enemy_pos.size():
		if data.enemy_hp[i] < 0.6:
			draw_circle(data.enemy_pos[i], RenderData.ENEMY_RADIUS[data.enemy_style[i]] * 0.45, FIELD)
	if data.slow_lines.size() > 0:
		draw_multiline(data.slow_lines, Color(0.5, 0.8, 1.0, 0.7), _w(2.0), _aa())
	draw_multiline_colors(data.tracer_lines, data.tracer_colors, _w(2.0), _aa())
	draw_arc(data.enemy_pos[5], 40.0, 0.0, TAU, 48, WHITE, _w(2.0), _aa())
	draw_arc(data.enemy_pos[20], 40.0, 0.0, TAU, 48, WHITE, _w(2.0), _aa())
	if not data.flash_on_material:
		_draw_flashes()
	for i in data.death_pos.size():
		draw_circle(data.death_pos[i], 9.0, Color(1, 1, 1, data.death_alpha[i] * 0.5))


func _draw_flashes() -> void:
	for i in data.flash_pos.size():
		draw_circle(data.flash_pos[i], 13.0, Color(1, 1, 1, data.flash_alpha[i]))


func _draw_hero() -> void:
	var h: Vector2 = data.hero_pos
	var leash: PackedVector2Array = RenderData.dashed_circle(h, 90.0, 10.0, 8.0)
	var reach: PackedVector2Array = RenderData.dashed_circle(h, 140.0, 3.0, 13.0)
	var glow_rect: Rect2 = Rect2(h - Vector2(64, 64), Vector2(128, 128))
	var glow2: Rect2 = Rect2(h - Vector2(96, 96), Vector2(192, 192))
	if data.interleaved:
		draw_texture_rect(data.glow_tex, glow2, false)
		draw_multiline(leash, Color(1, 1, 1, 0.5), _w(2.0), _aa())
		draw_texture_rect(data.glow_tex, glow_rect, false)
		draw_multiline(reach, Color(1, 1, 1, 0.6), _w(2.0), _aa())
		draw_texture_rect(data.glow_tex, glow_rect, false, Color(1, 1, 1, 0.5))
		draw_arc(data.aim_pos, 40.0, 0.0, TAU, 48, Color(1, 1, 1, 0.7), _w(3.0), _aa())
	else:
		draw_multiline(leash, Color(1, 1, 1, 0.5), _w(2.0), _aa())
		draw_multiline(reach, Color(1, 1, 1, 0.6), _w(2.0), _aa())
		draw_arc(data.aim_pos, 40.0, 0.0, TAU, 48, Color(1, 1, 1, 0.7), _w(3.0), _aa())
		draw_texture_rect(data.glow_tex, glow2, false)
		draw_texture_rect(data.glow_tex, glow_rect, false)
	var kite: PackedVector2Array = [h + Vector2(0, -30), h + Vector2(14, -2), h + Vector2(0, 16), h + Vector2(-10, -4)]
	draw_colored_polygon(kite, HERO_COLOR)
	draw_arc(h, 110.0, 0.0, TAU, 64, Color(1, 0.9, 0.5, 0.8), _w(3.0), _aa())


func _draw_hud_field() -> void:
	var font: Font = ThemeDB.fallback_font
	var sizes: PackedInt32Array = RenderData.TEXT_SIZES
	if data.one_text_size:
		sizes = PackedInt32Array([24, 24, 24])
	var labels: PackedStringArray = ["Start", "Call +12", "x3"]
	var spots: PackedVector2Array = [Vector2(40, 930), Vector2(200, 930), Vector2(440, 930)]
	if data.interleaved:
		for i in 5:
			draw_circle(Vector2(150.0 + 60.0 * float(i), 780.0), 28.0, Color(0.2, 0.25, 0.35))
			draw_string(font, Vector2(140.0 + 60.0 * float(i), 790.0), str(40 + 10 * i), HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[i % 3], WHITE)
		draw_rect(Rect2(20, 890, 160, 56), Color(0.2, 0.25, 0.35))
		draw_string(font, spots[0], labels[0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[1], WHITE)
		draw_circle(Vector2(470, 860), 42.0, Color(0.9, 0.7, 0.3))
		draw_string(font, spots[2], labels[2], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[2], WHITE)
		draw_arc(data.hero_pos, 30.0, 0.0, TAU, 32, WHITE, _w(2.0), _aa())
		draw_string(font, spots[1], labels[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[0], WHITE)
		return
	for i in 5:
		draw_circle(Vector2(150.0 + 60.0 * float(i), 780.0), 28.0, Color(0.2, 0.25, 0.35))
	draw_rect(Rect2(20, 890, 160, 56), Color(0.2, 0.25, 0.35))
	draw_circle(Vector2(470, 860), 42.0, Color(0.9, 0.7, 0.3))
	draw_arc(data.hero_pos, 30.0, 0.0, TAU, 32, WHITE, _w(2.0), _aa())
	for i in 5:
		draw_string(font, Vector2(140.0 + 60.0 * float(i), 790.0), str(40 + 10 * i), HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[0], WHITE)
	draw_string(font, spots[1], labels[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[0], WHITE)
	draw_string(font, spots[0], labels[0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[1], WHITE)
	draw_string(font, spots[2], labels[2], HORIZONTAL_ALIGNMENT_LEFT, -1.0, sizes[2], WHITE)


## V4: columns are bias 0 AA off, bias 0 AA on, bias 1 AA off, bias 1 AA on.
## Rows: 2 px ring, 2 px dashed leash, 1 px slot outline, full arcs at
## 8, 16, 24 and 32 points (seam check, 2 px plus bias 1).
func _draw_line_test() -> void:
	draw_rect(Rect2(0, 0, 540, 960), FIELD)
	var font: Font = ThemeDB.fallback_font
	var biases: PackedFloat32Array = [0.0, 0.0, 1.0, 1.0]
	var aas: Array[bool] = [false, true, false, true]
	for col in 4:
		var x: float = 70.0 + 133.0 * float(col)
		var b: float = biases[col]
		var aa: bool = aas[col]
		draw_string(font, Vector2(x - 50.0, 90.0), "b%d %s" % [int(b), "AA" if aa else "noAA"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 21, WHITE)
		draw_arc(Vector2(x, 190.0), 50.0, 0.0, TAU, 64, WHITE, 2.0 + b, aa)
		draw_multiline(RenderData.dashed_circle(Vector2(x, 330.0), 50.0, 10.0, 8.0), WHITE, 2.0 + b, aa)
		draw_rect(Rect2(x - 28.0, 440.0, 56.0, 56.0), WHITE, false, 1.0 + b, aa)
	var counts: PackedInt32Array = [8, 16, 24, 32]
	for i in 4:
		var x2: float = 70.0 + 133.0 * float(i)
		draw_string(font, Vector2(x2 - 30.0, 590.0), "%d pts" % counts[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 21, WHITE)
		draw_arc(Vector2(x2, 680.0), 50.0, 0.0, TAU, counts[i], WHITE, 3.0, false)
		draw_arc(Vector2(x2, 820.0), 50.0, 0.0, TAU, counts[i], WHITE, 3.0, true)

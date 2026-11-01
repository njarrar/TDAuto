# PROTOTYPE - NOT FOR PRODUCTION
# Question: With the hero pinned to a lane and the burst aimed by the player, is TOWERS + HERO better than TOWERS ONLY and than a hero nobody touches?
# Date: 2026-11-01
extends Node2D

# Modes: 0 towers + hero, 1 towers only, 2 hero only, 3 towers + hero NEVER TOUCHED (the pet test).
# Hero verbs: drag from the hero to pin it to a lane; drag from the gold button to aim the burst
# (release on the button = burst at the pin). Tapping ground does nothing.
const PATH := [Vector2(270, -20), Vector2(270, 260), Vector2(110, 260), Vector2(110, 560), Vector2(430, 560), Vector2(430, 940)]
const SLOTS := [Vector2(190, 140), Vector2(350, 140), Vector2(200, 400), Vector2(340, 400), Vector2(270, 650), Vector2(350, 780)]
const SKILL_POS := Vector2(470, 880)
const DEFAULT_ANCHOR := Vector2(270, 800)
const TOWER_COST := 50
const UPGRADE_COST := 60
const TOWER_RANGE := 150.0
const TOWER_DMG := 12.0
const UPGRADE_DMG := 16.0
const TOWER_CD := 0.6
const HERO_SPEED := 240.0
const HERO_RANGE := 100.0
const LEASH := 90.0
const HERO_DMG := 6.0
const HERO_CD := 0.4
const SKILL_RADIUS := 150.0
const SKILL_DMG := 38.0
const SKILL_CD := 8.0
const KILL_GOLD := 8
const WAVES := [[8, 30.0, 60.0], [10, 40.0, 65.0], [12, 50.0, 70.0], [14, 70.0, 70.0], [16, 90.0, 75.0], [10, 250.0, 60.0]] # count, hp, speed
const MODE_NAMES := ["TOWERS + HERO", "TOWERS ONLY", "HERO ONLY", "TOWERS + HERO NEVER TOUCHED"]

var mode := 0
var enemies: Array = []
var towers: Array = []
var flashes: Array = []
var hero_pos := Vector2.ZERO
var anchor := Vector2.ZERO
var hero_cd := 0.0
var skill_cd := 0.0
var skill_fx := 0.0
var fx_pos := Vector2.ZERO
var gold := 0
var lives := 0
var wave := 0
var spawned := 0
var spawn_t := 0.0
var gap_t := 0.0
var state := 0 # 0 playing, 1 won, 2 lost
var dmg := {"tower": 0.0, "hero": 0.0, "skill": 0.0}
var casts := 0
var cast_hits := 0
var cast_3plus := 0
var drag := ""
var drag_pos := Vector2.ZERO
var seg_len: Array = []
var total_len := 0.0
var bot_pin_t := 0.0


func _ready() -> void:
	for i in PATH.size() - 1:
		var l: float = PATH[i].distance_to(PATH[i + 1])
		seg_len.append(l)
		total_len += l
	if OS.get_cmdline_user_args().has("--auto"):
		_run_bots()
		get_tree().quit()
	else:
		_start(0)


func _start(m: int) -> void:
	mode = m
	enemies.clear()
	towers.clear()
	flashes.clear()
	anchor = DEFAULT_ANCHOR
	hero_pos = DEFAULT_ANCHOR
	hero_cd = 0.0
	skill_cd = 0.0
	skill_fx = 0.0
	gold = 120
	lives = 10
	wave = 0
	spawned = 0
	spawn_t = 0.0
	gap_t = 2.0
	state = 0
	dmg = {"tower": 0.0, "hero": 0.0, "skill": 0.0}
	casts = 0
	cast_hits = 0
	cast_3plus = 0
	drag = ""
	bot_pin_t = 0.0


func _process(delta: float) -> void:
	_step(delta)
	queue_redraw()


func pos_at(d: float) -> Vector2:
	var left := d
	for i in seg_len.size():
		if left <= seg_len[i]:
			return PATH[i].lerp(PATH[i + 1], left / seg_len[i])
		left -= seg_len[i]
	return PATH[PATH.size() - 1]


func _hit(e: Dictionary, amount: float, src: String) -> void:
	var real: float = minf(amount, e.hp)
	e.hp -= amount
	dmg[src] += real


func _burst(at: Vector2) -> void:
	if skill_cd > 0.0 or mode == 1 or mode == 3:
		return
	skill_cd = SKILL_CD
	skill_fx = 0.25
	fx_pos = at
	var hits := 0
	for e in enemies:
		if pos_at(e.d).distance_to(at) <= SKILL_RADIUS:
			_hit(e, SKILL_DMG, "skill")
			hits += 1
	casts += 1
	cast_hits += hits
	if hits >= 3:
		cast_3plus += 1


func _step(dt: float) -> void:
	if state != 0:
		return
	skill_cd = maxf(0.0, skill_cd - dt)
	skill_fx -= dt
	for f in flashes:
		f.t -= dt
	flashes = flashes.filter(func(f): return f.t > 0.0)

	if wave < WAVES.size():
		var w: Array = WAVES[wave]
		if spawned < w[0]:
			spawn_t -= dt
			if spawn_t <= 0.0:
				enemies.append({"d": 0.0, "hp": w[1], "max": w[1], "speed": w[2]})
				spawned += 1
				spawn_t = 0.9
		elif enemies.is_empty():
			gap_t -= dt
			if gap_t <= 0.0:
				wave += 1
				spawned = 0
				gap_t = 3.0
	elif enemies.is_empty():
		state = 1

	for e in enemies:
		e.d += e.speed * dt
	var leaked := enemies.filter(func(e): return e.d >= total_len)
	lives -= leaked.size()
	enemies = enemies.filter(func(e): return e.d < total_len)
	if lives <= 0:
		state = 2
		return

	if mode != 2:
		for t in towers:
			t.cd -= dt
			if t.cd <= 0.0:
				var tp: Vector2 = SLOTS[t.slot]
				var best: Dictionary = {}
				for e in enemies:
					if pos_at(e.d).distance_to(tp) <= TOWER_RANGE and (best.is_empty() or e.d > best.d):
						best = e
				if not best.is_empty():
					_hit(best, UPGRADE_DMG if t.lvl > 1 else TOWER_DMG, "tower")
					flashes.append({"a": tp, "b": pos_at(best.d), "t": 0.08, "c": Color(0.2, 0.9, 0.9)})
					t.cd = TOWER_CD

	if mode != 1:
		# The hero holds its pin; it only steps toward an enemy that is inside the leash around the pin.
		var goal := anchor
		var gd := INF
		for e in enemies:
			var ep := pos_at(e.d)
			if ep.distance_to(anchor) <= LEASH and ep.distance_to(hero_pos) < gd:
				gd = ep.distance_to(hero_pos)
				goal = ep
		var to := goal - hero_pos
		if to.length() > 1.0:
			hero_pos += to.normalized() * minf(HERO_SPEED * dt, to.length())
		hero_cd -= dt
		if hero_cd <= 0.0:
			var near: Dictionary = {}
			var nd := HERO_RANGE
			for e in enemies:
				var dd := pos_at(e.d).distance_to(hero_pos)
				if dd <= nd:
					nd = dd
					near = e
			if not near.is_empty():
				_hit(near, HERO_DMG, "hero")
				flashes.append({"a": hero_pos, "b": pos_at(near.d), "t": 0.08, "c": Color(1.0, 0.85, 0.3)})
				hero_cd = HERO_CD

	var dead := enemies.filter(func(e): return e.hp <= 0.0)
	gold += dead.size() * KILL_GOLD
	enemies = enemies.filter(func(e): return e.hp > 0.0)


func _hero_input_on() -> bool:
	return mode == 0 or mode == 2


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press(ev.position)
		else:
			_release(ev.position)
	elif ev is InputEventMouseMotion and drag != "":
		drag_pos = ev.position
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_1: _start(0)
			KEY_2: _start(1)
			KEY_3: _start(2)
			KEY_4: _start(3)


# Press priority: mode strip > restart > hero / skill drags > slots. Ground does nothing.
func _press(p: Vector2) -> void:
	if p.y < 40.0:
		_start((mode + 1) % 4)
		return
	if state != 0:
		_start(mode)
		return
	if _hero_input_on() and p.distance_to(SKILL_POS) < 45.0:
		drag = "skill"
		drag_pos = p
		return
	if _hero_input_on() and p.distance_to(hero_pos) < 45.0:
		drag = "hero"
		drag_pos = p
		return
	if mode != 2:
		for i in SLOTS.size():
			if p.distance_to(SLOTS[i]) < 36.0:
				var found := -1
				for j in towers.size():
					if towers[j].slot == i:
						found = j
				if found < 0 and gold >= TOWER_COST:
					gold -= TOWER_COST
					towers.append({"slot": i, "cd": 0.0, "lvl": 1})
				elif found >= 0 and towers[found].lvl == 1 and gold >= UPGRADE_COST:
					gold -= UPGRADE_COST
					towers[found].lvl = 2
				return


func _release(p: Vector2) -> void:
	if drag == "hero" and p.y > 50.0:
		anchor = p
	elif drag == "skill":
		_burst(anchor if p.distance_to(SKILL_POS) < 45.0 else p)
	drag = ""


func _report() -> String:
	var total: float = dmg.tower + dmg.hero + dmg.skill
	var share: float = 0.0 if total <= 0.0 else (dmg.hero + dmg.skill) / total * 100.0
	return "towers %.0f | hero %.0f | skill %.0f | hero share %.0f%% | bursts %d (3+ hit: %d)" % [dmg.tower, dmg.hero, dmg.skill, share, casts, cast_3plus]


# Stand-in for a player's read of the board: the path point with the most enemies inside the leash.
func _densest() -> Dictionary:
	var best := Vector2.ZERO
	var count := 0
	var d := 0.0
	while d < total_len:
		var pt := pos_at(d)
		var c := 0
		for e in enemies:
			if pos_at(e.d).distance_to(pt) <= LEASH:
				c += 1
		if c >= count and c > 0:
			count = c
			best = pt
		d += 20.0
	return {"pt": best, "n": count}


func _bot(m: int, dt: float) -> void:
	if m != 2:
		if gold >= TOWER_COST and towers.size() < SLOTS.size():
			towers.append({"slot": towers.size(), "cd": 0.0, "lvl": 1})
			gold -= TOWER_COST
		elif towers.size() == SLOTS.size() and gold >= UPGRADE_COST:
			for t in towers:
				if t.lvl == 1:
					t.lvl = 2
					gold -= UPGRADE_COST
					break
	if (m == 0 or m == 2) and not enemies.is_empty():
		bot_pin_t -= dt
		var dn := _densest()
		if bot_pin_t <= 0.0 and dn.n > 0:
			anchor = dn.pt
			bot_pin_t = 1.5 # a person re-pins about this often
		if dn.n >= 3:
			_burst(dn.pt)


func _run_bots() -> void:
	for m in 4:
		_start(m)
		var t := 0.0
		while state == 0 and t < 900.0:
			_bot(m, 1.0 / 30.0)
			_step(1.0 / 30.0)
			t += 1.0 / 30.0
		print("BOT %s: %s, wave %d/%d, lives %d, %.0fs | %s" % [MODE_NAMES[m], ["TIMEOUT", "WON", "LOST"][state], wave, WAVES.size(), lives, t, _report()])


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 540, 960), Color(0.04, 0.05, 0.1))
	draw_polyline(PackedVector2Array(PATH), Color(0.14, 0.17, 0.26), 34.0)
	for i in SLOTS.size():
		draw_arc(SLOTS[i], 24.0, 0.0, TAU, 24, Color(0.25, 0.4, 0.5), 2.0)
	for t in towers:
		var c: Vector2 = SLOTS[t.slot]
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(20, 14), c + Vector2(-20, 14)]), Color(0.1, 0.8, 0.85))
		if t.lvl > 1:
			draw_arc(c, 28.0, 0.0, TAU, 24, Color(0.6, 1.0, 1.0), 3.0)
	for e in enemies:
		var k: float = e.hp / e.max
		draw_circle(pos_at(e.d), 11.0, Color(1.0, 0.45 + 0.3 * k, 0.1))
	for f in flashes:
		draw_line(f.a, f.b, f.c, 2.0)
	if mode != 1:
		draw_arc(anchor, LEASH, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.3), 2.0)
		draw_circle(anchor, 4.0, Color(1.0, 0.9, 0.4, 0.6))
		if skill_fx > 0.0:
			draw_arc(fx_pos, SKILL_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
		draw_circle(hero_pos, 22.0, Color(1.0, 0.9, 0.4, 0.25))
		draw_colored_polygon(PackedVector2Array([hero_pos + Vector2(0, -18), hero_pos + Vector2(14, -2), hero_pos + Vector2(8, 16), hero_pos + Vector2(-12, 10), hero_pos + Vector2(-16, -6)]), Color(1.0, 0.92, 0.5))
		var ready := skill_cd <= 0.0
		draw_circle(SKILL_POS, 40.0, Color(1.0, 0.92, 0.5, 0.9 if ready else 0.25))
		if not ready:
			draw_string(font, SKILL_POS + Vector2(-8, 6), "%d" % ceili(skill_cd), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		if drag == "hero":
			draw_line(hero_pos, drag_pos, Color(1.0, 0.9, 0.4, 0.6), 2.0)
			draw_arc(drag_pos, LEASH, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, 0.5), 2.0)
		elif drag == "skill":
			draw_line(SKILL_POS, drag_pos, Color(1, 1, 1, 0.5), 2.0)
			draw_arc(drag_pos, SKILL_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)
	var white := Color(0.85, 0.9, 1.0)
	draw_rect(Rect2(0, 0, 540, 40), Color(0.1, 0.12, 0.2))
	draw_string(font, Vector2(10, 27), "%s  (tap here to switch)" % MODE_NAMES[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
	draw_string(font, Vector2(10, 68), "wave %d/%d   gold %d   lives %d" % [mini(wave + 1, WAVES.size()), WAVES.size(), gold, lives], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, white)
	if state != 0:
		draw_rect(Rect2(20, 380, 500, 150), Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(40, 430), "YOU WON" if state == 1 else "YOU LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, white)
		draw_string(font, Vector2(40, 470), _report(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, white)
		draw_string(font, Vector2(40, 505), "tap to retry this mode", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)

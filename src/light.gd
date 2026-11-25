extends Node2D
## The dark. Light enters from the sky, from torches and from the digger's helmet lamp, and spreads
## tile to tile, losing 1 through air and 3 through rock. This node draws the darkness over the world.

const Art = preload("res://src/art.gd")
const Monster = preload("res://src/monster.gd")
const T := 16
const LM := 10                     # tiles of margin round the view, so light from off screen arrives
const LW := 40 + 2 + LM * 2
const LH := 23 + 2 + LM * 2

var g                              ## the game (main.gd)
var light := PackedByteArray()
var warm := PackedByteArray()      # torch and lamp light only: tints the dark warm
var opq := PackedByteArray()
var x0 := 0
var y0 := 0
var day := 1.0


func _init() -> void:
	light.resize(LW * LH)
	warm.resize(LW * LH)
	opq.resize(LW * LH)


## Recomputes the light round the camera. Call before queue_redraw.
func compute() -> void:
	var world = g.world
	var t: Dictionary = g.t
	day = g.daylight(g.time)
	var sky := roundi(t.nightLight + (15 - t.nightLight) * day)
	x0 = floori(g.cam.x / T) - LM
	y0 = floori(g.cam.y / T) - LM
	light.fill(0)
	warm.fill(0)
	var bl := []
	var bw := []
	for i in 16:
		bl.append([])
		bw.append([])
	var torch := int(t.torchLight)
	for ly in LH:
		for lx in LW:
			var tx := x0 + lx
			var ty := y0 + ly
			var i := ly * LW + lx
			var v: int = world.get_t(tx, ty)
			opq[i] = 1 if world.solid(v) else 0
			var l := 0
			if tx >= 0 and tx < world.WW and ty < world.top[tx]:
				l = sky
			if v == Art.TORCH:
				l = maxi(l, torch)
				warm[i] = torch
				bw[torch].append(i)
			if l > 0:
				light[i] = l
				bl[l].append(i)
	var lamp := int(t.playerLight)
	var px := floori((g.p.x + g.p.w / 2) / T) - x0
	var py := floori((g.p.y + 4) / T) - y0
	if lamp > 0 and px >= 0 and py >= 0 and px < LW and py < LH:
		var i := py * LW + px
		if lamp > light[i]:
			light[i] = lamp
			bl[lamp].append(i)
		if lamp > warm[i]:
			warm[i] = lamp
			bw[lamp].append(i)
	_spread(light, bl)
	_spread(warm, bw)


# Brightest first: each cell lights its four neighbours, so every cell is settled once.
func _spread(a: PackedByteArray, buckets: Array) -> void:
	for lv in range(15, 1, -1):
		var q: Array = buckets[lv]
		var k := 0
		while k < q.size():
			var i: int = q[k]
			k += 1
			if a[i] != lv:
				continue
			var lx := i % LW
			for n: int in [i - 1 if lx > 0 else -1, i + 1 if lx < LW - 1 else -1, i - LW, i + LW]:
				if n < 0 or n >= LW * LH:
					continue
				var v := lv - (3 if opq[n] == 1 else 1)
				if v > a[n]:
					a[n] = v
					buckets[v].append(n)


func _draw() -> void:
	var world = g.world
	var dark := Color(0.024, 0.031, 0.086)
	# two tiles wider than the view: this is redrawn a few times a second while the camera moves
	for ly in range(LM - 2, LH - LM + 2):
		for lx in range(LM - 2, LW - LM + 2):
			var tx := x0 + lx
			var ty := y0 + ly
			if tx < 0 or tx >= world.WW or ty < 0 or ty >= world.WH:
				continue
			var i := ly * LW + lx
			var v: int = world.tiles[ty * world.WW + tx]
			var r := Rect2(tx * T, ty * T, T, T)
			var open: bool = ty <= world.surf[tx] and ty < world.top[tx]
			if v == Art.AIR and open: # open sky: the sky's own colour is its light
				if warm[i] > 4 and day < 0.7:
					draw_rect(r, Color(1.0, 0.67, 0.31, (warm[i] - 4) * 0.014 * (1 - day)))
				continue
			var l := mini(15, light[i])
			if l < 15:
				if open and (v == Art.TRUNK or v == Art.LEAF or v == Art.BED):
					# night falls on a tree or the bed in its own shape, never as a square
					draw_texture_rect_region(g.atlas, r, Rect2(v * T, 0, T, T), Color(dark.r, dark.g, dark.b, 1.0 - l / 15.0))
				else:
					draw_rect(r, Color(dark.r, dark.g, dark.b, 1.0 - l / 15.0))
			if warm[i] > 2 and warm[i] >= l - 1:
				draw_rect(r, Color(1.0, 0.59, 0.24, warm[i] * 0.011))


## Drawn every frame over the dark: monster eyes, and ore glinting before the digger reaches it.
func draw_over(ci: CanvasItem) -> void:
	var world = g.world
	for m in g.monsters:
		var tex: Texture2D = g.spr[m.kind][m.frame][0]
		var ox := roundf(m.x + m.w / 2 - tex.get_width() / 2.0)
		var oy := roundf(m.y + m.h - tex.get_height() + 1)
		for e: Vector2i in Monster.KIND[m.kind].eyes[m.frame]:
			var ex := tex.get_width() - 2 - e.x if m.dir < 0 else e.x + 1
			ci.draw_rect(Rect2(ox + ex, oy + e.y + 1, 1, 1), Color.html("#d8ff5a"))
	var ptx := floori((g.p.x + 5) / T)
	var pty := floori((g.p.y + 7) / T)
	var gr := int(g.t.glintRange)
	for ty in range(pty - gr, pty + gr + 1):
		for tx in range(ptx - gr, ptx + gr + 1):
			var v: int = world.get_t(tx, ty)
			if v != Art.COPPER and v != Art.IRON:
				continue
			var beat := int(g.time * 4 + Art.hsh(tx, ty, 50) * 7) % 7
			if beat > 1:
				continue
			var x := tx * T + 3 + int(Art.hsh(tx, ty, 51) * 9)
			var y := ty * T + 3 + int(Art.hsh(tx, ty, 52) * 9)
			var c := Color.html("#ffc98a") if v == Art.COPPER else Color.html("#f4f8fc")
			ci.draw_rect(Rect2(x, y - 1 - beat, 1, 3 + beat * 2), c)
			ci.draw_rect(Rect2(x - 1 - beat, y, 3 + beat * 2, 1), c)

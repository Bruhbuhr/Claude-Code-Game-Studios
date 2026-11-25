extends Node2D
## The tile world: seeded generation, tile reads and writes, and bodies moving against tiles.
## Drawn by two TileMapLayers (a static backdrop and the live tiles); works without them for checks.

const Art = preload("res://src/art.gd")
const T := 16
const WW := 220
const WH := 80
## Per tile id: dig is a config key (seconds to break) or a number; tier is the pickaxe needed;
## chew is the config key for a gnawer's seconds; col is the colour of its bits.
const INFO := [
	{"n": "air"},
	{"n": "grass", "solid": true, "dig": "digDirt", "drop": "dirt", "chew": "chewDirt", "col": "#7a5233"},
	{"n": "dirt", "solid": true, "dig": "digDirt", "drop": "dirt", "chew": "chewDirt", "col": "#7a5233"},
	{"n": "stone", "solid": true, "dig": "digStone", "drop": "stone", "chew": "chewStone", "col": "#878e98"},
	{"n": "copper ore", "solid": true, "dig": "digOre", "drop": "copper", "chew": "chewStone", "col": "#f0a35a"},
	{"n": "deep rock", "solid": true, "dig": "digDeep", "tier": 1, "drop": "stone", "chew": "chewStone", "col": "#5b6170"},
	{"n": "iron ore", "solid": true, "dig": "digIron", "tier": 1, "drop": "iron", "chew": "chewStone", "col": "#e3ecf5"},
	{"n": "tree", "dig": "digWood", "drop": "wood", "col": "#8a6238"},
	{"n": "leaves", "dig": 0.12, "col": "#57a04b"},
	{"n": "wood wall", "solid": true, "dig": "digWood", "drop": "plank", "chew": "chewWood", "col": "#a8743f"},
	{"n": "door", "solid": true, "dig": "digWood", "drop": "door", "chew": "chewWood", "col": "#8a5a2e"},
	{"n": "torch", "dig": 0.1, "drop": "torch", "col": "#ffd27a"},
	{"n": "bed"},
	{"n": "bedrock", "solid": true},
]

var tiles := PackedByteArray()
var surf := PackedInt32Array()   ## the generated surface row of each column
var top := PackedInt32Array()    ## the first solid row of each column now: sky reaches down to it
var dmg := {}                    ## cracks: tile index -> how broken, 0 to 1
var sx: int = WW >> 1            ## the bed's column
var fg: TileMapLayer
var bg: TileMapLayer


## Builds the two tile layers from the atlas. Skip it and the world still works, undrawn.
func setup(atlas: Texture2D) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = atlas
	src.texture_region_size = Vector2i(T, T)
	for i in range(1, Art.TILE_COUNT):
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	bg = TileMapLayer.new()
	bg.tile_set = ts
	add_child(bg)
	fg = TileMapLayer.new()
	fg.tile_set = ts
	add_child(fg)


static func solid(t: int) -> bool:
	return INFO[t].has("solid")


## The tile at a cell. Outside the world is bedrock, except open sky above it.
func get_t(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WW or y >= WH:
		return Art.AIR if (y < 0 and x >= 0 and x < WW) else Art.BEDROCK
	return tiles[y * WW + x]


func _retop(x: int) -> void:
	var y := 0
	while y < WH and not solid(tiles[y * WW + x]):
		y += 1
	top[x] = y


## Sets a tile, clears its cracks and redraws it.
func set_t(x: int, y: int, t: int) -> void:
	if x < 0 or y < 0 or x >= WW or y >= WH:
		return
	tiles[y * WW + x] = t
	dmg.erase(y * WW + x)
	_retop(x)
	if fg:
		if t == Art.AIR:
			fg.erase_cell(Vector2i(x, y))
		else:
			fg.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))


## True when a placed block here would have something to hold on to.
func supported(tx: int, ty: int) -> bool:
	if ty > surf[clampi(tx, 0, WW - 1)]:
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := get_t(tx + d.x, ty + d.y)
		if n != Art.AIR and n != Art.LEAF and n != Art.TORCH:
			return true
	return false


## Makes a new world from the generator's current seed. t is the tuning dictionary.
func generate(rng: RandomNumberGenerator, t: Dictionary) -> void:
	tiles.resize(WW * WH)
	tiles.fill(Art.AIR)
	surf.resize(WW)
	top.resize(WW)
	dmg.clear()
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var h_at := func(x: int) -> int:
		return 24 + roundi(3.2 * sin(x * 0.05 + p1) + 2.2 * sin(x * 0.11 + p2) + 1.2 * sin(x * 0.23 + p3))
	for x in WW:
		var h: int = h_at.call(sx) if absi(x - sx) <= 5 else h_at.call(x)
		var dirt := 5 + rng.randi_range(0, 2)
		var deep := 52 + roundi(2.0 * sin(x * 0.09 + p2))
		surf[x] = h
		for y in WH:
			var v := Art.AIR
			if y >= WH - 2 or x == 0 or x == WW - 1:
				v = Art.BEDROCK if y >= h - 30 else Art.AIR
			elif y == h:
				v = Art.GRASS
			elif y > h and y < h + dirt:
				v = Art.DIRT
			elif y >= h + dirt and y < deep:
				v = Art.STONE
			elif y >= deep:
				v = Art.DEEP
			tiles[y * WW + x] = v
	for i in int(t.caves):
		var x := 2.0 + rng.randf() * (WW - 4)
		var from := surf[int(x)] + 8
		_worm(rng, x, from + rng.randf() * (WH - 6 - from), rng.randf() * TAU, 25 + int(rng.randf() * 60), false)
	for i in 5: # a few cave mouths that open onto the surface
		var x := 10.0 + rng.randf() * (WW - 20)
		var ang := PI / 2 + (rng.randf() - 0.5)
		var length := 30 + int(rng.randf() * 30)
		if absf(x - sx) > 14:
			_worm(rng, x, surf[int(x)], ang, length, true)
	_worm(rng, sx + 8, surf[sx] + 10, 0.4, 26, false) # the first cave, a short dig from the bed
	for i in int(t.copperVeins):
		_vein(rng, rng.randi_range(0, WW - 1), 28 + rng.randi_range(0, 25), 4 + rng.randi_range(0, 5), Art.STONE, Art.COPPER)
	for i in int(t.ironVeins):
		_vein(rng, rng.randi_range(0, WW - 1), 52 + rng.randi_range(0, 23), 4 + rng.randi_range(0, 5), Art.DEEP, Art.IRON)
	for d: Vector2i in [Vector2i(4, 6), Vector2i(5, 6), Vector2i(5, 7), Vector2i(4, 7), Vector2i(6, 7)]: # the first glint
		tiles[(surf[sx] + d.y) * WW + sx + d.x] = Art.COPPER
	var last_tree := -9
	for x in range(4, WW - 4):
		if absi(x - sx) <= 3:
			continue
		var roll := rng.randf()
		if x == sx - 5 or x == sx + 9 or (roll < t.treeChance and x - last_tree > 2):
			_tree(rng, x)
			last_tree = x
	tiles[(surf[sx] - 1) * WW + sx] = Art.BED
	for x in WW:
		_retop(x)
	if fg:
		fg.clear()
		bg.clear()
		for y in WH:
			for x in WW:
				var v := tiles[y * WW + x]
				if v != Art.AIR:
					fg.set_cell(Vector2i(x, y), 0, Vector2i(v, 0))
				if y > surf[x]:
					var back := Art.BG_DIRT if y < surf[x] + 8 else (Art.BG_STONE if y < 52 else Art.BG_DEEP)
					bg.set_cell(Vector2i(x, y), 0, Vector2i(back, 0))


func _carve(cx: float, cy: float, r: float, open: bool) -> void:
	for y in range(floori(cy - r), floori(cy + r) + 1):
		for x in range(floori(cx - r), floori(cx + r) + 1):
			if x < 1 or x >= WW - 1 or y < 1 or y >= WH - 2:
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) > r * r:
				continue
			if not open and y < surf[x] + 3: # the surface stays whole
				continue
			if absi(x - sx) < 8 and y < surf[x] + 4: # and so does the ground under the bed
				continue
			tiles[y * WW + x] = Art.AIR


func _worm(rng: RandomNumberGenerator, x: float, y: float, ang: float, length: int, open: bool) -> void:
	for i in length:
		_carve(x, y, 1.1 + rng.randf() * 1.2, open)
		ang += (rng.randf() - 0.5) * 0.9
		x += cos(ang)
		y += sin(ang) * 0.6
		if open and i > 8:
			open = false


func _vein(rng: RandomNumberGenerator, x: int, y: int, n: int, from: int, to: int) -> void:
	for i in n:
		if x > 0 and x < WW - 1 and y > 0 and y < WH - 2 and tiles[y * WW + x] == from:
			tiles[y * WW + x] = to
		if rng.randf() < 0.5:
			x += -1 if rng.randf() < 0.5 else 1
		else:
			y += -1 if rng.randf() < 0.5 else 1


func _tree(rng: RandomNumberGenerator, x: int) -> void:
	var h := surf[x]
	var ht := 4 + rng.randi_range(0, 2)
	if tiles[h * WW + x] != Art.GRASS:
		return
	for y in range(h - ht, h):
		tiles[y * WW + x] = Art.TRUNK
	for yy in range(-2, 2):
		for xx in range(-2, 3):
			var cx := x + xx
			var cy := h - ht + yy
			if absi(xx) + absi(yy) > 3 or cx < 1 or cx >= WW - 1 or cy < 1:
				continue
			if tiles[cy * WW + cx] == Art.AIR:
				tiles[cy * WW + cx] = Art.LEAF


## True when the box overlaps a solid tile. The digger walks through their own doors.
func box_hits(x: float, y: float, w: float, h: float, digger: bool) -> bool:
	for ty in range(floori(y / T), floori((y + h) / T) + 1):
		for tx in range(floori(x / T), floori((x + w) / T) + 1):
			var v := get_t(tx, ty)
			if solid(v) and not (digger and v == Art.DOOR):
				return true
	return false


## Moves a body (anything with x, y, w, h, vx, vy, on_ground, hit_x, hit_y) one step, stopping at tiles.
## A body already inside a tile is let through, so it can never be frozen in place.
func move_box(e, dt: float, digger: bool) -> void:
	e.on_ground = false
	e.hit_x = 0
	e.hit_y = 0
	e.vy = clampf(e.vy, -560.0, 560.0)
	var inside := box_hits(e.x, e.y, e.w, e.h, digger)
	var nx: float = e.x + e.vx * dt
	if box_hits(nx, e.y, e.w, e.h, digger):
		if not inside:
			nx = floorf((nx + e.w) / T) * T - e.w - 0.01 if e.vx > 0 else floorf(nx / T) * T + T + 0.01
			if box_hits(nx, e.y, e.w, e.h, digger):
				nx = e.x
		e.hit_x = signi(int(signf(e.vx)))
		e.vx = 0.0
	e.x = nx
	var ny: float = e.y + e.vy * dt
	if box_hits(e.x, ny, e.w, e.h, digger):
		if not box_hits(e.x, e.y, e.w, e.h, digger):
			var down: bool = e.vy > 0
			ny = floorf((ny + e.h) / T) * T - e.h - 0.01 if down else floorf(ny / T) * T + T + 0.01
			if box_hits(e.x, ny, e.w, e.h, digger):
				ny = e.y
			if down:
				e.on_ground = true
		e.hit_y = signi(int(signf(e.vy)))
		e.vy = 0.0
	e.y = ny

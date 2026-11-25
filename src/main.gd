extends Node2D
## Nightfall Hollow: the run. Owns the state of one world (time of day, the bag, monsters, pickups)
## and steps it at the physics rate. The world, the dark and the HUD are child nodes it builds.
## Tuning comes from assets/data/config.json; nothing here is a gameplay number.

const Art = preload("res://src/art.gd")
const World = preload("res://src/world.gd")
const Digger = preload("res://src/player.gd")
const Monster = preload("res://src/monster.gd")
const Light = preload("res://src/light.gd")
const Hud = preload("res://src/hud.gd")
const W := 640
const H := 360
const T := 16
const CONFIG := "res://assets/data/config.json"
## What each recipe costs (config keys) and gives: a stack of blocks, or a tool tier.
const RECIPES := [
	{"name": "Torch", "cost": {"wood": "torchWood"}, "give": "torch", "count": "torchYield"},
	{"name": "Wood wall", "cost": {"wood": "wallWood"}, "give": "plank", "count": "wallYield"},
	{"name": "Door", "cost": {"wood": "doorWood"}, "give": "door"},
	{"name": "Wood sword", "cost": {"wood": "swordWoodCost"}, "tool": "sword", "tier": 1},
	{"name": "Copper pickaxe", "cost": {"wood": "pickCopperWood", "copper": "pickCopperOre"}, "tool": "pick", "tier": 1},
	{"name": "Copper sword", "cost": {"wood": "swordCopperWood", "copper": "swordCopperOre"}, "tool": "sword", "tier": 2},
	{"name": "Iron sword", "cost": {"wood": "swordIronWood", "iron": "swordIronOre"}, "tool": "sword", "tier": 3},
]
const SLOTS := [
	{"id": "pick", "name": "Pickaxe"}, {"id": "sword", "name": "Sword"},
	{"id": "dirt", "name": "Dirt", "tile": 2}, {"id": "stone", "name": "Stone", "tile": 3},
	{"id": "plank", "name": "Wood wall", "tile": 9}, {"id": "door", "name": "Door", "tile": 10},
	{"id": "torch", "name": "Torch", "tile": 11},
]
const ITEM_TILE := {"dirt": 2, "stone": 3, "wood": 7, "copper": 4, "iron": 6, "plank": 9, "door": 10, "torch": 11}
const HINTS := ["Hold left mouse on the ground to dig", "Dig a tree trunk for wood", "Press E to craft torches and walls",
	"Keys 1-7 pick a slot. Right mouse places a block", "Ore glints below. Dig down and light the dark", ""]


# A node whose drawing is one of this script's functions.
class Painter extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


var t: Dictionary = {}             ## tuning values, from CONFIG
var rng := RandomNumberGenerator.new()
var spr: Dictionary = {}
var atlas: Texture2D
var world
var p
var light
var hud
var root: Node2D
var ents: Painter
var over: Painter
var sky: Painter

var scene := "title"               ## title, play, pause or results
var time := 0.0                    ## seconds into this run
var phase := "day"
var inv := {"dirt": 0, "stone": 0, "wood": 0, "copper": 0, "iron": 0, "plank": 0, "door": 0, "torch": 0}
var tools := {"pick": 0, "sword": 0}
var sel := 0
var craft_open := false
var tut := 0
var place_cool := 0.0
var bits_cool := 0.0
var warn_cool := 0.0
var monsters: Array = []
var items: Array = []
var parts: Array = []
var floats: Array = []
var pouches: Array = []
var spawn_t := 0.0
var deaths := 0
var dug := 0
var killed := 0
var gained := ""
var cam := Vector2.ZERO
var world_seed := 0
var hit := {}                      # keys pressed since the last step
var mouse_click := false
var lmb_wait := false               # true until the left button is released after a click on the UI
var tick := 0


func _ready() -> void:
	t = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	atlas = Art.atlas()
	spr = Art.sprites()
	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	sky = _painter(back, _draw_sky)
	root = Node2D.new()
	add_child(root)
	world = World.new()
	root.add_child(world)
	world.setup(atlas)
	ents = _painter(root, _draw_ents)
	light = Light.new()
	light.g = self
	root.add_child(light)
	over = _painter(root, light.draw_over)
	var front := CanvasLayer.new()
	add_child(front)
	hud = Hud.new()
	hud.g = self
	front.add_child(hud)
	reset()
	# Debug starts for screenshots: `-- play` skips the title, `-- time=130` jumps the clock.
	for a in OS.get_cmdline_user_args():
		if a == "play":
			scene = "play"
		elif a.begins_with("time="):
			time = float(a.trim_prefix("time="))
		elif a == "craft":
			craft_open = true
			inv.wood = 4


func _painter(parent: Node, fn: Callable) -> Painter:
	var n := Painter.new()
	n.fn = fn
	parent.add_child(n)
	return n


## Throws this world away and makes a fresh one. A `seed=N` argument after `--` fixes the world.
func reset() -> void:
	world_seed = int(Time.get_unix_time_from_system()) + deaths + dug
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			world_seed = int(a.trim_prefix("seed="))
	rng.seed = world_seed
	world.generate(rng, t)
	p = Digger.new()
	time = 0.0
	phase = "day"
	for k in inv:
		inv[k] = 0
	tools = {"pick": 0, "sword": 0}
	sel = 0
	craft_open = false
	tut = 0
	monsters.clear()
	items.clear()
	parts.clear()
	floats.clear()
	pouches.clear()
	deaths = 0
	dug = 0
	killed = 0
	gained = ""
	wake()
	cam = p.centre() - Vector2(W, H) / 2
	_clamp_cam()


## Puts the digger back at the bed, whole.
func wake() -> void:
	p.x = (world.sx + 1) * T + 3
	p.y = world.surf[world.sx + 1] * T - p.h - 0.01
	p.vx = 0.0
	p.vy = 0.0
	p.hp = t.playerHp
	p.safe = 2.0
	while world.box_hits(p.x, p.y, p.w, p.h, true): # a wall built beside the bed: wake on top of it
		p.y -= T


func _clamp_cam() -> void:
	cam.x = clampf(cam.x, 0, world.WW * T - W)
	cam.y = clampf(cam.y, -H / 2.0, world.WH * T - H)


# ---- Time of day ---------------------------------------------------------------------------

func cycle() -> float:
	return t.dayLength + t.duskLength + t.nightLength


## "day", "dusk" or "night" at a run time in seconds.
func phase_at(tm: float) -> String:
	var tc := fmod(tm, cycle())
	return "day" if tc < t.dayLength else ("dusk" if tc < t.dayLength + t.duskLength else "night")


## 1 in full day, 0 at night, sliding through dusk and dawn.
func daylight(tm: float) -> float:
	var tc := fmod(tm, cycle())
	if tc < t.dayLength:
		return tc / 8.0 if (tm >= cycle() and tc < 8.0) else 1.0
	if tc < t.dayLength + t.duskLength:
		return 1.0 - (tc - t.dayLength) / t.duskLength
	return 0.0


func night_number() -> int:
	return int(time / cycle()) + 1


# ---- Input -----------------------------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		hit[e.physical_keycode] = true
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			mouse_click = true
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and scene == "play":
			sel = (sel + 1) % SLOTS.size()
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and scene == "play":
			sel = (sel + SLOTS.size() - 1) % SLOTS.size()


func down(k: int) -> bool:
	return Input.is_physical_key_pressed(k)


func mouse() -> Vector2:
	return get_viewport().get_mouse_position()


## The tile the digger points at: the mouse, or with F and G the block ahead (S for below).
func cursor_tile() -> Vector2i:
	if down(KEY_F) or down(KEY_G):
		var c: Vector2 = p.centre()
		var ptx := floori(c.x / T)
		var pty := floori(c.y / T)
		return Vector2i(ptx, pty + 1) if (down(KEY_S) or down(KEY_DOWN)) else Vector2i(ptx + p.dir, pty)
	var m := mouse() + cam.round()
	return Vector2i(floori(m.x / T), floori(m.y / T))


# ---- The step ----------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	tick += 1
	match scene:
		"title":
			if hit.has(KEY_ENTER) or hit.has(KEY_SPACE) or mouse_click:
				lmb_wait = true # the click that starts the game never digs
				scene = "play"
		"play":
			if hit.has(KEY_P) or hit.has(KEY_ESCAPE):
				scene = "pause"
			else:
				_play(dt)
		"pause":
			if hit.has(KEY_P) or hit.has(KEY_ESCAPE):
				scene = "play"
			elif hit.has(KEY_R):
				reset()
				scene = "play"
		"results":
			if hit.has(KEY_ENTER):
				reset()
				scene = "play"
	hit.clear()
	mouse_click = false
	root.position = -cam.round()
	# the dark is the costly part: a few times a second is plenty, and at once when the camera jumps (a death, a new world)
	if tick % 4 == 0 or tick < 3 or absf(cam.x / T - Light.LM - light.x0) > 2.0 or absf(cam.y / T - Light.LM - light.y0) > 2.0:
		light.compute()
		light.queue_redraw()
	sky.queue_redraw()
	ents.queue_redraw()
	over.queue_redraw()
	hud.queue_redraw()


func _play(dt: float) -> void:
	var before := phase_at(time)
	var n_before := int(time / cycle())
	time += dt
	phase = phase_at(time)
	var n := int(time / cycle())
	if phase != before:
		if phase == "night":
			spawn_t = t.spawnFirst
		if phase == "day" and n > n_before:
			for m in monsters:
				m.burn = true
			if n >= int(t.nightsToWin):
				gained = "You held the hollow for %d night%s" % [n, "" if n == 1 else "s"]
				scene = "results"
				return

	# craft list and hotbar
	if hit.has(KEY_E):
		craft_open = not craft_open
	for i in 7:
		if hit.has(KEY_1 + i):
			if craft_open:
				craft(i)
			else:
				sel = i
	var clicked_craft := false
	if mouse_click and craft_open:
		var i: int = hud.craft_row_at(mouse())
		if i >= 0:
			craft(i)
			clicked_craft = true
			lmb_wait = true

	# moving
	var left := down(KEY_A) or down(KEY_LEFT)
	var right := down(KEY_D) or down(KEY_RIGHT)
	var jump := down(KEY_SPACE) or down(KEY_W) or down(KEY_UP)
	p.knock -= dt
	if p.knock <= 0:
		p.vx = (t.moveSpeed if right else 0.0) - (t.moveSpeed if left else 0.0)
		if p.vx != 0:
			p.dir = 1 if p.vx > 0 else -1
			p.walk += dt * 9
		else:
			p.walk = 0.0
	if jump and p.on_ground:
		p.vy = -t.jumpSpeed
	p.vy += t.gravity * dt
	world.move_box(p, dt, true)
	p.x = clampf(p.x, T + 1, (world.WW - 2) * T)
	p.safe -= dt
	p.swing -= dt
	p.cool -= dt
	place_cool -= dt
	warn_cool -= dt
	bits_cool -= dt

	# acting
	var cur := cursor_tile()
	var slot: Dictionary = SLOTS[sel]
	var keys := down(KEY_F) or down(KEY_G)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		lmb_wait = false
	var lmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not lmb_wait and not clicked_craft and not hud.over_craft(mouse())
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if (lmb or rmb) and not keys:
		p.dir = 1 if cur.x * T + 8 >= p.x + p.w / 2 else -1
	if lmb or down(KEY_F):
		var cp := Vector2(cur.x * T + 8, cur.y * T + 8)
		var aimed := false
		for m in monsters:
			if m.rect().grow(8).has_point(cp):
				aimed = true
		if slot.id == "sword" or aimed:
			if p.cool <= 0:
				var dmg: float = t.pickDamage
				if slot.id == "sword" and tools.sword > 0:
					dmg = [0, t.swordWood, t.swordCopper, t.swordIron][tools.sword]
				_hit_monsters(dmg)
				p.cool = t.swingTime
				p.swing = 0.15
				if slot.id == "sword" and tools.sword == 0 and warn_cool <= 0:
					say("No sword yet: press E to craft one", "#ff8a80")
					warn_cool = 2.0
		else:
			_dig(cur.x, cur.y, dt)
	if rmb or down(KEY_G):
		_place(cur.x, cur.y)

	# the night
	if phase == "night":
		spawn_t -= dt
		if spawn_t <= 0 and monsters.size() < int(t.monsterCap + t.monsterCapStep * n):
			_spawn(n + 1)
			spawn_t = maxf(t.spawnIntervalMin, t.spawnInterval - t.spawnIntervalStep * n)
	for m in monsters:
		m.update(self, dt)
	for m in monsters:
		if m.hp <= 0:
			spray(m.x + m.w / 2, m.y + m.h / 2, "#ffd27a" if m.burn else "#45246e", 14, 90.0)
			if not m.burn:
				killed += 1
	monsters = monsters.filter(func(m): return m.hp > 0)

	# pickups fly to the digger
	var pc: Vector2 = p.centre()
	for it in items:
		it.age += dt
		var d: Vector2 = pc - it.pos
		var dist := maxf(1.0, d.length())
		if it.age > 0.18 and dist < 110:
			it.pos += d / dist * (120 + it.age * 320) * dt
		if dist < 9 and it.age > 0.18:
			it.got = true
			inv[it.id] += 1
			if it.id == "wood" and tut == 1:
				tut = 2
			if it.id == "copper" and tut == 4:
				tut = 5
	items = items.filter(func(it): return not it.got)
	for po in pouches:
		if pc.distance_to(po.pos) < 14:
			po.got = true
			for k in po.inv:
				inv[k] += po.inv[k]
			say("Got your pouch back")
	pouches = pouches.filter(func(po): return not po.got)
	for q in parts:
		q.life -= dt
		q.vel.y += 500 * dt
		q.pos += q.vel * dt
	parts = parts.filter(func(q): return q.life > 0)
	for f in floats:
		f.life -= dt
	floats = floats.filter(func(f): return f.life > 0)

	# torchlight mends
	if p.hp < t.playerHp:
		var ptx := floori(pc.x / T)
		var pty := floori(pc.y / T)
		var r := int(t.regenRange)
		var near := false
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if world.get_t(ptx + x, pty + y) == Art.TORCH:
					near = true
		if near:
			p.hp = minf(t.playerHp, p.hp + t.regen * dt)
	# falling asleep the hard way
	if p.hp <= 0:
		var carried := false
		for k in inv:
			if inv[k] > 0:
				carried = true
		if carried:
			pouches.append({"pos": pc, "inv": inv.duplicate(), "got": false})
			for k in inv:
				inv[k] = 0
		deaths += 1
		wake()
		say("You wake at your bed. Your pouch lies where you fell." if carried else "You wake at your bed.", "#ff8a80")
	cam += (p.centre() - Vector2(W, H) / 2 - cam) * 0.15
	_clamp_cam()


# ---- Small things ------------------------------------------------------------------------------

## A few bits flying off a point, in a colour.
func spray(x: float, y: float, colour: String, n: int, speed: float = 70.0) -> void:
	if parts.size() > 400:
		return
	for i in n:
		parts.append({"pos": Vector2(x, y), "vel": Vector2((rng.randf() - 0.5) * speed * 2, -rng.randf() * speed - 20),
			"life": 0.3 + rng.randf() * 0.4, "col": Color.html(colour)})


## A message above the hotbar. The same one is never shown twice at once.
func say(s: String, colour: String = "#fff4b0") -> void:
	for f in floats:
		if f.s == s:
			f.life = 3.2
			return
	floats.append({"s": s, "col": Color.html(colour), "life": 3.2})
	if floats.size() > 3:
		floats.pop_front()


# ---- Digging, placing, crafting -----------------------------------------------------------------

func in_reach(tx: int, ty: int) -> bool:
	return Vector2(tx * T + 8, ty * T + 8).distance_to(p.centre()) <= t.reach * T


## Breaks a tile: bits fly, it drops what it is made of, and a tree comes down whole.
func break_tile(tx: int, ty: int, drops: bool = true) -> void:
	var v: int = world.get_t(tx, ty)
	if v == Art.AIR or v == Art.BED or v == Art.BEDROCK:
		return
	var info: Dictionary = world.INFO[v]
	world.set_t(tx, ty, Art.AIR)
	spray(tx * T + 8, ty * T + 8, info.col, 8)
	if drops and info.has("drop"):
		items.append({"pos": Vector2(tx * T + 8, ty * T + 8), "id": info.drop, "age": 0.0, "got": false})
	if v == Art.TRUNK:
		if world.get_t(tx, ty - 1) == Art.TRUNK:
			break_tile(tx, ty - 1, drops)
		else:
			for yy in range(-3, 2):
				for xx in range(-2, 3):
					if world.get_t(tx + xx, ty + yy) == Art.LEAF:
						world.set_t(tx + xx, ty + yy, Art.AIR)
						spray((tx + xx) * T + 8, (ty + yy) * T + 8, "#57a04b", 2)
	if world.get_t(tx, ty - 1) == Art.TORCH and not world.supported(tx, ty - 1):
		break_tile(tx, ty - 1, drops)


func _dig_time(v: int) -> float:
	var d = world.INFO[v].dig
	return t[d] if d is String else d


func _dig(tx: int, ty: int, dt: float) -> void:
	var v: int = world.get_t(tx, ty)
	if v == Art.AIR or not in_reach(tx, ty):
		return
	var info: Dictionary = world.INFO[v]
	if not info.has("dig") or info.get("tier", 0) > tools.pick:
		if warn_cool <= 0:
			say("Your bed: you wake here" if v == Art.BED else ("Bedrock: nothing breaks it" if v == Art.BEDROCK else "Needs a copper pickaxe"), "#ff8a80")
			warn_cool = 1.2
		return
	var power: float = t.pickPowerCopper if tools.pick >= 1 else 1.0
	var i: int = ty * world.WW + tx
	var d: float = world.dmg.get(i, 0.0) + dt * power / _dig_time(v)
	p.swing = 0.12
	if bits_cool <= 0:
		bits_cool = 0.14
		spray(tx * T + 8, ty * T + 8, info.col, 2, 50.0)
	if d >= 1:
		break_tile(tx, ty)
		dug += 1
		if tut < 1:
			tut = 1
	else:
		world.dmg[i] = d


## Whether the selected block may go in this cell: empty, in reach, held up, and on nobody.
func can_place(tx: int, ty: int, tile: int) -> bool:
	var v: int = world.get_t(tx, ty)
	if tx < 1 or tx >= world.WW - 1 or ty < 1 or ty >= world.WH - 2:
		return false
	if (v != Art.AIR and v != Art.LEAF) or not in_reach(tx, ty):
		return false
	var box := Rect2(tx * T, ty * T, T, T)
	if world.solid(tile):
		if tile != Art.DOOR and box.intersects(p.rect()):
			return false
		for m in monsters:
			if box.intersects(m.rect()):
				return false
	return world.supported(tx, ty)


func _place(tx: int, ty: int) -> void:
	var slot: Dictionary = SLOTS[sel]
	if not slot.has("tile") or inv[slot.id] <= 0 or place_cool > 0 or not can_place(tx, ty, slot.tile):
		return
	world.set_t(tx, ty, slot.tile)
	inv[slot.id] -= 1
	place_cool = 0.14
	if tut == 3:
		tut = 4


## What a recipe costs now: resource -> count.
func cost_of(r: Dictionary) -> Dictionary:
	var c := {}
	for k in r.cost:
		c[k] = int(t[r.cost[k]])
	return c


func owned(r: Dictionary) -> bool:
	return r.has("tool") and tools[r.tool] >= r.tier


func can_craft(r: Dictionary) -> bool:
	if owned(r):
		return false
	var c := cost_of(r)
	for k in c:
		if inv[k] < c[k]:
			return false
	return true


## Crafts recipe i if the bag covers it.
func craft(i: int) -> void:
	if i < 0 or i >= RECIPES.size():
		return
	var r: Dictionary = RECIPES[i]
	if not can_craft(r):
		return
	var c := cost_of(r)
	for k in c:
		inv[k] -= c[k]
	if r.has("tool"):
		tools[r.tool] = r.tier
	else:
		inv[r.give] += int(t[r.count]) if r.has("count") else 1
	say("Made: " + r.name)
	if tut < 3:
		tut = 3


# ---- Monsters -----------------------------------------------------------------------------------

## Which monsters a night draws from. One is picked at random per spawn, so a kind listed twice
## comes twice as often. night is 1 for the first night.
func night_pool(night: int) -> Array:
	# TODO(human): shape the three nights. This default adds one kind a night.
	return ["gnawer"] if night <= 1 else (["gnawer", "gnawer", "leaper"] if night == 2 else ["gnawer", "leaper", "flyer"])


func _spawn(night: int) -> void:
	var pool := night_pool(night)
	var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
	var k: Dictionary = Monster.KIND[kind]
	var side := -1 if rng.randf() < 0.5 else 1
	var x: float = p.x + side * (W / 2.0 + 30 + rng.randf() * 80)
	if x < 2 * T or x > (world.WW - 3) * T:
		side = -side
		x = p.x + side * (W / 2.0 + 30 + rng.randf() * 80)
	x = clampf(x, 2 * T, (world.WW - 3) * T)
	var tx := floori(x / T)
	var top := mini(world.top[tx], world.top[floori((x + k.w) / T)]) # the higher of the columns it stands across
	var m := Monster.new()
	m.kind = kind
	m.w = k.w
	m.h = k.h
	m.x = x
	m.y = (world.surf[tx] - 7) * T if kind == "flyer" else top * T - k.h - 1
	m.hp = t[kind + "Hp"]
	m.dir = -side
	m.rest = rng.randf()
	monsters.append(m)


## A gnawer's teeth on one tile for one step.
func chew(tx: int, ty: int, dt: float) -> void:
	var v: int = world.get_t(tx, ty)
	var info: Dictionary = world.INFO[v]
	if not info.has("chew"):
		return
	var i: int = ty * world.WW + tx
	var slow := 1.5 if (v == Art.DEEP or v == Art.IRON) else 1.0
	var d: float = world.dmg.get(i, 0.0) + dt / (t[info.chew] * slow)
	if rng.randf() < 0.15:
		spray(tx * T + 8, ty * T + 8, info.col, 1, 40.0)
	if d >= 1:
		break_tile(tx, ty)
	else:
		world.dmg[i] = d


## Takes health off the digger and throws them back.
func hurt_player(n: float, dir: int) -> void:
	p.hp -= n
	p.safe = t.invuln
	p.vx = dir * t.knockback
	p.vy = -160.0
	p.knock = 0.2
	spray(p.x + 5, p.y + 6, "#e5484d", 8)


func _hit_monsters(dmg: float) -> void:
	var c: Vector2 = p.centre()
	var box := Rect2(c.x if p.dir > 0 else c.x - t.swingRange, p.y - 12, t.swingRange, p.h + 24)
	for m in monsters:
		if box.intersects(m.rect()):
			m.hp -= dmg
			m.hurt = 0.25
			m.vx = p.dir * t.knockback
			m.vy = -120.0
			spray(m.x + m.w / 2, m.y + m.h / 2, "#7d4bb8", 6)


# ---- Drawing: the sky behind, and everything that moves --------------------------------------------

func _mix(a: Color, b: Color, k: float) -> Color:
	return a.lerp(b, k)


func _draw_sky(ci: CanvasItem) -> void:
	var f := daylight(time)
	var turn := 1.0 - absf(2 * f - 1) # strongest halfway through dusk and dawn
	var top := Color.html("#070a1c").lerp(Color.html("#6fb7e6"), f).lerp(Color.html("#3b3a6e"), turn * 0.8)
	var bot := Color.html("#141a3a").lerp(Color.html("#bfe3f2"), f).lerp(Color.html("#f2a65a"), turn * 0.9)
	for i in 9:
		ci.draw_rect(Rect2(0, i * 40, W, 40), top.lerp(bot, i / 8.0))
	if f < 0.6:
		for i in 70:
			if Art.hsh(i, int(time * 2), 40) < 0.12: # a twinkle
				continue
			ci.draw_rect(Rect2(floorf(Art.hsh(i, 1, 41) * W), floorf(Art.hsh(i, 2, 42) * H * 0.7), 1, 1), Color(0.9, 0.93, 1.0, (0.6 - f) * 1.5))
	var tc := fmod(time, cycle())
	var day_all: float = t.dayLength + t.duskLength
	if tc < day_all:
		var k := tc / day_all
		ci.draw_texture(spr.sun[0][0], Vector2(roundf(60 + k * (W - 120)), roundf(150 - sin(minf(1.0, 0.25 + k * 0.75) * PI) * 120)))
	else:
		var k: float = (tc - day_all) / t.nightLength
		ci.draw_texture(spr.moon[0][0], Vector2(roundf(60 + k * (W - 120)), roundf(150 - sin(k * PI) * 110)))
	var hills := [[0.15, 60.0, "#5d8f8a", "#141d38"], [0.3, 30.0, "#4a7a5e", "#0f162c"]]
	for j in hills.size():
		var hl: Array = hills[j]
		var c := Color.html(hl[3]).lerp(Color.html(hl[2]), f)
		for x in range(0, W, 4):
			var wx: float = x + cam.x * hl[0]
			var hh: float = 50 + hl[1] + sin(wx * 0.011 + j * 2) * 26 + sin(wx * 0.031 + j) * 10
			ci.draw_rect(Rect2(x, roundf(H - 40 - hh - cam.y * hl[0] * 0.3), 4, H), c)


func _draw_ents(ci: CanvasItem) -> void:
	for i: int in world.dmg:
		var step := mini(2, int(world.dmg[i] * 3))
		ci.draw_texture_rect_region(atlas, Rect2((i % world.WW) * T, (i / world.WW) * T, T, T), Rect2((Art.CRACK1 + step) * T, 0, T, T))
	for po in pouches:
		ci.draw_texture(spr.pouch[0][0], Vector2(roundf(po.pos.x - 5), roundf(po.pos.y - 4 + sin(time * 3) * 1.5)))
	for it in items:
		ci.draw_texture_rect_region(atlas, Rect2(roundf(it.pos.x - 3), roundf(it.pos.y - 3), 6, 6), Rect2(ITEM_TILE[it.id] * T + 4, 4, 8, 8))
	for m in monsters:
		m.frame = (int(m.anim * 8) % 2) if m.kind == "flyer" else ((0 if m.on_ground else 1) if m.kind == "leaper" else int(m.anim * 6) % 2)
		if m.hurt > 0 and int(time * 30) % 2 == 1:
			continue
		var tex: Texture2D = spr[m.kind][m.frame][1 if m.dir < 0 else 0]
		ci.draw_texture(tex, Vector2(roundf(m.x + m.w / 2 - tex.get_width() / 2.0), roundf(m.y + m.h - tex.get_height() + 1)))
	if not (p.safe > 0 and int(time * 20) % 2 == 1):
		var fr := (int(p.walk) % 2) if (p.on_ground and p.walk > 0) else (0 if p.on_ground else 1)
		var side := 1 if p.dir < 0 else 0
		var tex: Texture2D = spr.you[fr][side]
		ci.draw_texture(tex, Vector2(roundf(p.x + p.w / 2 - tex.get_width() / 2.0), roundf(p.y + p.h - tex.get_height() + 1)))
		var tool: Texture2D = (spr.sword[tools.sword] if SLOTS[sel].id == "sword" else spr.pick[tools.pick])[side]
		var lift := 4 if p.swing > 0 else 0
		ci.draw_texture(tool, Vector2(roundf(p.x + p.w / 2 + (2 if p.dir > 0 else -2 - tool.get_width())), roundf(p.y - 3 + lift)))
	for q in parts:
		ci.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y), 2, 2), q.col)

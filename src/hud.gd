extends Control
## Everything drawn over the world: health, the day's clock, the hint, the hotbar, messages,
## the craft list, and the title, pause and results screens. Reads the game; changes nothing.

const Art = preload("res://src/art.gd")
const W := 640
const H := 360
const T := 16
const CRAFT := Rect2(8, 50, 372, 26 + 7 * 31 + 4)
const CRAFT_HEAD := 26
const CRAFT_ROW := 31
const WHERE := {"wood": "dig a tree trunk", "copper": "orange glints in the stone", "iron": "pale glints in deep rock", "stone": "under the dirt"}
const CONTROLS := [["A / D or arrows", "Move"], ["Space", "Jump"], ["Hold left mouse", "Dig, or attack a monster"],
	["Right mouse", "Place the selected block"], ["1 - 7 or wheel", "Pick a hotbar slot"], ["E", "Open the craft list"],
	["P", "Pause"], ["F  /  G", "No mouse: dig / place ahead (hold S for below)"]]

var g                               ## the game (main.gd)
var font: Font = ThemeDB.fallback_font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, H)


## The recipe row under a point, or -1.
func craft_row_at(m: Vector2) -> int:
	if not CRAFT.has_point(m):
		return -1
	var i := floori((m.y - CRAFT.position.y - CRAFT_HEAD) / CRAFT_ROW)
	return i if (i >= 0 and i < g.RECIPES.size()) else -1


## True when the craft list is open and covers a point, so a click there never digs.
func over_craft(m: Vector2) -> bool:
	return g.craft_open and CRAFT.has_point(m)


func _tw(s: String, px: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


# align: 0 centred on x, -1 starting at x, 1 ending at x. y is the text's middle.
func _text(s: String, x: float, y: float, px: int, c: Color, align: int = 0) -> void:
	var w := _tw(s, px)
	var left := x - w / 2 if align == 0 else (x if align < 0 else x - w)
	draw_string(font, Vector2(roundf(left), roundf(y + px * 0.36)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)


func _panel(r: Rect2, a: float = 0.86, edge: Color = Color(1, 1, 1, 0.16)) -> void:
	draw_rect(r, Color(0.063, 0.055, 0.118, a))
	draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1, 1)), edge, false, 1.0)


func _c(h: String) -> Color:
	return Color.html(h)


func _draw() -> void:
	match g.scene:
		"title":
			_title()
		"play":
			_play()
		"pause":
			_banner("Paused", ["P: back to the hollow", "R: leave this world and start a fresh one"])
		"results":
			_banner("Dawn", [g.gained, "%d blocks dug  -  %d monsters felled  -  woke at the bed %d time%s" % [g.dug, g.killed, g.deaths, "" if g.deaths == 1 else "s"],
				"Enter: a fresh world nobody has seen"])


func _hint() -> String:
	var n: int = g.night_number()
	if g.phase == "night":
		return "Night %d of %d: hold out until dawn" % [n, int(g.t.nightsToWin)]
	if g.phase == "dusk":
		return "Dusk. Get home and wall yourself in"
	if n > 1 and fmod(g.time, g.cycle()) < 12:
		return "Dawn. Repair, craft, dig deeper"
	return g.HINTS[g.tut]


func _play() -> void:
	var t: Dictionary = g.t
	var p = g.p
	var spr: Dictionary = g.spr
	# health
	_panel(Rect2(6, 6, 76, 18))
	for i in 5:
		var v := clampf((p.hp - i * t.playerHp / 5.0) / (t.playerHp / 5.0), 0.0, 1.0)
		draw_texture(spr.heart[1][0], Vector2(10 + i * 14, 10))
		if v > 0:
			var w := ceilf(11 * v)
			draw_texture_rect_region(spr.heart[0][0], Rect2(10 + i * 14, 10, w, 10), Rect2(0, 0, w, 10))
	# the day's clock
	var tc := fmod(g.time, g.cycle())
	var day_all: float = t.dayLength + t.duskLength
	var night := tc >= day_all
	var k: float = (tc - day_all) / t.nightLength if night else tc / day_all
	_panel(Rect2(W / 2 - 88, 6, 176, 18))
	draw_texture(spr.moon[0][0] if night else spr.sun[0][0], Vector2(W / 2 - 83, 10))
	var label := "Night %d of %d" % [g.night_number(), int(t.nightsToWin)] if night else ("Dusk" if g.phase == "dusk" else "Day %d" % g.night_number())
	_text(label, W / 2 - 68, 15, 11, Color.WHITE, -1)
	draw_rect(Rect2(W / 2 + 20, 12, 62, 6), _c("#34304f"))
	draw_rect(Rect2(W / 2 + 20, 12, roundf(62 * k), 6), _c("#9fb4ff") if night else (_c("#f2a65a") if g.phase == "dusk" else _c("#f2c94c")))
	_panel(Rect2(W - 112, 6, 106, 18))
	_text("E  craft     P  pause", W - 59, 15, 10, _c("#e8e4f4"))
	# what to do next: one line, always in the same place
	var h := _hint()
	if h != "":
		var w := roundf(_tw(h, 12)) + 24
		var warn: bool = g.phase != "day"
		_panel(Rect2(roundf(W / 2 - w / 2), 28, w, 20), 0.9, _c("#ff8a80") if warn else _c("#f2c94c"))
		_text(h, W / 2, 38, 12, _c("#ffd0c8") if warn else _c("#fff4b0"))
	# hotbar
	var sw := 34
	var n: int = g.SLOTS.size()
	var bx := roundf(W / 2 - n * sw / 2.0)
	var by := H - 38
	for i in n:
		var sl: Dictionary = g.SLOTS[i]
		var x := bx + i * sw
		var block: bool = sl.has("tile")
		var has: bool = g.inv[sl.id] > 0 if block else (sl.id == "pick" or g.tools.sword > 0)
		var on: bool = i == g.sel
		_panel(Rect2(x, by, sw - 2, 32), 0.9, _c("#fff4b0") if on else Color(1, 1, 1, 0.16))
		if on:
			draw_rect(Rect2(x + 1, by + 1, sw - 4, 30), Color(1, 0.96, 0.69, 0.14))
		var tint := Color(1, 1, 1, 1.0 if has else 0.35)
		if block:
			draw_texture_rect_region(g.atlas, Rect2(x + 8, by + 9, T, T), Rect2(sl.tile * T, 0, T, T), tint)
		else:
			var ic: Texture2D = spr[sl.id][g.tools[sl.id]][0]
			draw_texture(ic, Vector2(x + 16 - ic.get_width() / 2, by + 17 - ic.get_height() / 2), tint)
		_text(str(i + 1), x + 4, by + 7, 9, _c("#fff4b0") if on else _c("#b9b4cf"), -1)
		if block:
			_text(str(g.inv[sl.id]), x + sw - 5, by + 25, 10, Color.WHITE if has else _c("#8a86a0"), 1)
	var bw := n * sw - 2
	_panel(Rect2(bx, by - 18, bw, 16), 0.9)
	_text(g.SLOTS[g.sel].name, bx + 6, by - 10, 10, _c("#fff4b0"), -1)
	_text("wood %d    copper %d    iron %d" % [g.inv.wood, g.inv.copper, g.inv.iron], bx + bw - 6, by - 10, 10, _c("#e8e4f4"), 1)
	# messages: newest lowest, each fading out
	for i in g.floats.size():
		var f: Dictionary = g.floats[i]
		var w := roundf(_tw(f.s, 12)) + 24
		var x := roundf(W / 2 - w / 2)
		var y: float = by - 42 - (g.floats.size() - 1 - i) * 23
		var a := minf(1.0, f.life / 0.5)
		draw_rect(Rect2(x, y, w, 20), Color(0.063, 0.055, 0.118, 0.94 * a))
		draw_rect(Rect2(x, y, 3, 20), Color(f.col.r, f.col.g, f.col.b, a))
		_text(f.s, W / 2 + 1, y + 10, 12, Color(1, 1, 1, a))
	# the block under the cursor: what a click would do
	if not over_craft(g.mouse()):
		var cur: Vector2i = g.cursor_tile()
		var at: Vector2 = Vector2(cur.x * T, cur.y * T) - g.cam.round()
		var sl: Dictionary = g.SLOTS[g.sel]
		var v: int = g.world.get_t(cur.x, cur.y)
		if sl.has("tile") and g.inv[sl.id] > 0 and (v == Art.AIR or v == Art.LEAF):
			var ok: bool = g.can_place(cur.x, cur.y, sl.tile)
			draw_texture_rect_region(g.atlas, Rect2(at, Vector2(T, T)), Rect2(sl.tile * T, 0, T, T), Color(1, 1, 1, 0.55))
			draw_rect(Rect2(at + Vector2(0.5, 0.5), Vector2(T - 1, T - 1)), _c("#8cf07a") if ok else _c("#ff6b6b"), false, 1.0)
		elif v != Art.AIR:
			draw_rect(Rect2(at + Vector2(0.5, 0.5), Vector2(T - 1, T - 1)), Color(1, 1, 1, 0.85 if g.in_reach(cur.x, cur.y) else 0.25), false, 1.0)
	if g.craft_open:
		_craft()


# Each recipe a row: its key, its name, what it costs in green (have) or red (missing), and a Craft button.
func _craft() -> void:
	var c := CRAFT
	var x0 := c.position.x
	_panel(c, 0.95, _c("#f2c94c"))
	_text("Crafting", x0 + 10, c.position.y + 13, 13, _c("#fff4b0"), -1)
	_text("click a row or press its number     E closes", c.end.x - 10, c.position.y + 13, 9, _c("#b9b4cf"), 1)
	var hover := craft_row_at(g.mouse())
	for i in g.RECIPES.size():
		var r: Dictionary = g.RECIPES[i]
		var y: float = c.position.y + CRAFT_HEAD + i * CRAFT_ROW
		var ok: bool = g.can_craft(r)
		var own: bool = g.owned(r)
		var cost: Dictionary = g.cost_of(r)
		draw_rect(Rect2(x0 + 4, y, c.size.x - 8, CRAFT_ROW - 3), Color(0.55, 0.94, 0.48, 0.30 if hover == i else 0.14) if ok else Color(1, 1, 1, 0.05))
		draw_rect(Rect2(x0 + 8, y + 4, 16, 16), _c("#8cf07a") if ok else _c("#4a4666"))
		_text(str(i + 1), x0 + 16, y + 12, 11, _c("#10201a") if ok else _c("#d8d4e8"))
		var title: String = r.name + ("  x%d" % int(g.t[r.count]) if r.has("count") else "")
		_text(title, x0 + 30, y + 9, 12, _c("#8a86a0") if own else (Color.WHITE if ok else _c("#cfcbe0")), -1)
		if own:
			_text("you already have it", x0 + 30, y + 21, 9, _c("#8a86a0"), -1)
			continue
		var x := x0 + 30
		var lack := ""
		for key: String in cost:
			var enough: bool = g.inv[key] >= cost[key]
			var label := "%s %d / %d" % [key, g.inv[key], cost[key]]
			_text(label, x, y + 21, 10, _c("#8cf07a") if enough else _c("#ff8a80"), -1)
			x += _tw(label, 10) + 12
			if not enough and lack == "":
				lack = key
		if lack != "":
			_text("find %s: %s" % [lack, WHERE[lack]], x, y + 21, 9, _c("#b9b4cf"), -1)
		if ok:
			draw_rect(Rect2(c.end.x - 56, y + 5, 46, 18), _c("#b6ffa6") if hover == i else _c("#8cf07a"))
			_text("Craft", c.end.x - 33, y + 14, 11, _c("#10201a"))


func _banner(title: String, lines: Array) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.08, 0.82))
	_text(title, W / 2, 96, 34, _c("#fff4b0"))
	for i in lines.size():
		_text(lines[i], W / 2, 150 + i * 26, 13, Color.WHITE if i == lines.size() - 1 else _c("#e8e4f4"))


func _title() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.08, 0.84))
	_text("Nightfall Hollow", W / 2, 50, 36, _c("#fff4b0"))
	_text("Dig by day. Craft what you find. Hold your shelter through three nights.", W / 2, 84, 13, Color.WHITE)
	var x := W / 2 - 230
	var y := 104
	var row := 22
	_panel(Rect2(x, y, 460, CONTROLS.size() * row + 10), 0.9)
	for i in CONTROLS.size():
		var cy := y + 16 + i * row
		if i % 2 == 0:
			draw_rect(Rect2(x + 4, cy - 10, 452, row - 2), Color(1, 1, 1, 0.05))
		_text(CONTROLS[i][0], x + 140, cy, 12, _c("#fff4b0"), 1)
		_text(CONTROLS[i][1], x + 156, cy, 12, Color.WHITE, -1)
	_text("Press Enter or click to start", W / 2, H - 46, 15, Color(0.55, 0.94, 0.48, 0.65 + 0.35 * sin(g.tick * 0.07)))

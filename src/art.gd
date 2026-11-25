extends RefCounted
## Every tile and figure, drawn in code as pixel maps (no image files yet).
## Tiles go into one atlas, one 16 px column per id below; figures are textures with a dark outline.

const T := 16
## Tile ids. The first fourteen are world tiles; the rest are atlas-only (backdrops and cracks).
enum { AIR, GRASS, DIRT, STONE, COPPER, DEEP, IRON, TRUNK, LEAF, PLANK, DOOR, TORCH, BED, BEDROCK,
	BG_DIRT, BG_STONE, BG_DEEP, CRACK1, CRACK2, CRACK3, TILE_COUNT }


## A fixed hash in 0..1 for textures and twinkles: looks only, never gameplay.
static func hsh(a: int, b: int, c: int = 0) -> float:
	var n: int = (((a + 1) * 374761393) ^ ((b + 1) * 668265263) ^ ((c + 1) * 1274126177)) & 0xFFFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967296.0


static func col(h: String) -> Color:
	return Color.html(h)


static func _blank(w: int = T, h: int = T) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _speck(img: Image, base: String, cols: Array, dens: float, salt: int) -> void:
	img.fill(col(base))
	for y in T:
		for x in T:
			var r := hsh(x, y, salt)
			if r < dens:
				img.set_pixel(x, y, col(cols[int(r / dens * cols.size())]))


# Nuggets and rock lumps: a body, a shadow and one highlight.
static func _blobs(img: Image, n: int, cols: Array, salt: int) -> void:
	for i in n:
		var x := 1 + int(hsh(i, 1, salt) * 11)
		var y := 1 + int(hsh(i, 2, salt) * 11)
		var w := 2 + int(hsh(i, 3, salt) * 2)
		var h := 2 + int(hsh(i, 4, salt) * 2)
		img.fill_rect(Rect2i(x, y + 1, w + 1, h), col(cols[1]))
		img.fill_rect(Rect2i(x, y, w, h), col(cols[0]))
		img.set_pixel(x, y, col(cols[2]))


static func _tile(id: int) -> Image:
	var g := _blank()
	match id:
		DIRT:
			_speck(g, "#7a5233", ["#5e3d25", "#8f6440", "#694529"], 0.3, 1)
		GRASS:
			_speck(g, "#7a5233", ["#5e3d25", "#8f6440", "#694529"], 0.3, 1)
			for x in T:
				var d := 3 + int(hsh(x, 0, 7) * 3)
				g.fill_rect(Rect2i(x, 0, 1, d), col("#3f8f3a"))
				g.set_pixel(x, 0, col("#6cc04f"))
				if hsh(x, 1, 7) < 0.4:
					g.set_pixel(x, d - 1, col("#2f6e30"))
		STONE:
			_speck(g, "#6f7680", ["#636a74", "#7a818b"], 0.35, 2)
			_blobs(g, 4, ["#7f8690", "#585e68", "#959ca6"], 3)
		COPPER:
			_speck(g, "#6f7680", ["#636a74", "#7a818b"], 0.35, 2)
			_blobs(g, 5, ["#d9813a", "#8f4f1f", "#ffc98a"], 4)
		DEEP:
			_speck(g, "#4a4f5c", ["#40444f", "#535866"], 0.35, 5)
			_blobs(g, 4, ["#5b6170", "#343844", "#70778a"], 6)
		IRON:
			_speck(g, "#4a4f5c", ["#40444f", "#535866"], 0.35, 5)
			_blobs(g, 5, ["#b9c6d8", "#6f7b8f", "#f4f8fc"], 8)
		TRUNK:
			g.fill_rect(Rect2i(4, 0, 8, T), col("#6b4a2b"))
			g.fill_rect(Rect2i(5, 0, 2, T), col("#8a6238"))
			g.fill_rect(Rect2i(10, 0, 2, T), col("#4e3520"))
			for y in range(0, T, 5):
				g.fill_rect(Rect2i(7, y + 2, 2, 1), col("#4e3520"))
		LEAF:
			for y in T:
				for x in T:
					var r := hsh(x >> 1, y >> 1, 9)
					if r >= 0.08:
						g.set_pixel(x, y, col("#2f6130" if r < 0.4 else ("#3f7d3a" if r < 0.8 else "#57a04b")))
		PLANK:
			g.fill(col("#a8743f"))
			for y in range(0, T, 4):
				g.fill_rect(Rect2i(0, y + 3, T, 1), col("#7d5229"))
				g.fill_rect(Rect2i(0, y, T, 1), col("#c08a50"))
				g.fill_rect(Rect2i((y * 3 + 5) % T, y, 1, 3), col("#7d5229"))
		DOOR:
			g.fill_rect(Rect2i(2, 0, 12, T), col("#5a3a1c"))
			g.fill_rect(Rect2i(4, 0, 8, T), col("#8a5a2e"))
			g.fill_rect(Rect2i(7, 0, 1, T), col("#6e4622"))
			g.fill_rect(Rect2i(4, 7, 8, 1), col("#6e4622"))
			g.fill_rect(Rect2i(10, 9, 1, 2), col("#f2c94c"))
		TORCH:
			g.fill_rect(Rect2i(7, 7, 2, 9), col("#6b4a2b"))
			g.fill_rect(Rect2i(6, 3, 4, 5), col("#e8772e"))
			g.fill_rect(Rect2i(7, 4, 2, 3), col("#ffd27a"))
			g.fill_rect(Rect2i(7, 2, 1, 2), col("#fff4b0"))
		BED:
			g.fill_rect(Rect2i(0, 12, T, 2), col("#5a3a1c"))
			g.fill_rect(Rect2i(0, 6, 2, 10), col("#5a3a1c"))
			g.fill_rect(Rect2i(14, 10, 2, 6), col("#5a3a1c"))
			g.fill_rect(Rect2i(5, 8, 10, 4), col("#b8323a"))
			g.fill_rect(Rect2i(5, 8, 10, 1), col("#d9545b"))
			g.fill_rect(Rect2i(2, 8, 4, 4), col("#f1ead6"))
		BEDROCK:
			_speck(g, "#16161d", ["#0e0e13", "#22222c"], 0.4, 11)
		BG_DIRT:
			_speck(g, "#3a281b", ["#32221a", "#42301f"], 0.3, 12)
		BG_STONE:
			_speck(g, "#2b2e35", ["#25282e", "#32363e"], 0.3, 13)
		BG_DEEP:
			_speck(g, "#1f2129", ["#1a1c23", "#262933"], 0.3, 14)
		CRACK1, CRACK2, CRACK3:
			var k := id - CRACK1 + 1
			for w in k * 2:
				var x := 8
				var y := 8
				for i in 4 + k * 2:
					g.set_pixel(x, y, Color(0.08, 0.055, 0.047, 0.85))
					x += roundi(hsh(w, i, 20 + k) * 2 - 1 + (0.6 if w % 2 else -0.6))
					y += roundi(hsh(w, i, 30 + k) * 2 - 1 + (0.5 if w % 3 else -0.5))
					if x < 0 or y < 0 or x >= T or y >= T:
						break
	return g


## The tile atlas: TILE_COUNT columns of 16 px, column index = tile id.
static func atlas() -> ImageTexture:
	var img := _blank(T * TILE_COUNT, T)
	for id in range(1, TILE_COUNT):
		img.blit_rect(_tile(id), Rect2i(0, 0, T, T), Vector2i(id * T, 0))
	return ImageTexture.create_from_image(img)


# One figure from a pixel map: a letter per colour, then a dark one-pixel outline round the shape.
# Returns [facing right, facing left].
static func _fig(rows: Array, pal: Dictionary, outline: bool = true) -> Array:
	var w := 0
	for r: String in rows:
		w = maxi(w, r.length())
	var h := rows.size()
	var img := _blank(w + 2, h + 2)
	for y in h:
		var r: String = rows[y]
		for x in r.length():
			if pal.has(r[x]):
				img.set_pixel(x + 1, y + 1, col(pal[r[x]]))
	if outline:
		var edge: Array[Vector2i] = []
		for y in h + 2:
			for x in w + 2:
				if img.get_pixel(x, y).a > 0.0:
					continue
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < w + 2 and q.y < h + 2 and img.get_pixelv(q).a > 0.0:
						edge.append(Vector2i(x, y))
						break
		for e in edge:
			img.set_pixelv(e, col("#1a1420"))
	var flipped := img.duplicate() as Image
	flipped.flip_x()
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(flipped)]


## Every figure, by name. Each entry is a list of frames; each frame is [right-facing, left-facing].
static func sprites() -> Dictionary:
	var you := {"h": "#e9c46a", "l": "#fff4b0", "s": "#f2c9a0", "o": "#e8772e", "O": "#b4521a", "b": "#4a3426", "k": "#2b1b12", "g": "#6f7680"}
	var top := ["...hhhhhh...", "..hhhhhhhl..", "..hhhhhhhll.", "..ssssssss..", "..sssksskk..", "..ssssssss..", "...ssssss...",
		"..oooooooo..", ".oooooooooo.", ".ooOooooOoo.", ".ssOooooOss.", "..gggggggg..", "..oooooooo.."]
	var mon := {"v": "#7d4bb8", "V": "#45246e", "e": "#d8ff5a", "t": "#f2ecd8", "m": "#2a0f3a"}
	var gn := ["....vvvvvvvv......", "..vvvvvvvvvvvv....", ".vvvvvvvvvvvvvee..", "vvvVvvvvvvvvvvevv.", "vvVVVvvvvvvvvvvvvv",
		"vvvVvvvvvvvtmtmtmt", "vvvvvvvvvvmmmmmmmm", "vvvvvvvvvvvtmtmtmt", ".vvvvvvvvvvvvvvvv."]
	var lp := [".V......V.", ".VV....VV.", "..vvvvvv..", ".vvevvevv.", ".vvvvvvvv.", "..vvttvv..", "...vvvv...", "..vvvvvv..", "..vVvvVv..",
		"..vvvvvv..", "...vvvv..."]
	var pick := ["..HHHHHH...", ".HHHHHHHH..", "HH....sHHH.", "H....sss.HH", "....sss...H", "...sss.....", "..sss......", ".sss.......", "sss........", "ss........."]
	var sword := [".........BB", "........BBB", ".......BBB.", "......BBB..", ".....BBB...", ".g..BBB....", ".ggBBB.....", "..ggB......", ".sggg......", "ss..g......", "s.........."]
	var heart := [".rr...rr.", "rrrr.rrrr", "rrrrrrrrr", "rrrrrrrrr", ".rrrrrrr.", "..rrrrr..", "...rrr...", "....r...."]
	var s := {}
	s.you = [_fig(top + ["..ooo..ooo..", "..OOO..OOO..", "..bbb..bbbb."], you), _fig(top + ["..oooo.ooo..", ".OOO....OOO.", ".bbb....bbbb"], you)]
	s.gnawer = [_fig(gn + [".VV..VV....VV..VV.", ".VV..VV....VV..VV."], mon), _fig(gn + ["..VV.VV...VV..VV..", "..VV..VV.VV...VV.."], mon)]
	s.leaper = [_fig(lp + ["..VV..VV..", ".VV....VV.", ".V......V.", ".VV....VV.", "..VV..VV..", "..V....V..", ".VV....VV."], mon),
		_fig(lp + ["...VVVV...", "...V..V...", "...V..V...", "...V..V...", "...V..V...", "..VV..VV..", ".VV....VV."], mon)]
	s.flyer = [_fig(["V....................V", "VV..................VV", "VVV................VVV", ".VVVV....v..v....VVVV.", "..VVVVV.vvvvvv.VVVVV..",
		"...VVVVvvevvevvVVVV...", "....VVVvvvvvvvvVVV....", "......VvvvttvvvV......", ".......vvvvvvvv.......", "........vv..vv........", "........V....V........"], mon),
		_fig(["......................", ".........v..v.........", "........vvvvvv........", "..VVVVVvvevvevvVVVVV..", ".VVVVVVvvvvvvvvVVVVVV.",
		"VVVV.VVvvvttvvvVV.VVVV", "VVV....vvvvvvvv....VVV", "VV......vv..vv......VV", "V.......V....V.......V"], mon)]
	s.pick = [_fig(pick, {"H": "#9aa3ad", "s": "#8a6238"}), _fig(pick, {"H": "#d9813a", "s": "#8a6238"})]
	s.sword = []
	for blade: String in ["#55505f", "#c79a5f", "#f0a35a", "#dfe8f2"]:
		s.sword.append(_fig(sword, {"B": blade, "g": "#f2c94c", "s": "#6b4a2b"}))
	s.heart = [_fig(heart, {"r": "#e5484d"}), _fig(heart, {"r": "#3a2030"})]
	s.sun = [_fig(["....y....", ".y..y..y.", "..yyyyy..", "..yYYYy..", "yyyYYYyyy", "..yYYYy..", "..yyyyy..", ".y..y..y.", "....y...."], {"y": "#f2c94c", "Y": "#fff4b0"}, false)]
	s.moon = [_fig(["..www...", ".wwww...", "www.....", "www.....", "www.....", "wwww..w.", ".wwwwww.", "..wwww.."], {"w": "#dfe8f2"}, false)]
	s.pouch = [_fig(["...kk...", "..kttk..", "..tttt..", ".tttttt.", "tttTtttt", "ttTTTttt", "tttttttt", ".tttttt."], {"t": "#c79a5f", "T": "#8a6238", "k": "#6b4a2b"})]
	return s

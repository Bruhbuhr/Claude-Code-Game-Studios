extends RefCounted
## One night monster. Three kinds, each with its own way past a shelter:
## the gnawer chews through walls, the leaper clears low ones, the duskwing flies over any with no roof.

const T := 16
## Each kind's box, its name, and its eyes (sprite pixels that glow through the dark), per frame.
const KIND := {
	"gnawer": {"w": 16.0, "h": 10.0, "name": "Gnawer", "eyes": [[Vector2i(14, 2), Vector2i(15, 2), Vector2i(14, 3)], [Vector2i(14, 2), Vector2i(15, 2), Vector2i(14, 3)]]},
	"leaper": {"w": 8.0, "h": 17.0, "name": "Leaper", "eyes": [[Vector2i(3, 3), Vector2i(6, 3)], [Vector2i(3, 3), Vector2i(6, 3)]]},
	"flyer": {"w": 14.0, "h": 8.0, "name": "Duskwing", "eyes": [[Vector2i(9, 5), Vector2i(12, 5)], [Vector2i(9, 3), Vector2i(12, 3)]]},
}

var kind := "gnawer"
var x := 0.0
var y := 0.0
var w := 16.0
var h := 10.0
var vx := 0.0
var vy := 0.0
var on_ground := false
var hit_x := 0
var hit_y := 0
var hp := 1.0
var dir := 1
var rest := 0.0      ## leaper: seconds until the next leap
var hurt := 0.0      ## seconds left flinching, when it does not steer
var anim := 0.0
var burn := false    ## dawn has come: it is burning away
var slide := 0.0     ## duskwing: seconds left sliding along what it hit
var slide_x := 0
var slide_y := 0
var frame := 0


func rect() -> Rect2:
	return Rect2(x, y, w, h)


## One step. g is the game (main.gd): its world, digger, tuning and the tile and hurt calls.
func update(g, dt: float) -> void:
	var t: Dictionary = g.t
	var world = g.world
	var p = g.p
	var cx := x + w / 2
	var dx: float = p.x + p.w / 2 - cx
	var dy: float = p.y + p.h / 2 - (y + h / 2)
	var to := 1 if dx >= 0 else -1
	hurt -= dt
	anim += dt
	dir = to
	if burn:
		hp -= 40.0 * dt
		g.spray(cx, y, "#ffd27a", 1, 30.0)
	if kind == "gnawer":
		if hurt <= 0:
			vx = to * t.gnawerSpeed if absf(dx) > 6 else 0.0
		vy += t.gravity * dt
		world.move_box(self, dt, false)
		var mtx := floori(cx / T)
		var fty := floori((y + h - 2) / T)
		if hit_x != 0:
			var tx := floori((x + w + 3 if hit_x > 0 else x - 3) / T)
			var block: bool = world.solid(world.get_t(tx, fty))
			if on_ground and block and not world.solid(world.get_t(tx, fty - 1)) and not world.solid(world.get_t(mtx, fty - 1)):
				vy = -t.gnawerHop # one block: hop it
			elif on_ground: # two or more: through it (never mid-hop, or every step it climbs gets bitten)
				g.chew(tx, fty if block else fty - 1, dt)
		elif absf(dx) <= 6 and dy > 8 and on_ground: # the digger went down: chew a hole as wide as itself
			for c in range(floori(x / T), floori((x + w) / T) + 1):
				g.chew(c, floori((y + h + 3) / T), dt)
		elif absf(dx) <= 6 and dy < -12 and dy > -5 * T and on_ground: # the digger went up: gnaw out what they stand on
			for c in range(floori(p.x / T), floori((p.x + p.w) / T) + 1):
				g.chew(c, floori((p.y + p.h + 3) / T), dt)
	elif kind == "leaper":
		vy += t.gravity * dt
		if not on_ground and hurt <= 0:
			vx = to * t.leaperSpeed # steers in the air, so a wall it brushes never pins it
		world.move_box(self, dt, false)
		if on_ground:
			vx = 0.0
			rest -= dt
			if rest <= 0:
				vx = to * t.leaperSpeed
				vy = -t.leaperJump
				rest = t.leaperRest * (0.8 + g.rng.randf() * 0.5)
	else: # duskwing: straight at the digger through open air, sliding along what it hits
		var d := maxf(1.0, Vector2(dx, dy).length())
		var sp: float = t.flyerSpeed
		if hurt <= 0:
			vx = dx / d * sp
			vy = dy / d * sp + sin(anim * 5) * 14
		if slide > 0:
			slide -= dt
			if slide_x != 0:
				vx = slide_x * sp
			else:
				vy = slide_y * sp
		world.move_box(self, dt, false)
		if hit_x != 0 and slide <= 0:
			slide = 0.7
			slide_x = 0
			slide_y = 1 if dy > 0 else -1
		elif hit_y != 0 and slide <= 0:
			slide = 0.7
			slide_y = 0
			slide_x = to
	x = clampf(x, T, (world.WW - 2) * T)
	if p.safe <= 0 and not burn and rect().intersects(p.rect()):
		g.hurt_player(t[kind + "Damage"], to)

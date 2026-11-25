extends SceneTree
## The one check: same seed, same world; a recipe crafts; the clock reaches night.
## Run: godot --headless --path . -s res://tests/selfcheck.gd   (exit 0 pass, 1 fail)


func _initialize() -> void:
	var World = load("res://src/world.gd")
	var Main = load("res://src/main.gd")
	var Art = load("res://src/art.gd")
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/config.json"))
	var rng := RandomNumberGenerator.new()
	var worlds := []
	for s in [7, 7, 8]:
		var w = World.new()
		rng.seed = s
		w.generate(rng, t)
		worlds.append(w)
	var a = worlds[0]
	var m = Main.new()
	m.t = t
	m.inv.wood = 1
	m.craft(0)
	var checks := {
		"same seed gives the same world": a.tiles == worlds[1].tiles,
		"another seed gives another world": a.tiles != worlds[2].tiles,
		"the bed stands on the surface": a.get_t(a.sx, a.surf[a.sx] - 1) == Art.BED,
		"copper waits under the bed": a.get_t(a.sx + 4, a.surf[a.sx] + 6) == Art.COPPER,
		"outside the world is bedrock": a.get_t(-1, 10) == Art.BEDROCK,
		"one wood crafts the torches": m.inv.wood == 0 and m.inv.torch == int(t.torchYield),
		"no wood crafts nothing": not m.can_craft(m.RECIPES[0]),
		"night comes after day and dusk": m.phase_at(t.dayLength + t.duskLength + 1) == "night" and m.phase_at(1) == "day",
		"night is dark": m.daylight(t.dayLength + t.duskLength + 1) == 0.0,
	}
	var failed := 0
	for name in checks:
		print(("ok:   " if checks[name] else "FAIL: ") + name)
		if not checks[name]:
			failed += 1
	for w in worlds:
		w.free()
	m.free()
	quit(1 if failed > 0 else 0)

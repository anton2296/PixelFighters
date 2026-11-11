class_name TestArena
extends TestSuite
# Конфиг арен: поля, билдер физики, стартовые позиции для любого числа бойцов.

func test_arena_fields():
	check(ArenaData.ARENA_ORDER.size() >= 2, "минимум 2 арены")
	for id in ArenaData.ARENA_ORDER:
		var a = ArenaData.ARENAS[id]
		check(float(a.floor_y) > 0.0, "%s: floor_y" % id)
		check(a.x_min < a.x_max, "%s: x_min < x_max" % id)
		check(a.proj_min <= a.x_min, "%s: proj_min <= x_min" % id)
		check(a.proj_max >= a.x_max, "%s: proj_max >= x_max" % id)
		check(a.has("sky") and a.has("platform_color") and a.has("decor") and a.has("platforms"),
			"%s: поля декора" % id)

func test_get_arena():
	check_eq(ArenaData.get_arena("cave").x_min, ArenaData.ARENAS["cave"].x_min, "get_arena по id")
	check_eq(ArenaData.get_arena("bogus").x_min, ArenaData.ARENAS[ArenaData.ARENA_ORDER[0]].x_min,
		"get_arena: fallback на первую арену")

func test_spawn_positions():
	for id in ArenaData.ARENA_ORDER:
		var a = ArenaData.ARENAS[id]
		for n in [2, 3, 4, 6]:
			var pts = ArenaData.spawn_positions(a, n)
			check_eq(pts.size(), n, "%s: позиций для n=%d" % [id, n])
			for p in pts:
				check(p.x >= a.x_min and p.x <= a.x_max, "%s n=%d: x в игровых границах" % [id, n])
				check_eq(p.y, a.floor_y, "%s n=%d: y = пол" % [id, n])
			for i in range(n - 1):
				check(pts[i].x < pts[i + 1].x, "%s n=%d: позиции упорядочены" % [id, n])

func test_builder():
	for id in ArenaData.ARENA_ORDER:
		var a = ArenaData.ARENAS[id]
		var scene := Node2D.new()
		ArenaData.build(scene, a)
		var bodies: Array = []
		for c in scene.get_children():
			if c is StaticBody2D:
				bodies.append(c)
		check_eq(bodies.size(), 1 + 2 + a.platforms.size(),
			"%s: пол + 2 стены + платформы" % id)
		for b in bodies:
			check(b.collision_layer == 1, "%s: физ. тела на слое 1" % id)
		scene.free()

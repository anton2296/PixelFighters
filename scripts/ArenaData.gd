class_name ArenaData
# Конфиг арены: границы, пол, платформы, декор. Билдер строит сцену из этих данных,
# бойцы и снаряды читают границы из конфига — никаких magic-чисел по всей codebase.

const ARENA_ORDER = ["dojo", "cave"]
const ARENA_NAMES = { "dojo": "Додзё", "cave": "Пещера" }

# Не const: словари с Color/Vector2 — не константное выражение в GDScript.
static var ARENAS = {
	"dojo": {
		"name": "Додзё",
		"floor_y": 620.0,
		"x_min": 70.0, "x_max": 1210.0,
		"proj_min": 40.0, "proj_max": 1240.0,
		"sky": Color(0.10, 0.12, 0.22),
		"platform_color": Color(0.25, 0.24, 0.3),
		"platforms": [],
		"decor": [
			{ "type": "polygon", "points": PackedVector2Array([Vector2(0, 620), Vector2(220, 380), Vector2(480, 620)]), "color": Color(0.16, 0.18, 0.28) },
			{ "type": "polygon", "points": PackedVector2Array([Vector2(700, 620), Vector2(980, 340), Vector2(1280, 620)]), "color": Color(0.14, 0.16, 0.26) },
			{ "type": "polygon", "points": PackedVector2Array([Vector2(1050, 120), Vector2(1120, 90), Vector2(1180, 140), Vector2(1140, 210), Vector2(1060, 200)]), "color": Color(0.85, 0.85, 0.6, 0.6) },
			{ "type": "rect", "pos": Vector2(0, 620), "size": Vector2(1280, 100), "color": Color(0.20, 0.17, 0.14) },
			{ "type": "rect", "pos": Vector2(0, 620), "size": Vector2(1280, 4), "color": Color(0.75, 0.65, 0.4) },
			{ "type": "rect", "pos": Vector2(28, 420), "size": Vector2(24, 200), "color": Color(0.25, 0.24, 0.3) },
			{ "type": "rect", "pos": Vector2(1228, 420), "size": Vector2(24, 200), "color": Color(0.25, 0.24, 0.3) },
		],
	},
	"cave": {
		"name": "Пещера",
		"floor_y": 620.0,
		"x_min": 90.0, "x_max": 1190.0,
		"proj_min": 55.0, "proj_max": 1225.0,
		"sky": Color(0.11, 0.09, 0.12),
		"platform_color": Color(0.32, 0.27, 0.22),
		"platforms": [
			{ "pos": Vector2(250, 470), "size": Vector2(220, 24) },
			{ "pos": Vector2(810, 360), "size": Vector2(220, 24) },
			{ "pos": Vector2(530, 280), "size": Vector2(180, 24) },
		],
		"decor": [
			{ "type": "polygon", "points": PackedVector2Array([Vector2(0, 620), Vector2(160, 300), Vector2(360, 620)]), "color": Color(0.15, 0.12, 0.13) },
			{ "type": "polygon", "points": PackedVector2Array([Vector2(900, 620), Vector2(1120, 260), Vector2(1280, 620)]), "color": Color(0.13, 0.11, 0.14) },
			{ "type": "rect", "pos": Vector2(0, 620), "size": Vector2(1280, 100), "color": Color(0.19, 0.15, 0.12) },
			{ "type": "rect", "pos": Vector2(0, 620), "size": Vector2(1280, 4), "color": Color(0.8, 0.5, 0.3) },
			{ "type": "rect", "pos": Vector2(48, 420), "size": Vector2(24, 200), "color": Color(0.3, 0.26, 0.24) },
			{ "type": "rect", "pos": Vector2(1208, 420), "size": Vector2(24, 200), "color": Color(0.3, 0.26, 0.24) },
		],
	},
}

static func get_arena(id: String) -> Dictionary:
	return ARENAS.get(id, ARENAS[ARENA_ORDER[0]])

# Стартовые позиции n бойцов, равномерно внутри игровых границ.
static func spawn_positions(a: Dictionary, n: int) -> Array:
	var out: Array = []
	for i in range(n):
		var t = (i + 0.5) / float(n)
		out.append(Vector2(a.x_min + (a.x_max - a.x_min) * t, a.floor_y))
	return out

# Строит визуальную и физическую арену внутри узла сцены.
static func build(scene: Node2D, a: Dictionary):
	var sky := ColorRect.new()
	sky.color = a.sky
	sky.size = Vector2(1280, 720)
	scene.add_child(sky)
	for d in a.decor:
		if d.type == "polygon":
			var p := Polygon2D.new()
			p.polygon = d.points
			p.color = d.color
			scene.add_child(p)
		else:
			var r := ColorRect.new()
			r.position = d.pos
			r.size = d.size
			r.color = d.color
			scene.add_child(r)
	# физический пол: слой 1, закрывает игровое поле + запас за стенами
	var g := StaticBody2D.new()
	var gs := CollisionShape2D.new()
	var gr := RectangleShape2D.new()
	gr.size = Vector2(a.x_max - a.x_min + 120.0, 200.0)
	gs.shape = gr
	gs.position = Vector2((a.x_min + a.x_max) / 2.0, a.floor_y + 100.0)
	g.add_child(gs)
	g.collision_layer = 1
	scene.add_child(g)
	# стены
	for wx in [a.x_min - 40.0, a.x_max + 40.0]:
		var wall := StaticBody2D.new()
		var ws := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(60, 720)
		ws.shape = wr
		ws.position = Vector2(wx, 360)
		wall.add_child(ws)
		wall.collision_layer = 1
		scene.add_child(wall)
	# платформы: слой 1 — на них можно стоять
	for pl in a.platforms:
		var pb := StaticBody2D.new()
		var ps := CollisionShape2D.new()
		var pr := RectangleShape2D.new()
		pr.size = pl.size
		ps.shape = pr
		ps.position = pl.pos + pl.size / 2.0
		pb.add_child(ps)
		pb.collision_layer = 1
		scene.add_child(pb)
		var vr := ColorRect.new()
		vr.position = pl.pos
		vr.size = pl.size
		vr.color = a.platform_color
		scene.add_child(vr)

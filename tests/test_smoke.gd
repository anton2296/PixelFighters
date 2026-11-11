class_name SmokeRunner
extends Node
# Сценарные проверки в живом дереве сцены:
# MainMenu (UI под 6 персонажей), Fight с 4 бойцами на пещере, снаряд,
# KO и переход раунда, Fight с 2 бойцами на додзё с новыми персонажами.

var checks := 0
var failures: Array = []
var done := false
var step := 0
var frames := 0
var menu: Control
var fight: Node
var hp_before := 0.0
var proj: Projectile = null
var proj_x0 := 0.0
var proj_moved := false

# GameState: Engine-синглтон (тесты) или узел автозагрузки /root/GameState (игра).
func gs() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return get_node("/root/GameState")

func check(cond: bool, msg: String):
	checks += 1
	if not cond:
		failures.append(msg)

func hp_total() -> float:
	var s := 0.0
	for f in fight.fighters:
		s += f.hp
	return s

func _ready():
	step = 1
	frames = 0

func _physics_process(delta: float):
	frames += 1
	match step:
		1:
			if frames == 1:
				menu = load("res://scenes/MainMenu.tscn").instantiate()
				add_child(menu)
			elif frames >= 3:
				check(menu.panels.size() == CharData.ORDER.size(),
					"MainMenu: карточек == %d персонажей" % CharData.ORDER.size())
				check(menu.arena_btn.item_count == ArenaData.ARENA_ORDER.size(), "MainMenu: выбор арены")
				check(menu.part_btn.item_count == 1, "MainMenu: в UI только 2 участника")
				check(menu.mode_btn.item_count == 2, "MainMenu: режим")
				check(menu.diff_btn.item_count == 3, "MainMenu: сложность")
				var fits = true
				for p in menu.panels:
					if p.position.y + p.size.y > 720.0:
						fits = false
				check(fits, "MainMenu: сетка карточек влезает в экран")
				# настройки управления: назначенная клавиша должна показаться на кнопке
				# имитируем реальное нажатие через очередь ввода, путь _input
				menu.open_settings()
				menu.start_capture(1, "light")
				var ev := InputEventKey.new()
				ev.pressed = true
				ev.keycode = KEY_K
				ev.physical_keycode = KEY_K
				get_tree().root.push_input(ev)
				check(menu.key_buttons["1.light"].text == "K", "Управление: клавиша K назначена и показана")
				menu.close_settings()
				step = 2
				frames = 0
		2:
			if frames == 1:
				gs().arena_id = "cave"
				gs().participants = 4
				gs().p2_is_bot = true
				gs().chars = ["striker", "bruiser", "acrobat", "mage"]
				fight = load("res://scenes/Fight.tscn").instantiate()
				add_child(fight)
			elif frames >= 2:
				check(fight.fighters.size() == 4, "Fight(4): 4 бойца на поле")
				check(fight.bots[0] == null, "Fight(4): слот 0 — человек")
				check(fight.bots[1] != null and fight.bots[2] != null and fight.bots[3] != null,
					"Fight(4): слоты 1-3 — боты")
				check(fight.phase == "intro", "Fight(4): раунд начинается интро")
				step = 3
				frames = 0
		3:
			if fight.phase == "fight":
				check(true, "Fight(4): интро -> fight")
				hp_before = hp_total()
				step = 4
				frames = 0
			elif frames > 240:
				check(false, "Fight(4): фаза не перешла в fight за 240 кадров")
				hp_before = hp_total()
				step = 4
				frames = 0
		4:
			if frames >= 300:
				check(hp_total() < hp_before, "Fight(4): боты наносят урон за 5 секунд")
				step = 5
				frames = 0
		5:
			if frames == 1:
				var mage: Fighter = fight.fighters[3]
				# сбросим мага к правому краю арены: снаряд пролетает
				# длинную дистанцию и не поражает цель мгновенно
				mage.reset(Vector2(1100.0, fight.arena.floor_y), -1)
				fight.spawn_projectile(mage, mage.char_data.attacks.special)
				proj = null
				for c in fight.get_children():
					if c is Projectile:
						proj = c
				check(proj != null, "Fight(4): spawn_projectile создал снаряд")
				if proj != null:
					proj_x0 = proj.global_position.x
			elif frames == 4:
				# снаряд может поразить цель и освободиться очень быстро —
				# фиксируем смещение влево сразу, пока он жив
				if is_instance_valid(proj) and proj.global_position.x < proj_x0 - 10.0:
					proj_moved = true
			elif frames >= 130:
				check(proj_moved, "Fight(4): снаряд летит к врагам")
				var live = 0
				for c in fight.get_children():
					if c is Projectile:
						live += 1
				check(live == 0, "Fight(4): снаряд поражен за 2 секунды")
				check(hp_total() < hp_before, "Fight(4): HP упал от снаряда/боёв")
				step = 6
				frames = 0
		6:
			if frames == 1:
				for i in range(1, 4):
					fight.fighters[i].take_hit(999.0, 1.0, 0.0, 0.0, 0.1, true)
			elif fight.phase == "over":
				check(fight.fighters[0].hp > 0.0, "Fight(4): KO — один выживший")
				step = 7
				frames = 0
			elif frames > 300:
				check(false, "Fight(4): фаза over не наступила после KO")
				step = 7
				frames = 0
		7:
			if frames >= 200:
				check(fight.round_num == 2, "Fight(4): после KO стартует раунд 2")
				check(int(fight.wins[0]) == 1, "Fight(4): победа записана выжившему")
				var ok = true
				for f in fight.fighters:
					if f.hp < f.max_hp:
						ok = false
				check(ok, "Fight(4): новый раунд — HP восстановлены")
				var a = ArenaData.ARENAS["cave"]
				for f in fight.fighters:
					if f.position.x < a.x_min or f.position.x > a.x_max:
						ok = false
				check(ok, "Fight(4): спавны внутри границ пещеры")
				step = 8
				frames = 0
		8:
			if frames == 1:
				fight.queue_free()
				gs().arena_id = "dojo"
				gs().participants = 2
				gs().p2_is_bot = true
				gs().chars = ["shadow", "gunner"]
				fight = load("res://scenes/Fight.tscn").instantiate()
				add_child(fight)
			elif frames >= 3:
				check(fight.fighters.size() == 2, "Fight(2): 2 бойца")
				check(fight.bots[0] == null and fight.bots[1] != null, "Fight(2): человек + бот")
				var f0: Fighter = fight.fighters[0]
				check(f0.char_data.name == "NOVA", "Fight(2): новый персонаж в слоте 0")
				check(f0.arena.x_min == 70.0, "Fight(2): арена додзё")
				step = 9
				frames = 0
		9:
			if fight.phase == "fight":
				check(true, "Fight(2): интро -> fight")
				hp_before = hp_total()
				step = 10
				frames = 0
			elif frames > 240:
				check(false, "Fight(2): фаза не перешла в fight")
				hp_before = hp_total()
				step = 10
				frames = 0
		10:
			if frames == 1:
				var g: Fighter = fight.fighters[1]
				fight.spawn_projectile(g, g.char_data.attacks.special)
				var live = 0
				for c in fight.get_children():
					if c is Projectile:
						proj = c
						live += 1
				check(live == 1, "Fight(2): снаряд стрелка")
				if proj != null:
					proj_x0 = proj.global_position.x
			elif frames >= 20:
				check(proj.global_position.x < proj_x0 - 50.0, "Fight(2): снаряд летит влево к игроку")
				var live = 0
				for c in fight.get_children():
					if c is Projectile:
						live += 1
				check(live <= 1, "Fight(2): снаряд жив и не дублируется")
				done = true

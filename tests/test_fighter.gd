class_name TestFighter
extends TestSuite
# Бойец без дерева сцены: урон, блок, неуязвимость, KO, комбо, окна hitbox, сброс.
# Узлы создаются кодом; всё, что требует земли (прыжок/спец-удар на земле),
# проверяется в smoke-сценарии на живой сцене.

func make_char(key: String) -> Array:
	var stub = FightStub.new()
	stub.arena = ArenaData.ARENAS["dojo"]
	var f = Fighter.new()
	f.setup(CharData.CHARS[key], 1, stub, null)
	return [stub, f]

func test_setup():
	var t = make_char("striker")
	var f: Fighter = t[1]
	check_eq(f.hp, f.max_hp, "setup: hp = max_hp")
	check_eq(f.max_hp, float(CharData.CHARS["striker"].hp), "setup: max_hp из конфига")
	check(f.sprite != null and f.hitbox != null and f.hurtbox != null, "setup: узлы созданы")
	check(f.arena.has("x_min"), "setup: арена получена от fight-узла")
	check_eq(f.state, "IDLE", "setup: стартовая стойка")
	t[0].free()
	f.free()

func test_take_hit():
	var t = make_char("striker")
	var f: Fighter = t[1]
	var before = f.hp
	f.take_hit(10.0, 1.0, 100.0, -100.0, 0.3, false)
	check_eq(f.hp, before - 10.0, "take_hit: снимает урон")
	check_eq(f.state, "HIT", "take_hit: обычный удар -> HIT")
	t[0].free()
	f.free()

func test_block_damage():
	var t = make_char("striker")
	var f: Fighter = t[1]
	f.state = "BLOCK"
	var before = f.hp
	f.take_hit(10.0, 1.0, 100.0, -100.0, 0.3, false)
	check_eq(f.hp, before - 1.5, "блок: урон x0.15")
	t[0].free()
	f.free()

func test_dash_invuln():
	var t = make_char("shadow")
	var f: Fighter = t[1]
	f.state = "DASH"
	f.invuln = f.dash_invuln
	var before = f.hp
	f.take_hit(10.0, -1.0, 100.0, -100.0, 0.3, true)
	check_eq(f.hp, before, "рывок с неуязвимостью: урон = 0")
	t[0].free()
	f.free()

func test_ko_and_signal():
	var t = make_char("striker")
	var f: Fighter = t[1]
	var died_count = [0]
	f.died.connect(func(): died_count[0] += 1)
	f.take_hit(999.0, 1.0, 100.0, -100.0, 0.3, true)
	check_eq(f.hp, 0.0, "KO: hp не уходит в минус")
	check_eq(f.state, "KO", "KO: состояние KO")
	check_eq(died_count[0], 1, "KO: сигнал died ровно раз")
	f.take_hit(10.0, 1.0, 0.0, 0.0, 0.2, false)
	check_eq(f.hp, 0.0, "KO: мёртвого бойца нельзя добить")
	t[0].free()
	f.free()

func test_heavy_off_balance():
	var t = make_char("striker")
	var f: Fighter = t[1]
	f.state = "LIGHT"
	f.attack = CharData.CHARS["striker"].attacks.light
	f.state_time = 0.1
	f.take_hit(10.0, 1.0, 200.0, -100.0, 0.3, true)
	check_eq(f.state, "BALANCE", "сильный удар по атакующему = потеря равновесия")
	t[0].free()
	f.free()

func test_combo_window():
	var t = make_char("striker")
	var f: Fighter = t[1]
	check(not f.start_attack("light2"), "light2 запрещён из нейтральной стойки")
	f.state = "LIGHT"
	f.combo_window = 0.25
	f.attack = CharData.CHARS["striker"].attacks.light
	check(f.start_attack("light2"), "light2 разрешён в окне комбо")
	check_eq(f.state, "LIGHT2", "переход в LIGHT2")
	t[0].free()
	f.free()

func test_special_cd_air_only():
	var t = make_char("acrobat")
	var f: Fighter = t[1]
	f.state = "JUMP"
	check(f.start_attack("special"), "acrobat: спец-удар в воздухе")
	check(f.special_cd > 0.0, "спец-удар задаёт кулдаун")
	check(not f.start_attack("special"), "второй спец-удар под кулдауном запрещён")
	t[0].free()
	f.free()

func test_hitbox_active_window():
	var t = make_char("striker")
	var f: Fighter = t[1]
	check(not f.hitbox_active(), "нейтральная стойка: hitbox выключен")
	f.start_attack("light")
	var a = CharData.CHARS["striker"].attacks.light
	check(not f.hitbox_active(), "startup: hitbox ещё закрыт")
	f.state_time = a.startup
	check(f.hitbox_active(), "окно active открыто")
	f.state_time = a.startup + a.active + 0.01
	check(not f.hitbox_active(), "после active hitbox закрыт")
	t[0].free()
	f.free()

func test_projectile_char_has_no_hitbox():
	var t = make_char("gunner")
	var f: Fighter = t[1]
	f.state = "SPECIAL"
	f.attack = CharData.CHARS["gunner"].attacks.special
	check(not f.hitbox_active(), "снаряд: hitbox бойца не активен")
	t[0].free()
	f.free()

func test_crouch_hurtbox():
	var t = make_char("striker")
	var f: Fighter = t[1]
	f.enter_state("CROUCH")
	check_eq(f.hurt_shape.shape.size, Vector2(46, 40), "присед: укороченный hurtbox")
	f.enter_state("IDLE")
	check_eq(f.hurt_shape.shape.size, Vector2(46, 78), "стойка: полный hurtbox")
	t[0].free()
	f.free()

func test_reset():
	var t = make_char("striker")
	var f: Fighter = t[1]
	f.take_hit(20.0, 1.0, 0.0, 0.0, 0.2, false)
	f.special_cd = 1.0
	f.reset(Vector2(300, 620), -1)
	check_eq(f.hp, f.max_hp, "reset: hp восстановлен")
	check_eq(f.position, Vector2(300, 620), "reset: позиция")
	check_eq(f.facing, -1.0, "reset: фэйсинг")
	check_eq(f.state, "IDLE", "reset: стойка")
	check_eq(f.special_cd, 0.0, "reset: кулдауны обнулены")
	t[0].free()
	f.free()

func test_nearest_foe():
	var stub = FightStub.new()
	stub.arena = ArenaData.ARENAS["dojo"]
	var a = Fighter.new()
	var b = Fighter.new()
	var c = Fighter.new()
	a.setup(CharData.CHARS["striker"], 1, stub, null)
	b.setup(CharData.CHARS["bruiser"], -1, stub, null)
	c.setup(CharData.CHARS["mage"], 1, stub, null)
	a.position = Vector2(100, 620)
	b.position = Vector2(900, 620)
	c.position = Vector2(300, 620)
	stub.fighters = [a, b, c]
	check_eq(a.nearest_foe(), c, "nearest_foe: ближайший живой")
	c.hp = 0.0
	check_eq(a.nearest_foe(), b, "nearest_foe: мёртвый не цель")
	stub.free()
	a.free()
	b.free()
	c.free()

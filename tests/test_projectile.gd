class_name TestProjectile
extends TestSuite
# Снаряд: движение, время жизни, границы арены, урон при попадании.
# Узлы вне дерева сцены, физика вызывается вручную — детерминированный тест.

func make_shot(char_key: String) -> Array:
	var stub = FightStub.new()
	stub.arena = ArenaData.ARENAS["dojo"]
	var owner = Fighter.new()
	owner.setup(CharData.CHARS[char_key], 1, stub, null)
	owner.position = Vector2(200, 620)
	stub.fighters = [owner]
	var p = Projectile.new()
	var a = CharData.CHARS[char_key].attacks.special
	p.setup(stub, owner, 1.0, a.dmg, a.proj_speed, owner.char_data.color)
	p.global_position = owner.global_position + Vector2(60.0, -44.0)
	return [stub, owner, p]

func test_moves_and_bounds():
	var t = make_shot("gunner")
	var p: Projectile = t[2]
	var x0 = p.global_position.x
	p._physics_process(0.1)
	check(p.global_position.x > x0, "снаряд летит по направлению")
	check(p.life < 1.4, "life уменьшается")
	check(not p.is_queued_for_deletion(), "внутри арены снаряд жив")
	p.global_position.x = ArenaData.ARENAS["dojo"].proj_max + 1.0
	p._physics_process(0.1)
	check(p.is_queued_for_deletion(), "за границей арены удаляется")
	t[0].free()
	p.free()

func test_life_expiry():
	var t = make_shot("mage")
	var p: Projectile = t[2]
	var guard = 0
	while p.life > 0.0 and not p.is_queued_for_deletion() and guard < 100:
		p._physics_process(0.05)
		guard += 1
	check(p.is_queued_for_deletion(), "исчерпал life -> удаление")
	t[0].free()
	p.free()

func test_on_hit_damage():
	var t = make_shot("gunner")
	var stub: FightStub = t[0]
	var owner: Fighter = t[1]
	var p: Projectile = t[2]
	var victim = Fighter.new()
	victim.setup(CharData.CHARS["striker"], -1, stub, null)
	victim.position = Vector2(600, 620)
	stub.fighters = [owner, victim]
	var before = victim.hp
	p._on_hit(victim.hurtbox)
	check_eq(victim.hp, before - p.dmg, "снаряд наносит dmg")
	check(p.done, "done-флаг после попадания")
	check_eq(stub.shakes.size(), 1, "shake после попадания")
	stub.free()
	p.free()
	victim.free()

func test_on_hit_owner_ignored():
	var t = make_shot("mage")
	var p: Projectile = t[2]
	p._on_hit(p.owner_fighter.hurtbox)
	check(p.is_queued_for_deletion(), "свой hurtbox игнорируется")
	t[0].free()
	p.free()

class_name BotAI
extends RefCounted
# Контроллер бота для одного бойца. Работает с любым бойцом и любым числом врагов:
# цель — ближайший живой боец, параметры агрессии берутся из словаря сложности.

var fight: Node
var b: Fighter
var diff: Dictionary

var ai_timer := 0.0
var ai_block := 0.0
var ai_retreat := 0.0
var ai_dir := 0.0
var atk_cd := 0.0

func init(fight_node: Node, bot: Fighter, d: Dictionary):
	fight = fight_node
	b = bot
	diff = d

func nearest_foe() -> Fighter:
	var best: Fighter = null
	var best_d := 1e20
	for o in fight.fighters:
		if o == b:
			continue
		if o.hp <= 0.0:
			continue
		var d2 = b.global_position.distance_squared_to(o.global_position)
		if d2 < best_d:
			best_d = d2
			best = o
	return best

func process(delta: float):
	if b.state == "KO":
		return
	# одноразовые флаги сбрасываем каждый кадр (тик выставит их при необходимости)
	b.ext_jump = false
	b.ext_dash = false
	atk_cd -= delta
	ai_block -= delta
	ai_retreat -= delta
	ai_timer -= delta
	var f = nearest_foe()
	if f == null:
		return
	var dist = abs(b.global_position.x - f.global_position.x)
	var toward = 1.0 if f.global_position.x > b.global_position.x else -1.0

	if ai_timer <= 0.0:
		ai_timer = diff.react
		# угроза: противник замахивается или летит в воздух рядом
		var threat = (f.attacking() and dist < 200.0)
		if not f.is_on_floor() and dist < 200.0:
			threat = true
		if threat and randf() < diff.block_p:
			ai_block = 0.30
			ai_dir = 0.0
		elif dist > 120.0:
			if b.dash_cd <= 0.0 and randf() < diff.dash_p:
				b.ext_dash = true
			ai_dir = toward
			if randf() < diff.jump_p:
				b.ext_jump = true
		else:
			if b.can_act() and atk_cd <= 0.0 and randf() < diff.aggr:
				atk_cd = diff.cooldown
				var r = randf()
				if b.special_cd <= 0.0 and randf() < diff.special_p:
					var sp = b.char_data.attacks.get("special", {})
					# снаряд запускаем на дистанции
					if sp.get("projectile", false) and dist > 80.0:
						b.ext_attacks.append(["special", fight.clock])
					elif sp.get("air_only", false):
						if not b.is_on_floor():
							b.ext_attacks.append(["special", fight.clock])
						elif randf() < diff.jump_p:
							b.ext_jump = true
					else:
						b.ext_attacks.append(["special", fight.clock])
				elif r < 0.55:
					b.ext_attacks.append(["light", fight.clock])
					if randf() < diff.combo_p:
						b.ext_attacks.append(["light2", fight.clock])
						if randf() < diff.combo_p:
							b.ext_attacks.append(["heavy", fight.clock])
				elif r < 0.85:
					b.ext_attacks.append(["heavy" if b.is_on_floor() else "air", fight.clock])
				else:
					if dist > 70.0 and b.is_on_floor():
						b.ext_jump = true
			elif randf() < 0.15:
				ai_retreat = 0.35

	# непрерывное движение
	if ai_block > 0.0:
		b.ext_block = true
		b.ext_dir = 0.0
	else:
		b.ext_block = false
		if ai_retreat > 0.0:
			b.ext_dir = -toward
		elif ai_dir != 0.0:
			b.ext_dir = ai_dir
		ai_dir = 0.0
		if abs(b.ext_dir) < 0.01:
			if dist > 110.0:
				b.ext_dir = toward
			elif dist < 55.0:
				b.ext_dir = -toward * 0.6

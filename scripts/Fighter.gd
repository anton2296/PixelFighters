extends CharacterBody2D
class_name Fighter
# Базовый боец: движение, прыжки, рывок, блок, удары, хитбоксы, получение урона.

const GRAVITY := 2200.0

signal hp_changed()
signal died()

var char_data: Dictionary
var fight: Node
var foe: Fighter
var facing := 1.0
var hp := 100.0
var max_hp := 100.0
var state := "IDLE"
var state_time := 0.0
var attack: Dictionary
var has_hit := false
var combo_window := 0.0
var special_cd := 0.0
var dash_cd := 0.0
var invuln := 0.0
var flash := 0.0
var land_timer := 0.0
var jumps_used := 0
var stun_time := 0.0
var control_enabled := true
var launched := false
var balance_dir := 0.0

# Внешние управляющие флаги (игрок или ИИ)
var ext_dir := 0.0
var ext_block := false
var ext_jump := false
var ext_dash := false
var ext_attacks: Array = []

var sprite: AnimatedSprite2D
var hitbox: Area2D
var hit_shape: CollisionShape2D
var hurtbox: Area2D
var hurt_shape: CollisionShape2D

var speed := 200.0
var jump_v := -680.0
var jump_dj := -560.0
var jump_launch := 0.0
var dash_speed := 400.0
var dash_dur := 0.2
var dash_dir := 1.0
var dash_invuln := 0.0

var anims: Dictionary
# конфиг арены (границы) — источник истины один: ArenaData, через Fight.arena
var arena: Dictionary = {}
var slam_active := false
var slam_time := 0.0
var projectile_fired := false
# оверлей ударной волны TITAN (кадры f10/f11 Ground_Slam.png — только эффект)
var wave_fx: Sprite2D
var wave_frame_big: AtlasTexture
var wave_frame_small: AtlasTexture

func setup(data: Dictionary, start_facing: int, fight_node: Node, enemy: Fighter):
	char_data = data
	facing = start_facing
	fight = fight_node
	foe = enemy
	if fight_node != null and fight_node.get("arena") != null:
		arena = fight_node.arena
	max_hp = float(data.hp)
	hp = max_hp
	speed = float(data.speed)
	jump_v = float(data.jump)
	jump_dj = float(data.jump_dj)
	jump_launch = float(data.get("jump_launch", 0.0))
	dash_speed = float(data.dash_speed)
	dash_dur = float(data.dash_dur)
	dash_invuln = float(data.dash_invuln)
	anims = CharData.COMMON_ANIM.duplicate(true)
	for k in char_data.anim:
		anims[k] = char_data.anim[k]

	# слой 4 = тело бойца: не проходимы друг для друга; сталкиваются со стенами (1)
	collision_layer = 4
	collision_mask = 5

	sprite = AnimatedSprite2D.new()
	sprite.position = Vector2(0, -64)
	sprite.sprite_frames = build_frames()
	add_child(sprite)
	sprite.play("idle")
	sprite.modulate = char_data.color

	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.height = 76.0
	cap.radius = 22.0
	cs.shape = cap
	cs.position = Vector2(0, -38)
	add_child(cs)

	hurtbox = Area2D.new()
	hurtbox.collision_layer = 2
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurt_shape = CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(46, 78)
	hurt_shape.shape = hr
	hurt_shape.position = Vector2(0, -40)
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.monitoring = false
	hitbox.monitorable = false
	hit_shape = CollisionShape2D.new()
	var rh := RectangleShape2D.new()
	rh.size = Vector2(40, 18)
	hit_shape.shape = rh
	hitbox.add_child(hit_shape)
	add_child(hitbox)
	hitbox.area_entered.connect(_on_hitbox_hit)

	# оверлей волны: кадр без персонажа, рисуется поверх тела при ударе о землю
	var slam_tex = load("res://assets/Anim/Ground_Slam.png")
	wave_frame_big = AtlasTexture.new()
	wave_frame_big.atlas = slam_tex
	wave_frame_big.region = Rect2(10 * 128.0, 0.0, 128.0, 128.0)
	wave_frame_small = AtlasTexture.new()
	wave_frame_small.atlas = slam_tex
	wave_frame_small.region = Rect2(11 * 128.0, 0.0, 128.0, 128.0)
	wave_fx = Sprite2D.new()
	wave_fx.centered = false
	wave_fx.position = Vector2(-64.0, -128.0)
	wave_fx.z_index = 1
	wave_fx.texture = wave_frame_big
	wave_fx.visible = false
	add_child(wave_fx)

	add_to_group("fighters")

func build_frames() -> SpriteFrames:
	var fr := SpriteFrames.new()
	for key in anims:
		var def = anims[key]
		var tex = load(CharData.ANIM_DIR + def[0])
		var count = int(tex.get_width() / 128.0)
		if def.size() >= 4:
			count = def[3]
		if key == "idle":
			count = 1
		if not fr.has_animation(key):
			fr.add_animation(key)
		for i in range(count):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(float(i) * 128.0, 0.0, 128.0, 128.0)
			fr.add_frame(key, at, 1.0)
		fr.set_animation_speed(key, def[1])
		fr.set_animation_loop(key, def[2])
	return fr

func attacking() -> bool:
	return state in ["LIGHT", "LIGHT2", "HEAVY", "AIR", "AIRLIGHT", "SPECIAL", "CROUCHATK"]

func can_act() -> bool:
	return control_enabled and state in ["IDLE", "WALK", "BLOCK", "CROUCH", "JUMP", "FALL", "LANDING"]

func _physics_process(delta: float):
	state_time += delta
	combo_window = maxf(0.0, combo_window - delta)
	special_cd = maxf(0.0, special_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	land_timer = maxf(0.0, land_timer - delta)
	if flash > 0.0:
		flash -= delta
		sprite.modulate = Color(2.5, 2.5, 2.5)
	else:
		sprite.modulate = char_data.color

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	handle_state(delta)

	move_and_slide()

	# цель — ближайший живой боец (работает при любом числе участников)
	if fight != null and fight.get("fighters") != null:
		foe = nearest_foe()
	# автоповорот к противнику в нейтральных состояниях
	if control_enabled and state in ["IDLE", "WALK", "BLOCK", "CROUCH"] and foe != null:
		facing = 1.0 if foe.global_position.x > global_position.x else -1.0
	sprite.flip_h = facing < 0.0

	# границы арены из конфига (позиция относительно корня сцены)
	if arena.is_empty():
		position.x = clampf(position.x, 70.0, 1210.0)
	else:
		position.x = clampf(position.x, arena.x_min, arena.x_max)

	update_hitbox()

func nearest_foe() -> Fighter:
	var best: Fighter = null
	var best_d := 1e20
	for o in fight.fighters:
		if o == self:
			continue
		if o.hp <= 0.0:
			continue
		var d2 = global_position.distance_squared_to(o.global_position)
		if d2 < best_d:
			best_d = d2
			best = o
	return best

func handle_state(delta: float):
	match state:
		"IDLE", "WALK":
			if control_enabled:
				try_inputs(delta)
			if not is_on_floor():
				enter_state("FALL")
		"JUMP":
			if control_enabled:
				try_inputs(delta)
			if is_on_floor() and not launched:
				# медленный старт прыжка (TITAN): первые кадры на земле
				velocity.x = ext_dir * speed * 0.6
				if state_time >= jump_launch:
					launched = true
					velocity.y = jump_v
			elif not is_on_floor():
				if control_enabled:
					velocity.x = ext_dir * speed * 0.8
				if launched:
					if sprite.animation == "jump" and sprite.frame >= 5.0 and sprite.is_playing():
						sprite.pause()
					if velocity.y > 0.0:
						enter_state("FALL")
		"FALL":
			if control_enabled:
				try_inputs(delta)
				velocity.x = ext_dir * speed * 0.8
			if is_on_floor() and velocity.y >= 0.0:
				enter_state("LANDING")
				velocity.x *= 0.3
				jumps_used = 0
		"LANDING":
			velocity.x *= 0.85
			if control_enabled:
				try_inputs(delta)
			if land_timer <= 0.0:
				enter_state("IDLE")
		"DASH":
			velocity.x = dash_dir * dash_speed
			if is_on_floor() and state_time >= dash_dur:
				enter_state("IDLE")
			elif not is_on_floor():
				enter_state("FALL")
		"BLOCK":
			# авто-защитная стойка: бездействие = блок
			velocity.x = 0.0
			if not is_on_floor():
				enter_state("FALL")
			elif sprite.animation == "block_hit" and not sprite.is_playing():
				# анимация успешного блокирования закончилась — возвращаемся в стойку
				sprite.play("block")
			elif ext_block:
				enter_state("CROUCH")
			elif control_enabled:
				try_inputs(delta)
		"CROUCH":
			# присед: низкая стойкость, высокие удары пролетают над головой
			velocity.x = 0.0
			if not is_on_floor():
				enter_state("FALL")
			elif not ext_block:
				enter_state("IDLE")
			elif control_enabled:
				try_inputs(delta)
		"LIGHT", "LIGHT2", "HEAVY", "AIR", "AIRLIGHT", "SPECIAL", "CROUCHATK":
			attack_phase(delta)
		"HIT":
			if is_on_floor():
				velocity.x *= 0.8
			if state_time >= stun_time:
				if is_on_floor():
					enter_state("IDLE")
				else:
					enter_state("FALL")
		"BALANCE":
			# потеря равновесия: кувыркаемся, управления нет
			if is_on_floor():
				velocity.x *= 0.85
			sprite.rotation = balance_dir * 0.3 * clampf(1.0 - state_time / maxf(stun_time, 0.01), 0.0, 1.0)
			if state_time >= stun_time:
				if is_on_floor():
					enter_state("GETUP")
				else:
					enter_state("FALL")
		"GETUP":
			# вставание после падения
			velocity.x = 0.0
			if not is_on_floor():
				enter_state("FALL")
			elif state_time >= 0.55:
				enter_state("LANDING")
		"KO":
			if is_on_floor():
				velocity.x *= 0.85
			# анимация ko сама доводит бойца до лёжа, поворот не нужен
			sprite.rotation = lerpf(sprite.rotation, 0.0, 6.0 * delta)
			sprite.position.y = lerpf(sprite.position.y, -40.0, 4.0 * delta)

func try_inputs(delta: float):
	# клавиша «вниз» = присед
	if ext_block and is_on_floor() and state in ["IDLE", "WALK", "LANDING", "BLOCK"]:
		enter_state("CROUCH")
		velocity.x = 0.0
		return
	# атаки из очереди [название, время]: устаревшие (>0.3с) выбрасываем,
	# первую неудачную оставляем в очереди (для комбо)
	while ext_attacks.size() > 0:
		var e = ext_attacks[0]
		if fight != null and fight.clock - float(e[1]) > 0.30:
			ext_attacks.pop_front()
			continue
		var t = e[0]
		if t == "light":
			if not is_on_floor():
				t = "airlight"
			elif state == "CROUCH":
				t = "crouch"
		if start_attack(t):
			ext_attacks.pop_front()
			return
		break
	# прыжок
	if ext_jump:
		if is_on_floor() and state in ["IDLE", "WALK", "LANDING", "BLOCK"]:
			jumps_used = 1
			velocity.x = ext_dir * speed * 0.6
			if jump_launch <= 0.0:
				launched = true
				velocity.y = jump_v
			else:
				launched = false
			enter_state("JUMP")
			return
		elif not is_on_floor() and char_data.double_jump and jumps_used < 2 and state in ["JUMP", "FALL"]:
			jumps_used += 1
			velocity.y = jump_dj
			sprite.play("double_jump")
			return
	# рывок
	if ext_dash and is_on_floor() and dash_cd <= 0.0 and state in ["IDLE", "WALK", "LANDING", "BLOCK"]:
		dash_dir = ext_dir if ext_dir != 0.0 else facing
		dash_cd = 0.5
		invuln = dash_invuln
		enter_state("DASH")
		return
	# ходьба
	if control_enabled:
		if ext_dir != 0.0 and is_on_floor() and state != "CROUCH":
			velocity.x = ext_dir * speed
			if state != "WALK":
				enter_state("WALK")
			var want = "run" if abs(velocity.x) >= speed * 0.95 else "walk"
			if sprite.animation != want:
				sprite.play(want)
		elif is_on_floor():
			velocity.x = 0.0
			if state == "WALK":
				enter_state("IDLE")
		# авто-блок: персонаж бездействует = защитная стойка
		if ext_dir == 0.0 and ext_attacks.size() == 0 and not ext_jump and not ext_dash and not ext_block and is_on_floor() and state in ["IDLE", "WALK", "LANDING"]:
			enter_state("BLOCK")

func start_attack(t) -> bool:
	if not control_enabled:
		return false
	if not t in char_data.attacks:
		return false
	var a = char_data.attacks[t]
	if t == "special" and special_cd > 0.0:
		return false
	if t == "special" and a.get("air_only", false) and is_on_floor():
		return false
	if t == "special" and not a.get("air_only", false) and not is_on_floor():
		return false
	if t == "air" or t == "airlight":
		if is_on_floor() or not state in ["JUMP", "FALL", "BALANCE"]:
			return false
	elif t == "light2":
		if not (state == "LIGHT" and combo_window > 0.0):
			return false
	elif t == "heavy":
		if not (state in ["IDLE", "WALK", "LANDING", "BLOCK"]) and not (state in ["LIGHT", "LIGHT2"] and combo_window > 0.0):
			return false
	elif t == "light":
		if not state in ["IDLE", "WALK", "LANDING", "BLOCK"]:
			return false
	elif t == "crouch":
		if state != "CROUCH":
			return false
	elif t == "special":
		if a.get("air_only", false):
			if is_on_floor() or not state in ["JUMP", "FALL", "BALANCE"]:
				return false
		elif not is_on_floor() or not state in ["IDLE", "WALK", "LANDING", "BLOCK"]:
			return false
	# запуск
	attack = a
	has_hit = false
	projectile_fired = false
	slam_active = false
	slam_time = 0.0
	if t == "special" and a.get("slam", false):
		velocity = Vector2(facing * 240.0, -700.0)
	elif t == "crouch":
		velocity.x = facing * 140.0
	elif t == "special":
		velocity.x = 0.0
	else:
		velocity.x = facing * 30.0
	if t == "special":
		special_cd = char_data.special_cd
	var st_name = t.to_upper()
	if t == "crouch":
		st_name = "CROUCHATK"
	if t == "special" and a.get("air_only", false):
		st_name = "SPECIAL"
	enter_state(st_name)
	return true

func attack_phase(delta: float):
	var a = attack
	var total = a.startup + a.active + a.recovery
	if a.get("slam", false):
		velocity.x = facing * 240.0
		if not slam_active:
			if is_on_floor() and state_time > 0.25:
				slam_active = true
				slam_time = 0.0
				fight.shake(0.4)
		else:
			slam_time += delta
			velocity.x = 0.0
			# показываем ударную волну поверх персонажа
			wave_fx.visible = true
			wave_fx.flip_h = facing < 0.0
			wave_fx.texture = wave_frame_small if slam_time > a.active else wave_frame_big
			if slam_time > a.active + a.recovery:
				enter_state("IDLE")
	elif a.get("projectile", false):
		velocity.x = facing * 40.0
		if not projectile_fired and state_time >= a.startup:
			projectile_fired = true
			fight.spawn_projectile(self, a)
		if state_time >= total:
			enter_state("IDLE" if is_on_floor() else "FALL")
	else:
		if state_time < a.startup:
			velocity.x = facing * 30.0
		elif state_time < a.startup + a.active:
			velocity.x = facing * a.get("move_x", 0)
			if a.get("move_x", 0) == 0:
				velocity.x = facing * 70.0
		else:
			velocity.x *= 0.6
		if state_time >= total:
			enter_state("IDLE" if is_on_floor() else "FALL")

func enter_state(s: String):
	state = s
	state_time = 0.0
	if s != "SPECIAL":
		wave_fx.visible = false
	hitbox.set_deferred("monitoring", false)
	if s == "LANDING":
		land_timer = 0.15
	if s == "CROUCH" or s == "CROUCHATK":
		hurt_shape.shape.size = Vector2(46, 40)
		hurt_shape.position = Vector2(0, -20)
	else:
		hurt_shape.shape.size = Vector2(46, 78)
		hurt_shape.position = Vector2(0, -40)
	if s != "KO" and s != "BALANCE":
		sprite.rotation = 0.0
	var want = state_anim()
	if want != "" and sprite.animation != want:
		sprite.play(want)
	if s == "JUMP":
		sprite.frame = 0
		sprite.play()
	if s == "CROUCH":
		# присед проигрывается один раз и замирает на последнем кадре
		sprite.frame = 0
		sprite.play()
	if attacking():
		var a = attack
		hit_shape.shape.size = Vector2(maxf(a.reach, 10.0), maxf(a.hit_h, 10.0))
		hit_shape.position = Vector2(facing * (26.0 + a.reach / 2.0), a.hit_y)

func state_anim() -> String:
	match state:
		"IDLE": return "idle"
		"WALK": return "run" if abs(velocity.x) > speed * 0.95 else "walk"
		"DASH": return "dash" if anims.has("dash") else "run"
		"JUMP": return "jump"
		"FALL": return "fall"
		"LANDING": return "landing"
		"BLOCK": return "block"
		"CROUCH": return "crouch"
		"CROUCHATK": return "crouch_attack"
		"BALANCE": return "fall"
		"GETUP": return "getup"
		"HIT": return "hurt"
		"KO": return "ko"
		"LIGHT": return "light"
		"LIGHT2": return "light2"
		"HEAVY": return "heavy"
		"AIR": return "air"
		"AIRLIGHT": return "airlight"
		"SPECIAL": return "special"
	return ""

# чистая логика активности hitbox'а — тестируется без дерева сцены
func hitbox_active() -> bool:
	if state in ["LIGHT", "LIGHT2", "HEAVY", "AIR", "AIRLIGHT", "SPECIAL", "CROUCHATK"]:
		var a = attack
		if a.get("projectile", false):
			return false
		if a.get("slam", false):
			return slam_active and slam_time <= a.active
		return state_time >= a.startup and state_time <= a.startup + a.active
	return false

func update_hitbox():
	var active = hitbox_active()
	if state in ["LIGHT", "LIGHT2", "HEAVY", "AIR", "AIRLIGHT", "SPECIAL", "CROUCHATK"] and attack.get("slam", false) and active:
		hit_shape.shape.size = Vector2(attack.reach, maxf(attack.hit_h, 10.0))
		hit_shape.position = Vector2(0.0, attack.hit_y)
	if hitbox.monitoring != active:
		hitbox.set_deferred("monitoring", active)

func _on_hitbox_hit(area: Area2D):
	if not hitbox.monitoring or has_hit:
		return
	if area == hurtbox:
		return
	if area.get_parent() == self:
		return
	var victim = area.get_parent()
	if victim == null or not victim is Fighter:
		return
	has_hit = true
	var a = attack
	var dir = 1.0 if victim.global_position.x > global_position.x else -1.0
	victim.take_hit(a.dmg, dir, a.kb, a.kb_y, a.stun, a.get("heavy", false))
	if a.get("heavy", false) or a.get("slam", false):
		fight.shake(0.25)
	if state in ["LIGHT", "LIGHT2"]:
		combo_window = 0.25

func take_hit(dmg: float, dir: float, kb: float, kb_y: float, stun: float, heavy: bool):
	if state == "KO":
		return
	if invuln > 0.0:
		return
	if state == "BLOCK":
		dmg *= 0.15
		velocity.x = dir * kb * 0.4
		hp = maxf(0.0, hp - dmg)
		state_time = 0.0
		sprite.play("block_hit")
	else:
		# сильный удар во время прыжка, атаки или рывка = потеря равновесия
		var off_balance = heavy and (not is_on_floor() or attacking() or state == "DASH")
		if off_balance:
			stun_time = stun * 1.3
			balance_dir = dir
			enter_state("BALANCE")
			velocity.x = dir * kb
			velocity.y = minf(velocity.y, kb_y * 0.7)
		else:
			stun_time = stun
			enter_state("HIT")
			velocity.x = dir * kb
			if heavy:
				velocity.y = minf(velocity.y, kb_y)
		hp = maxf(0.0, hp - dmg)
	flash = 0.06
	hp_changed.emit()
	if hp <= 0.0:
		enter_state("KO")
		velocity = Vector2(dir * 320.0, -250.0)
		died.emit()

func reset(pos: Vector2, face: int):
	hp = max_hp
	position = pos
	velocity = Vector2.ZERO
	facing = face
	state = "IDLE"
	state_time = 0.0
	combo_window = 0.0
	special_cd = 0.0
	dash_cd = 0.0
	invuln = 0.0
	flash = 0.0
	land_timer = 0.0
	jumps_used = 0
	launched = false
	balance_dir = 0.0
	slam_active = false
	slam_time = 0.0
	projectile_fired = false
	attack = {}
	ext_attacks.clear()
	ext_dir = 0.0
	ext_block = false
	ext_jump = false
	ext_dash = false
	sprite.rotation = 0.0
	hurt_shape.shape.size = Vector2(46, 78)
	hurt_shape.position = Vector2(0, -40)
	sprite.position = Vector2(0, -64)
	sprite.modulate = char_data.color
	hitbox.set_deferred("monitoring", false)
	sprite.play("idle")
	hp_changed.emit()

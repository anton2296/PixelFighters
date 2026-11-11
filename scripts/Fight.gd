extends Node2D
# Боевая сцена: арена из конфига ArenaData, произвольное число бойцов, HUD под N участников,
# раунды (best of 3), ввод человека и бот на каждого не-игрока.

const WINS_NEEDED := 2
const ROUND_TIME := 99.0

const DIFFS = [
	{ "react": 0.45, "block_p": 0.12, "aggr": 0.35, "cooldown": 0.85, "dash_p": 0.06, "jump_p": 0.03, "special_p": 0.10, "combo_p": 0.0 },
	{ "react": 0.20, "block_p": 0.40, "aggr": 0.55, "cooldown": 0.50, "dash_p": 0.15, "jump_p": 0.08, "special_p": 0.30, "combo_p": 0.35 },
	{ "react": 0.09, "block_p": 0.65, "aggr": 0.70, "cooldown": 0.30, "dash_p": 0.22, "jump_p": 0.14, "special_p": 0.45, "combo_p": 0.60 },
]

var fighters: Array = []
var bots: Array = []   # BotAI или null (человек) — по индексу бойца
var arena: Dictionary

var hud: CanvasLayer
var fills: Array = []
var bar_w := 0.0
var mirrored := 1
var name_labels: Array = []
var pip_labels: Array = []
var timer_label: Label
var msg: Label
var hint: Label
var pause_root: Control

var phase := "intro"
var phase_time := 0.0
var round_num := 1
var wins: Array = []
var round_time := ROUND_TIME
var disp_hp: Array = []
var shake_t := 0.0
var slowmo_real := 0.0
var over_winner := -1
var time_over_flag := false
var diff: Dictionary
var key_prev := {}
var clock := 0.0
var pending_keys: Array = []

var P1_KEYS := { "left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "light": KEY_J, "heavy": KEY_K, "special": KEY_L, "dash": KEY_SHIFT }
var P2_KEYS := { "left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "light": KEY_1, "heavy": KEY_2, "special": KEY_3, "dash": KEY_CTRL }
# в _ready эти карты перезаписываются настройками из GameState

# GameState: Engine-синглтон (тесты) или узел автозагрузки /root/GameState (игра).
func gs() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return get_node("/root/GameState")

func _ready():
	P1_KEYS = gs().p1_keys.duplicate()
	P2_KEYS = gs().p2_keys.duplicate()
	diff = DIFFS[clampi(gs().difficulty, 0, 2)]
	arena = ArenaData.get_arena(gs().arena_id)
	var chars = gs().get_match_chars()
	ArenaData.build(self, arena)
	for i in range(chars.size()):
		var f = Fighter.new()
		add_child(f)
		fighters.append(f)
		f.setup(CharData.CHARS[chars[i]], 1 if i == 0 else -1, self, null)
		f.hp_changed.connect(_on_hp)
	for i in range(chars.size()):
		if is_bot_slot(i):
			var ai = BotAI.new()
			ai.init(self, fighters[i], diff)
			bots.append(ai)
		else:
			bots.append(null)
	for i in range(chars.size()):
		wins.append(0)
	build_hud()
	build_pause_menu()
	start_round()

func is_bot_slot(i: int) -> bool:
	if i == 0:
		return false
	if i == 1:
		return gs().p2_is_bot
	return true

func hps() -> Array:
	var out: Array = []
	for f in fighters:
		out.append(f.hp)
	return out

func announce(text: String, big: float):
	msg.text = text
	msg.scale = Vector2(big, big)
	var tw := create_tween()
	tw.tween_property(msg, "scale", Vector2(1, 1), 0.25)

func build_hud():
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var n = fighters.size()
	var gap := 40.0
	bar_w = (1280.0 - (n + 1) * gap) / float(n)
	mirrored = int(ceil(n / 2.0))
	for i in range(n):
		var x = gap + i * (bar_w + gap)
		var bg := ColorRect.new()
		bg.color = Color(0.1, 0.1, 0.12, 0.9)
		bg.position = Vector2(x, 30)
		bg.size = Vector2(bar_w, 34)
		root.add_child(bg)
		var fill := ColorRect.new()
		fill.color = Color(0.35, 0.85, 0.45)
		fill.position = Vector2(4, 4)
		fill.size = Vector2(bar_w - 8.0, 26)
		bg.add_child(fill)
		fills.append(fill)
		var d = fighters[i].char_data
		var lbl := Label.new()
		lbl.text = d.name + (" (БОТ)" if bots[i] != null else "")
		lbl.add_theme_font_size_override("font_size", 26 if n <= 2 else 18)
		lbl.add_theme_color_override("font_color", d.color)
		lbl.position = Vector2(x, 66)
		lbl.size = Vector2(bar_w, 28)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i >= mirrored else HORIZONTAL_ALIGNMENT_LEFT
		root.add_child(lbl)
		name_labels.append(lbl)
		var pip := Label.new()
		pip.add_theme_font_size_override("font_size", 24)
		pip.position = Vector2(x, 96)
		pip.size = Vector2(bar_w, 30)
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i >= mirrored else HORIZONTAL_ALIGNMENT_LEFT
		root.add_child(pip)
		pip_labels.append(pip)

	timer_label = Label.new()
	timer_label.text = str(int(ROUND_TIME))
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	if n <= 2:
		timer_label.position = Vector2(590, 20)
		timer_label.size = Vector2(100, 60)
	else:
		timer_label.position = Vector2(0, 130)
		timer_label.size = Vector2(1280, 40)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(timer_label)

	msg = Label.new()
	msg.add_theme_font_size_override("font_size", 84)
	msg.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	msg.position = Vector2(0, 260)
	msg.size = Vector2(1280, 140)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.pivot_offset = Vector2(640, 70)
	root.add_child(msg)

	hint = Label.new()
	hint.text = "Enter — меню   •   R — заново   •   Esc — меню"
	hint.add_theme_font_size_override("font_size", 24)
	hint.position = Vector2(0, 650)
	hint.size = Vector2(1280, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.visible = false
	root.add_child(hint)

func _on_hp():
	pass

func start_round():
	phase = "intro"
	phase_time = 0.0
	round_time = ROUND_TIME
	var spawns = ArenaData.spawn_positions(arena, fighters.size())
	for i in range(fighters.size()):
		fighters[i].reset(spawns[i], 1 if i == 0 else -1)
		fighters[i].control_enabled = false
	disp_hp = []
	for f in fighters:
		disp_hp.append(f.hp)
	msg.visible = true
	hint.visible = false
	announce("РАУНД " + str(round_num), 1.3)
	timer_label.text = str(int(round_time))

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		pending_keys.append(event.physical_keycode)

func _process(delta: float):
	clock += delta
	var real = delta / Engine.time_scale
	# тряска
	if shake_t > 0.0:
		shake_t -= delta
		position.x = randf_range(-8.0, 8.0) * minf(shake_t * 4.0, 1.0)
		position.y = randf_range(-6.0, 6.0) * minf(shake_t * 4.0, 1.0)
	elif position.x != 0.0 or position.y != 0.0:
		position = Vector2.ZERO
	# HUD
	for i in range(fighters.size()):
		var f = fighters[i]
		disp_hp[i] = lerpf(disp_hp[i], f.hp, 8.0 * delta)
		var r = disp_hp[i] / f.max_hp
		var fill = fills[i]
		fill.size = Vector2((bar_w - 8.0) * r, 26.0)
		if i >= mirrored:
			fill.position = Vector2(4.0 + (bar_w - 8.0) * (1.0 - r), 4.0)
		fill.color = hp_color(r)
		pip_labels[i].text = pips(wins[i])

	match phase:
		"intro":
			phase_time += delta
			if phase_time > 0.9 and msg.text != "В БОЙ!":
				announce("В БОЙ!", 1.3)
			if phase_time > 1.6:
				phase = "fight"
				msg.text = ""
				for f in fighters:
					f.control_enabled = true
		"fight":
			if edge(KEY_ESCAPE):
				enter_pause()
			round_time -= delta
			timer_label.text = str(maxi(0, int(round_time)))
			var h = hps()
			var alive = 0
			for v in h:
				if v > 0.0:
					alive += 1
			if alive <= 1:
				phase = "over"
				phase_time = 0.0
				time_over_flag = false
				announce("K.O.!", 1.6)
				Engine.time_scale = 0.25
				slowmo_real = 0.0
				for f in fighters:
					f.control_enabled = false
			elif round_time <= 0.0:
				phase = "over"
				phase_time = 0.0
				time_over_flag = true
				announce("ВРЕМЯ!", 1.4)
				over_winner = RoundRules.resolve(h)
				for f in fighters:
					f.control_enabled = false
		"pause":
			if edge(KEY_ESCAPE):
				resume_game()
		"over":
			slowmo_real += real
			if slowmo_real > 0.8 and Engine.time_scale < 1.0:
				Engine.time_scale = 1.0
			phase_time += real
			if phase_time > 2.2:
				var w = over_winner if time_over_flag else RoundRules.resolve(hps())
				time_over_flag = false
				over_winner = -1
				if w >= 0:
					wins[w] += 1
				if RoundRules.match_won(wins, w, WINS_NEEDED):
					phase = "end"
					announce(fighters[w].char_data.name + " ПОБЕЖДАЕТ!", 1.2)
					hint.visible = true
				else:
					if w < 0:
						announce("НИЧЬЯ", 1.2)
					round_num += 1
					start_round()
		"end":
			if edge(KEY_ENTER):
				Engine.time_scale = 1.0
				get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
			elif edge(KEY_R):
				Engine.time_scale = 1.0
				wins = []
				for i in range(fighters.size()):
					wins.append(0)
				round_num = 1
				start_round()
			elif edge(KEY_ESCAPE):
				Engine.time_scale = 1.0
				get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		_:
			pass

	# управление
	if phase == "fight":
		feed_human(fighters[0], P1_KEYS)
		for i in range(1, fighters.size()):
			if bots[i] != null:
				bots[i].process(delta)
			else:
				feed_human(fighters[i], P2_KEYS)
	else:
		for f in fighters:
			f.ext_dir = 0.0
			f.ext_block = false
			f.ext_attacks.clear()
	pending_keys.clear()

func set_fight_active(active: bool):
	# заморозка/разморозка бойцов и снарядов (борты не двигаются, попадания не проходят)
	var mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for f in fighters:
		f.process_mode = mode
		f.hitbox.monitoring = active
	for c in get_children():
		if c is Projectile:
			c.process_mode = mode
			c.monitoring = active

func enter_pause():
	phase = "pause"
	pause_root.visible = true
	msg.visible = false
	set_fight_active(false)

func resume_game():
	pause_root.visible = false
	msg.visible = true
	set_fight_active(true)
	phase = "fight"

func restart_round():
	pause_root.visible = false
	set_fight_active(true)
	start_round()

func exit_to_menu():
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func build_pause_menu():
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	pause_root = Control.new()
	pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pause_root)
	pause_root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(dim)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.position = Vector2(0, 200)
	title.size = Vector2(1280, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_root.add_child(title)
	var specs := [["Продолжить (Esc)", "resume"], ["Начать раунд заново", "restart"], ["Выйти в главное меню", "exit"]]
	var y := 320
	for s in specs:
		var b := Button.new()
		b.text = s[0]
		b.add_theme_font_size_override("font", 26)
		b.position = Vector2(440, y)
		b.size = Vector2(400, 60)
		if s[1] == "resume":
			b.pressed.connect(resume_game)
		elif s[1] == "restart":
			b.pressed.connect(restart_round)
		else:
			b.pressed.connect(exit_to_menu)
		pause_root.add_child(b)
		y += 74

func pips(w: int) -> String:
	var s := ""
	for i in range(WINS_NEEDED):
		s += "●" if i < w else "○"
	return s

func hp_color(r: float) -> Color:
	if r > 0.6:
		return Color(0.35, 0.85, 0.45)
	if r > 0.3:
		return Color(0.9, 0.8, 0.25)
	return Color(0.9, 0.25, 0.25)

func shake(t: float):
	shake_t = maxf(shake_t, t)

func spawn_projectile(owner: Fighter, a: Dictionary):
	var proj := Projectile.new()
	proj.setup(self, owner, owner.facing, a.dmg, a.proj_speed, owner.char_data.color)
	add_child(proj)
	proj.global_position = owner.global_position + Vector2(owner.facing * 60.0, -44.0)

func edge(key: int) -> bool:
	var p = Input.is_physical_key_pressed(key)
	var prev = key_prev.get(key, false)
	key_prev[key] = p
	return p and not prev

func feed_human(f: Fighter, keys: Dictionary):
	f.ext_dir = 0.0
	if Input.is_physical_key_pressed(keys.left):
		f.ext_dir -= 1.0
	if Input.is_physical_key_pressed(keys.right):
		f.ext_dir += 1.0
	f.ext_block = Input.is_physical_key_pressed(keys.down)
	f.ext_jump = keys.up in pending_keys
	f.ext_dash = keys.dash in pending_keys
	# очередь атак: [название, время_нажатия]
	if keys.light in pending_keys:
		f.ext_attacks.append(["light", clock])
	if keys.heavy in pending_keys:
		f.ext_attacks.append(["heavy" if f.is_on_floor() else "air", clock])
	if keys.special in pending_keys:
		f.ext_attacks.append(["special", clock])

func _exit_tree():
	Engine.time_scale = 1.0

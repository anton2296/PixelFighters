extends Control
# Главное меню: фон, сетка карточек персонажей (любое число), выбор арены,
# числа участников, режима и сложности; старт боя.

const ORDER = CharData.ORDER

# GameState: Engine-синглтон (тесты) или узел автозагрузки /root/GameState (игра).
func gs() -> Node:
	if Engine.has_singleton("GameState"):
		return Engine.get_singleton("GameState")
	return get_node("/root/GameState")

var selected := 0
var panels: Array = []
var border_styles: Array = []
var diff_btn: OptionButton
var mode_btn: OptionButton
var arena_btn: OptionButton
var part_btn: OptionButton

func _ready():
	# фон
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.18)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var ground := ColorRect.new()
	ground.color = Color(0.14, 0.12, 0.16)
	ground.position = Vector2(0, 560)
	ground.size = Vector2(1280, 160)
	add_child(ground)

	var title := Label.new()
	title.text = "PIXEL FIGHTERS"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := Label.new()
	sub.text = "2D-файтинг • арена, участники, персонаж, сложность бота"
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	sub.position = Vector2(0, 110)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# сетка карточек: колонки и строки считается из числа персонажей
	var n = ORDER.size()
	var cols = min(4, n)
	var rows = int(ceil(n / float(cols)))
	var card_w = (1280.0 - (cols + 1) * 20.0) / float(cols)
	var card_h = 344.0 if rows == 1 else 190.0
	var grid_y = 170.0 if rows == 1 else 140.0
	for i in range(n):
		var key = ORDER[i]
		var d = CharData.CHARS[key]
		var x = 20.0 + (i % cols) * (card_w + 20.0)
		var y = grid_y + (i / cols) * (card_h + 10.0)
		var panel := Panel.new()
		panel.position = Vector2(x, y)
		panel.size = Vector2(card_w, card_h)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.16, 0.22)
		style.set_corner_radius_all(10)
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_color = Color(0.3, 0.3, 0.35)
		panel.add_theme_stylebox_override("panel", style)
		panels.append(panel)
		border_styles.append(style)
		add_child(panel)

		var t_size = 200.0 if rows == 1 else 110.0
		var tex := TextureRect.new()
		var full = load(CharData.ANIM_DIR + "Punch_1.png")
		var at := AtlasTexture.new()
		at.atlas = full
		at.region = Rect2(0, 0, 128, 128)
		tex.texture = at
		tex.modulate = d.color
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.position = Vector2((card_w - t_size) / 2.0, 6.0 if rows > 1 else 10.0)
		tex.size = Vector2(t_size, t_size)
		panel.add_child(tex)

		var name_lbl := Label.new()
		name_lbl.text = d.name
		name_lbl.add_theme_font_size_override("font_size", 26 if rows == 1 else 20)
		name_lbl.add_theme_color_override("font_color", d.color)
		name_lbl.position = Vector2(10, t_size + 10.0)
		name_lbl.size = Vector2(card_w - 20, 26)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(name_lbl)

		var role := Label.new()
		role.text = d.role
		role.add_theme_font_size_override("font_size", 16 if rows == 1 else 13)
		role.position = Vector2(10, t_size + 36.0)
		role.size = Vector2(card_w - 20, card_h - t_size - 62.0)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(role)

		var stats := Label.new()
		stats.text = "HP: %d  Скорость: %d" % [d.hp, d.speed]
		stats.add_theme_font_size_override("font_size", 17 if rows == 1 else 14)
		stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		stats.position = Vector2(10, card_h - 28.0)
		stats.size = Vector2(card_w - 20, 22)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(stats)

		# вся карточка кликабельна
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_card_input.bind(i))
		for c in panel.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# панель выбора матча
	var controls_y = grid_y + rows * (card_h + 10.0) + 2.0
	var row_y = controls_y + 26.0
	var x := 20.0
	arena_btn = OptionButton.new()
	part_btn = OptionButton.new()
	mode_btn = OptionButton.new()
	diff_btn = OptionButton.new()
	x = add_option("Арена", arena_btn, x, controls_y, row_y, 250)
	for a in ArenaData.ARENA_ORDER:
		arena_btn.add_item(ArenaData.ARENA_NAMES[a])
	arena_btn.selected = 0
	# Селектор участников скрыт из интерфейса: матч — 2 бойца.
	# Механизм N>2 заложен: part_btn + clampi(2+selected, 2, min(4, ORDER))
	# в start_game, динамические бойцы/HUD/боты в Fight.gd. Чтобы вернуть:
	#   for p in [2, 3, 4]: part_btn.add_item(str(p))
	#   x = add_option("Участников", part_btn, x, controls_y, row_y, 160)
	for p in [2]:
		part_btn.add_item(str(p))
	part_btn.selected = 0
	x = add_option("Режим", mode_btn, x, controls_y, row_y, 310)
	mode_btn.add_item("Против бота")
	mode_btn.add_item("2 игрока (клавиатура)")
	mode_btn.selected = 0
	x = add_option("Сложность бота", diff_btn, x, controls_y, row_y, 250)
	diff_btn.add_item("Лёгкий")
	diff_btn.add_item("Средний")
	diff_btn.add_item("Сложный")
	diff_btn.selected = 1
	var start := Button.new()
	start.text = "НАЧАТЬ БОЙ"
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_font_size_override("font", 24)
	start.position = Vector2(x + 20.0, row_y)
	start.size = Vector2(1280.0 - x - 40.0, 48)
	start.pressed.connect(start_game)
	add_child(start)

	var info := Label.new()
	info.text = controls_text()
	info_label = info
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info.position = Vector2(0, 640)
	info.size = Vector2(1280, 78)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)

	select(0)
	_build_controls()

func add_option(label_text: String, btn: OptionButton, x: float, label_y: float, btn_y: float, w: float) -> float:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.position = Vector2(x, label_y)
	lbl.size = Vector2(w, 24)
	add_child(lbl)
	# без фокуса нажатия клавиш не «съедаются» списком
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2(x, btn_y)
	btn.size = Vector2(w, 48)
	btn.add_theme_font_size_override("font", 20)
	add_child(btn)
	return x + w + 20.0

func _on_card_input(event: InputEvent, i: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select(i)

func select(i: int):
	selected = clampi(i, 0, panels.size() - 1)
	for j in range(panels.size()):
		var style = border_styles[j]
		if j == selected:
			style.border_color = Color(1, 0.85, 0.4)
		else:
			style.border_color = Color(0.3, 0.3, 0.35)

func start_game():
	gs().participants = clampi(2 + part_btn.selected, 2, min(4, ORDER.size()))
	gs().arena_id = ArenaData.ARENA_ORDER[arena_btn.selected]
	gs().difficulty = diff_btn.selected
	gs().p2_is_bot = mode_btn.selected == 0
	# слот 0 — выбранный персонаж, остальные — уникальные из перемешанного пула
	var pool = ORDER.duplicate()
	pool.shuffle()
	var out: Array = [ORDER[clampi(selected, 0, ORDER.size() - 1)]]
	for k in pool:
		if out.size() < gs().participants:
			out.append(k)
	gs().chars = out
	gs().p1_char = out[0]
	gs().p2_char = out[1]
	get_tree().change_scene_to_file("res://scenes/Fight.tscn")

# ---------------- Настройки управления ----------------
var settings_root: Control
var key_buttons := {}
var cap_player := 0
var cap_action := ""
var info_label: Label

func _build_controls():
	var btn := Button.new()
	btn.text = "УПРАВЛЕНИЕ"
	btn.add_theme_font_size_override("font", 20)
	btn.position = Vector2(1100, 20)
	btn.size = Vector2(160, 44)
	btn.pressed.connect(open_settings)
	add_child(btn)

func controls_text() -> String:
	var k1 = gs().p1_keys
	var k2 = gs().p2_keys
	var t = "P1: %s/%s — движение, %s — прыжок, %s — присед, %s — удар (присев = скольжение, в воздухе = удар в прыжке), %s — сильный, %s — способность, %s — рывок\n" % [
		gs().key_name(k1.left), gs().key_name(k1.right), gs().key_name(k1.up), gs().key_name(k1.down),
		gs().key_name(k1.light), gs().key_name(k1.heavy), gs().key_name(k1.special), gs().key_name(k1.dash)]
	t += "P2: %s/%s — движение, %s — прыжок, %s — присед, %s — удар, %s — сильный, %s — способность, %s — рывок\n" % [
		gs().key_name(k2.left), gs().key_name(k2.right), gs().key_name(k2.up), gs().key_name(k2.down),
		gs().key_name(k2.light), gs().key_name(k2.heavy), gs().key_name(k2.special), gs().key_name(k2.dash)]
	t += "Стоишь без действия — авто-блок. Сильный удар в прыжке/атаке — потеря равновесия. Esc — пауза"
	return t

func open_settings():
	if settings_root == null:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.62)
		dim.size = Vector2(1280, 720)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		settings_root = dim
		add_child(dim)

		var title := Label.new()
		title.text = "НАСТРОЙКИ УПРАВЛЕНИЯ — нажмите кнопку действия, затем клавишу"
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		title.position = Vector2(0, 70)
		title.size = Vector2(1280, 40)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dim.add_child(title)

		var p1_lbl := Label.new()
		p1_lbl.text = "Игрок 1"
		p1_lbl.add_theme_font_size_override("font_size", 24)
		p1_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.45))
		p1_lbl.position = Vector2(70, 120)
		dim.add_child(p1_lbl)
		var p2_lbl := Label.new()
		p2_lbl.text = "Игрок 2"
		p2_lbl.add_theme_font_size_override("font_size", 24)
		p2_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		p2_lbl.position = Vector2(710, 120)
		dim.add_child(p2_lbl)

		for i in gs().ACTIONS.size():
			var a = gs().ACTIONS[i]
			for p in [1, 2]:
				var lx = 70 if p == 1 else 710
				var bx = 270 if p == 1 else 910
				var y = 160 + i * 56
				var lbl := Label.new()
				lbl.text = gs().ACTION_NAMES[a]
				lbl.add_theme_font_size_override("font_size", 20)
				lbl.position = Vector2(lx, y)
				lbl.size = Vector2(200, 44)
				dim.add_child(lbl)
				var kb := Button.new()
				kb.position = Vector2(bx, y)
				kb.size = Vector2(140, 44)
				kb.add_theme_font_size_override("font", 20)
				# без фокуса клавиши доходят до _unhandled_input, а не к кнопке
				kb.focus_mode = Control.FOCUS_NONE
				kb.pressed.connect(start_capture.bind(p, a))
				dim.add_child(kb)
				key_buttons["%d.%s" % [p, a]] = kb

		var reset := Button.new()
		reset.text = "Сбросить по умолчанию"
		reset.focus_mode = Control.FOCUS_NONE
		reset.add_theme_font_size_override("font", 20)
		reset.position = Vector2(430, 640)
		reset.size = Vector2(220, 44)
		reset.pressed.connect(reset_settings)
		dim.add_child(reset)

		var close := Button.new()
		close.text = "ЗАКРЫТЬ"
		close.focus_mode = Control.FOCUS_NONE
		close.add_theme_font_size_override("font", 20)
		close.position = Vector2(700, 640)
		close.size = Vector2(150, 44)
		close.pressed.connect(close_settings)
		dim.add_child(close)
	settings_root.visible = true
	refresh_key_buttons()

func close_settings():
	if settings_root != null:
		settings_root.visible = false
	cap_action = ""

func reset_settings():
	gs().reset_keys()
	refresh_key_buttons()

func start_capture(p: int, a: String):
	cap_player = p
	cap_action = a
	var b = key_buttons["%d.%s" % [p, a]]
	b.text = "нажмите…"
	b.release_focus()

func refresh_key_buttons():
	for k in key_buttons:
		var parts = k.split(".")
		var p = int(parts[0])
		var a = parts[1]
		var d = gs().p1_keys if p == 1 else gs().p2_keys
		var b = key_buttons[k]
		b.text = gs().key_name(d[a])
	info_label.text = controls_text()

# Клавиши во время захвата перехватываем в _input: он приходит раньше GUI-фокуса,
# иначе сфокусированный OptionButton потребляет нажатие.
func _input(event: InputEvent):
	if settings_root == null or not settings_root.visible:
		return
	if cap_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.physical_keycode
		if code == KEY_ESCAPE:
			cap_action = ""
			refresh_key_buttons()
			return
		gs().set_key(cap_player, cap_action, code)
		cap_action = ""
		refresh_key_buttons()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
	if settings_root == null or not settings_root.visible:
		return
	if cap_action == "":
		if event.is_action_pressed("ui_cancel"):
			close_settings()

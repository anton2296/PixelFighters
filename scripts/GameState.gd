extends Node
# Autoload: настройки матча между сценами + карта управления.

var p1_char := "striker"
var p2_char := "bruiser"
var difficulty := 1   # 0 лёгкий, 1 средний, 2 сложный
var p2_is_bot := true
# матч: id арены из ArenaData, число участников (2..4), набор персонажей по слотам
var arena_id := "dojo"
var participants := 2
var chars: Array = []

func get_match_chars() -> Array:
	if chars.size() == participants:
		return chars
	# fallback: первый выбранный, второй выбранный, остальные — случайные
	var out: Array = [p1_char, p2_char]
	for i in range(2, participants):
		out.append(CharData.ORDER[randi() % CharData.ORDER.size()])
	return out

const ACTIONS := ["left", "right", "up", "down", "light", "heavy", "special", "dash"]
const ACTION_NAMES := {
	"left": "Влево", "right": "Вправо", "up": "Прыжок", "down": "Присед",
	"light": "Быстрый удар", "heavy": "Сильный удар", "special": "Способность", "dash": "Рывок",
}
const DEFAULT_P1 := {
	"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
	"light": KEY_J, "heavy": KEY_K, "special": KEY_L, "dash": KEY_SHIFT,
}
const DEFAULT_P2 := {
	"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
	"light": KEY_1, "heavy": KEY_2, "special": KEY_3, "dash": KEY_CTRL,
}

var p1_keys := DEFAULT_P1.duplicate()
var p2_keys := DEFAULT_P2.duplicate()

func _ready():
	load_keys()

func load_keys():
	var cfg := ConfigFile.new()
	if cfg.load("user://controls.cfg") == OK:
		var p1 = cfg.get_value("keys", "p1", {})
		var p2 = cfg.get_value("keys", "p2", {})
		for a in ACTIONS:
			if a in p1:
				p1_keys[a] = p1[a]
			if a in p2:
				p2_keys[a] = p2[a]

func save_keys():
	var cfg := ConfigFile.new()
	cfg.set_value("keys", "p1", p1_keys)
	cfg.set_value("keys", "p2", p2_keys)
	cfg.save("user://controls.cfg")

func set_key(player: int, action: String, code: int):
	var d = p1_keys if player == 1 else p2_keys
	# одна клавиша = одно действие: убираем старые назначения
	for a in ACTIONS:
		if d[a] == code and a != action:
			d[a] = -1
	d[action] = code
	save_keys()

func reset_keys():
	p1_keys = DEFAULT_P1.duplicate()
	p2_keys = DEFAULT_P2.duplicate()
	save_keys()

func key_name(code: int) -> String:
	if code < 0:
		return "—"
	return OS.get_keycode_string(code)

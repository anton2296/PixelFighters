class_name RoundRules
# Чистая логика раунда/матча для произвольного числа бойцов — без узлов, легко тестируется.

# Раунд закончен, когда осталось <=1 живого или время вышло.
static func round_over(hps: Array, time_left: float) -> bool:
	var alive = 0
	for h in hps:
		if h > 0.0:
			alive += 1
	return alive <= 1 or time_left <= 0.0

# Победитель: максимальный HP; единственный выживший = максимальный HP.
# Ничья (равные верхние значения) => -1.
static func resolve(hps: Array) -> int:
	var best = -1
	var best_hp = -1.0
	for i in hps.size():
		var h = hps[i]
		if h > best_hp:
			best_hp = h
			best = i
		elif h == best_hp:
			best = -1
	return best

static func match_won(wins: Array, index: int, needed: int) -> bool:
	return index >= 0 and wins[index] >= needed

class_name TestRules
extends TestSuite
# Логика раунда/матча для произвольного числа бойцов.

func test_round_over():
	check(RoundRules.round_over([100.0, 0.0], 50.0), "остался 1 живой — раунд закончен")
	check(not RoundRules.round_over([100.0, 80.0], 50.0), "двое живы — игра идёт")
	check(RoundRules.round_over([50.0, 40.0], 0.0), "время вышло")
	check(RoundRules.round_over([0.0, 0.0, 0.0], 99.0), "все мертвы")
	check(not RoundRules.round_over([1.0, 2.0, 3.0], 10.0), "трое живы — игра идёт")

func test_resolve():
	check_eq(RoundRules.resolve([10.0, 20.0, 5.0]), 1, "максимальный HP побеждает")
	check_eq(RoundRules.resolve([0.0, 30.0, 0.0]), 1, "единственный выживший")
	check_eq(RoundRules.resolve([30.0, 30.0, 30.0]), -1, "полная ничья => -1")
	check_eq(RoundRules.resolve([10.0, 10.0, 0.0]), -1, "равные верхние => ничья")
	check_eq(RoundRules.resolve([1.0]), 0, "один боец")

func test_match_won():
	check(RoundRules.match_won([2, 1], 0, 2), "2 победы — матч за игроком 0")
	check(not RoundRules.match_won([1, 1], 0, 2), "одной победы мало")
	check(not RoundRules.match_won([2, 2], -1, 2), "победитель ничьей не выигрывает матч")

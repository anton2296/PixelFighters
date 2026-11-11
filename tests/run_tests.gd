extends SceneTree
# Тестовый раннер. Запуск:
#   Godot --headless --path PixelFighters -s res://tests/run_tests.gd
# Синхронные сюиты выполняются при старте, сценарий SmokeRunner — кадрами в дереве.

# static var: ссылки на class_name не константны
static var PURE = [TestCharData, TestArena, TestRules, TestFighter, TestProjectile]

var results: Array = []
var smoke: SmokeRunner
var frames := 0

func _initialize() -> void:
	_setup()

func _setup() -> void:
	var gs = load("res://scripts/GameState.gd").new()
	root.add_child(gs)
	Engine.register_singleton("GameState", gs)
	for S in PURE:
		var suite = S.new()
		suite.run_all()
		results.append(suite)
		print("сюит %s: %d проверок, %d неудач" % [suite.get_class(), suite.checks, suite.failures.size()])
		for f in suite.failures:
			print("   FAIL: %s" % f)
	smoke = SmokeRunner.new()
	root.add_child(smoke)

func _physics_process(delta: float) -> bool:
	if smoke == null:
		_setup()
		if smoke == null:
			print("INIT FAIL: SmokeRunner не создан")
			quit(2)
			return false
	frames += 1
	if smoke.done:
		results.append(smoke)
		var total = 0
		var fails = 0
		for r in results:
			total += r.checks
			fails += r.failures.size()
		print("сюит Smoke: %d проверок, %d неудач" % [smoke.checks, smoke.failures.size()])
		for f in smoke.failures:
			print("   FAIL: %s" % f)
		print("ИТОГ: %d проверок, %d неудач" % [total, fails])
		quit(0 if fails == 0 else 1)
	elif frames > 4000:
		print("TIMEOUT: сценарий не завершился за 4000 кадров")
		quit(2)
	return false

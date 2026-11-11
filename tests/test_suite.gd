class_name TestSuite
extends RefCounted
# База тестов: collect checks in check/check_eq, launch methods test_* via run_all.

var checks := 0
var failures: Array = []

func check(cond: bool, msg: String):
	checks += 1
	if not cond:
		failures.append(msg)

func check_eq(a, b, msg: String):
	checks += 1
	if a != b:
		failures.append("%s: ожидалось %s, получено %s" % [msg, b, a])

func run_all() -> int:
	for m in get_method_list():
		var mname = String(m["name"])
		if mname.begins_with("test_"):
			call(mname)
	return failures.size()

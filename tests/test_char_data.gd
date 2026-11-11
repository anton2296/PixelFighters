class_name TestCharData
extends TestSuite
# Целостность данных персонажей: больше 4 героев, все поля, все аним-файлы на месте.

func test_more_than_four_chars():
	check(CharData.CHARS.size() > 4, "персонажей больше 4 (получено %d)" % CharData.CHARS.size())
	check_eq(CharData.ORDER.size(), CharData.CHARS.size(), "ORDER покрывает все CHARS")
	for k in CharData.ORDER:
		check(CharData.CHARS.has(k), "ORDER -> CHARS: %s" % k)

func test_char_fields():
	for k in CharData.CHARS:
		var d = CharData.CHARS[k]
		check(int(d.hp) > 0, "%s: hp > 0" % k)
		check(int(d.speed) > 0, "%s: speed > 0" % k)
		check(float(d.jump) < 0.0, "%s: прыжок вверх (jump < 0)" % k)
		check(String(d.name) != "", "%s: имя" % k)
		check(d.color.a > 0.0, "%s: цвет" % k)
		check(float(d.special_cd) >= 0.0, "%s: кулдаун способности" % k)
		for atk in ["light", "light2", "airlight", "crouch", "heavy", "air", "special"]:
			check(d.attacks.has(atk), "%s: атака %s" % [k, atk])

func test_attack_fields():
	var req = ["anim", "dmg", "startup", "active", "recovery", "hit_y"]
	for k in CharData.CHARS:
		for aname in CharData.CHARS[k].attacks:
			var a = CharData.CHARS[k].attacks[aname]
			for f in req:
				check(a.has(f), "%s.%s: поле %s" % [k, aname, f])
			check(float(a.startup) > 0.0 and float(a.active) > 0.0 and float(a.recovery) > 0.0,
				"%s.%s: фазы положительны" % [k, aname])

func test_anim_files_exist():
	# общие анимации
	for key in CharData.COMMON_ANIM:
		check(ResourceLoader.exists(CharData.ANIM_DIR + CharData.COMMON_ANIM[key][0]),
			"файл анима %s (%s)" % [CharData.COMMON_ANIM[key][0], key])
	# индивидуальные оверлеи персонажей
	for k in CharData.CHARS:
		for key in CharData.CHARS[k].anim:
			check(ResourceLoader.exists(CharData.ANIM_DIR + CharData.CHARS[k].anim[key][0]),
				"%s: аним %s" % [k, key])

class_name FightStub
extends Node2D
# Минимальная подделка боевой сцены: Fighter/Projectile нужен узел fight
# с полями arena, clock, fighters и методами shake / spawn_projectile.

var arena: Dictionary = {}
var clock := 0.0
var fighters: Array = []
var shakes: Array = []
var projectiles: Array = []

func shake(t: float):
	shakes.append(t)

func spawn_projectile(owner: Fighter, a: Dictionary):
	var p := Projectile.new()
	p.setup(self, owner, owner.facing, a.dmg, a.proj_speed, owner.char_data.color)
	add_child(p)
	p.global_position = owner.global_position + Vector2(owner.facing * 60.0, -44.0)
	projectiles.append(p)

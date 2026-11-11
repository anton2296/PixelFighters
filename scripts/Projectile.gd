extends Area2D
class_name Projectile
# Снаряд (огненный шар) — летит, поражает hurtbox, исчезает.

var vel := Vector2.ZERO
var dmg := 0.0
var life := 1.4
var owner_fighter: Fighter
var fight: Node
var arena: Dictionary = {}
var done := false

func setup(fight_node: Node, owner: Fighter, dir: float, dmg_in: float, speed: float, color: Color):
	fight = fight_node
	owner_fighter = owner
	dmg = dmg_in
	vel = Vector2(dir * speed, 0.0)
	if fight_node != null and fight_node.get("arena") != null:
		arena = fight_node.arena
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 16.0
	cs.shape = c
	add_child(cs)
	var sp := Sprite2D.new()
	var tex = load(CharData.ANIM_DIR + "Casting Spell.png")
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(5.0 * 128.0, 0.0, 128.0, 128.0)
	sp.centered = true
	sp.scale = Vector2(0.55, 0.55)
	sp.texture = at
	sp.modulate = color
	add_child(sp)
	area_entered.connect(_on_hit)

func _physics_process(delta: float):
	global_position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
	elif arena.is_empty():
		if global_position.x < 40.0 or global_position.x > 1240.0:
			queue_free()
	elif global_position.x < arena.proj_min or global_position.x > arena.proj_max:
		queue_free()

func _on_hit(area: Area2D):
	if done:
		return
	done = true
	if area == owner_fighter.hurtbox:
		queue_free()
		return
	var victim = area.get_parent()
	if victim != null and victim is Fighter:
		victim.take_hit(dmg, sign(vel.x), 260.0, -140.0, 0.32, true)
		fight.shake(0.22)
	queue_free()

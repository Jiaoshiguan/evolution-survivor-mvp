extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal upgrade_applied(upgrade_id: String, rarity: String)

const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const ALL_UPGRADES := [
	"damage_boost",
	"rapid_cycle",
	"adrenal_drive",
	"piercing_rounds",
	"double_shot",
	"bio_armor",
	"spore_satellite",
	"crit_matrix",
	"pulse_shell",
]
const MAX_UPGRADE_STACKS := 10
const BASE_PROJECTILE_RADIUS := 7.0

var arena_bounds := Rect2(Vector2(-960.0, -540.0), Vector2(1920.0, 1080.0))
var projectile_parent: Node
var projectile_pool: ScenePool
var enemy_source: Node
@onready var camera: Camera2D = $Camera2D

var move_speed := 235.0
var max_health := 100.0
var health := 100.0
var attack_damage := 16.0
var damage_multiplier := 1.0
var attack_cooldown := 0.55
var projectile_speed := 620.0
var projectile_pierce := 0
var projectile_count := 1
var projectile_scale := 1.0
var crit_chance := 0.05
var crit_multiplier := 1.8
var attack_range := 720.0
var hit_radius := 18.0
var magnet_radius := 146.0
var pickup_radius := 24.0
var orb_pull_speed := 320.0
var orb_pull_acceleration := 1180.0

var invulnerability_timer := 0.0
var attack_timer := 0.1
var orbit_spore_level := 0
var orbit_rotation := 0.0
var is_dead := false
var last_aim_direction := Vector2.RIGHT
var current_move_direction := Vector2.ZERO
var has_attack_target := false
var upgrade_levels := {}
var upgrade_pick_rarities := {}
var muzzle_flash_timer := 0.0
var hurt_flash_timer := 0.0
var trauma := 0.0
var shake_time := 0.0


func _ready() -> void:
	for upgrade_id in ALL_UPGRADES:
		upgrade_levels[upgrade_id] = 0
		upgrade_pick_rarities[upgrade_id] = []
	emit_signal("health_changed", health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	var input_vector := _get_move_input()
	velocity = input_vector * move_speed
	move_and_slide()
	current_move_direction = input_vector

	var arena_end := arena_bounds.position + arena_bounds.size
	global_position = global_position.clamp(arena_bounds.position, arena_end)

	if invulnerability_timer > 0.0:
		invulnerability_timer = max(invulnerability_timer - delta, 0.0)
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer = max(muzzle_flash_timer - delta, 0.0)
	if hurt_flash_timer > 0.0:
		hurt_flash_timer = max(hurt_flash_timer - delta, 0.0)
	if trauma > 0.0:
		trauma = max(trauma - delta * 1.7, 0.0)
		shake_time += delta * 42.0
		camera.offset = Vector2(
			sin(shake_time * 1.13) * trauma * 8.0,
			cos(shake_time * 1.37) * trauma * 8.0
		)
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, min(1.0, delta * 12.0))

	attack_timer -= delta
	orbit_rotation += delta * (1.8 + orbit_spore_level * 0.3)
	var target := _find_nearest_enemy()
	has_attack_target = target != null
	if target != null:
		last_aim_direction = (target.global_position - global_position).normalized()

	if attack_timer <= 0.0:
		if target != null:
			_fire_at_target(target)
			attack_timer = attack_cooldown

	_update_orbit_spores(delta)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	var move_dir: Vector2 = current_move_direction.normalized()
	var attack_dir: Vector2 = last_aim_direction.normalized()
	if attack_dir == Vector2.ZERO:
		attack_dir = Vector2.RIGHT
	var cooldown_progress: float = 1.0 - clamp(attack_timer / max(attack_cooldown, 0.001), 0.0, 1.0)
	var target_strength: float = 1.0 if has_attack_target else 0.22
	var pre_fire: float = clamp((cooldown_progress - 0.76) / 0.24, 0.0, 1.0) * target_strength
	var attack_scale: float = 1.0 + pre_fire * 0.14 + sin(Time.get_ticks_msec() * 0.022) * 0.08 * pre_fire
	var attack_fill: Color = Color(0.34, 0.26, 0.12, 0.28).lerp(Color("ffcf6d"), cooldown_progress * target_strength)
	var attack_outline_color: Color = Color(0.74, 0.62, 0.32, 0.35).lerp(Color("fff3cf"), target_strength)

	var shell_color: Color = Color("8cf2c6") if invulnerability_timer <= 0.0 else Color("f1fff8")
	var shell_deep: Color = Color("173a33")
	var hurt_mix: float = clamp(hurt_flash_timer / 0.18, 0.0, 1.0)
	shell_color = shell_color.lerp(Color("ff7a7a"), hurt_mix * 0.78)
	shell_deep = shell_deep.lerp(Color("5a1717"), hurt_mix * 0.72)
	draw_circle(Vector2.ZERO, hit_radius, shell_color)
	draw_circle(Vector2.ZERO, hit_radius * 0.58, shell_deep)
	draw_circle(Vector2.ZERO, hit_radius * 0.22 + pulse * 0.45, Color("f4fffb").lerp(Color("ffd8d8"), hurt_mix * 0.55))

	var attack_start: Vector2 = attack_dir * (hit_radius + 2.0)
	var attack_end: Vector2 = attack_dir * (hit_radius + 12.0 * attack_scale)
	draw_line(attack_start, attack_end, attack_fill, 2.6)
	draw_circle(attack_end, 1.8 + pre_fire * 1.1, attack_outline_color)

	if move_dir != Vector2.ZERO:
		var triangle_tip: Vector2 = move_dir * (hit_radius + 13.0)
		var triangle_side: Vector2 = move_dir.orthogonal() * 5.0
		var triangle_back: Vector2 = move_dir * (hit_radius + 3.0)
		var move_triangle: PackedVector2Array = PackedVector2Array([
			triangle_tip,
			triangle_back + triangle_side,
			triangle_back - triangle_side,
		])
		draw_colored_polygon(move_triangle, Color(0.86, 1.0, 0.95, 0.08))
		var tri_outline: PackedVector2Array = move_triangle.duplicate()
		tri_outline.append(tri_outline[0])
		draw_polyline(tri_outline, Color("eafff6"), 1.4)

	if muzzle_flash_timer > 0.0:
		var flash_alpha: float = muzzle_flash_timer / 0.08
		draw_line(attack_dir * (hit_radius + 2.0), attack_dir * (hit_radius + 18.0 + flash_alpha * 8.0), Color(1.0, 1.0, 1.0, flash_alpha * 0.85), 2.8)

	if orbit_spore_level > 0:
		var orbit_count := orbit_spore_level
		var orbit_radius := 56.0 + orbit_spore_level * 6.0
		for index in orbit_count:
			var angle := orbit_rotation + TAU * float(index) / float(orbit_count)
			var pos: Vector2 = Vector2.RIGHT.rotated(angle) * orbit_radius
			_draw_spore_pod(pos, angle, 7.5 + orbit_spore_level)


func apply_meta_bonuses(bonuses: Dictionary) -> void:
	max_health += float(bonuses.get("max_health_bonus", 0.0))
	health = max_health
	damage_multiplier *= float(bonuses.get("damage_multiplier", 1.0))
	move_speed += float(bonuses.get("move_speed_bonus", 0.0))
	emit_signal("health_changed", health, max_health)


func take_damage(amount: float) -> void:
	if is_dead or invulnerability_timer > 0.0:
		return
	health = max(health - amount, 0.0)
	invulnerability_timer = 0.22
	hurt_flash_timer = 0.18
	_add_trauma(0.55)
	AudioManager.play_sfx_limited("player_hurt", 120, "player_hurt", 0.0, randf_range(0.96, 1.04))
	emit_signal("damaged", amount)
	emit_signal("health_changed", health, max_health)
	if health <= 0.0:
		is_dead = true
		emit_signal("died")


func heal(amount: float) -> void:
	health = min(health + amount, max_health)
	emit_signal("health_changed", health, max_health)


func can_receive_upgrade(upgrade_id: String) -> bool:
	return int(upgrade_levels.get(upgrade_id, 0)) < MAX_UPGRADE_STACKS


func get_available_upgrades() -> Array[String]:
	var options: Array[String] = []
	for upgrade_id in ALL_UPGRADES:
		if can_receive_upgrade(upgrade_id):
			options.append(upgrade_id)
	return options


func apply_upgrade(upgrade_id: String, rarity: String = "common") -> void:
	upgrade_levels[upgrade_id] = int(upgrade_levels.get(upgrade_id, 0)) + 1
	upgrade_pick_rarities[upgrade_id].append(rarity)
	match upgrade_id:
		"damage_boost":
			attack_damage += _get_scalar_value(rarity, 4.0, 6.0, 12.0)
		"rapid_cycle":
			attack_cooldown = max(0.12, attack_cooldown * _get_scalar_value(rarity, 0.94, 0.9, 0.84))
		"adrenal_drive":
			move_speed += _get_scalar_value(rarity, 16.0, 24.0, 40.0)
			magnet_radius += _get_scalar_value(rarity, 8.0, 14.0, 24.0)
		"piercing_rounds":
			projectile_pierce += int(_get_scalar_value(rarity, 1.0, 1.0, 2.0))
		"double_shot":
			projectile_count += int(_get_scalar_value(rarity, 1.0, 1.0, 2.0))
		"bio_armor":
			max_health += _get_scalar_value(rarity, 10.0, 18.0, 32.0)
			heal(_get_scalar_value(rarity, 14.0, 24.0, 40.0))
		"spore_satellite":
			orbit_spore_level += int(_get_scalar_value(rarity, 1.0, 1.0, 2.0))
		"crit_matrix":
			crit_chance = min(0.95, crit_chance + _get_scalar_value(rarity, 0.08, 0.12, 0.2))
		"pulse_shell":
			projectile_scale += _get_scalar_value(rarity, 0.18, 0.28, 0.42)
	emit_signal("upgrade_applied", upgrade_id, rarity)
	emit_signal("health_changed", health, max_health)


func _get_move_input() -> Vector2:
	var x := int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var y := int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return Vector2(x, y).normalized()


func _find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance_sq := attack_range * attack_range
	if enemy_source == null:
		return null
	for enemy in enemy_source.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("can_be_hit") and not enemy.can_be_hit():
			continue
		var distance_sq := global_position.distance_squared_to(enemy.global_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_enemy = enemy
	return nearest_enemy


func _fire_at_target(target: Node2D) -> void:
	if projectile_parent == null:
		return

	var direction := (target.global_position - global_position).normalized()
	var spread := 0.18
	var start_angle := -spread * float(projectile_count - 1) * 0.5
	for index in projectile_count:
		var projectile = projectile_pool.acquire(projectile_parent) if projectile_pool != null else PROJECTILE_SCENE.instantiate()
		var adjusted_direction := direction.rotated(start_angle + spread * index)
		var shot_stats: Dictionary = _roll_shot_stats()
		var projectile_radius := BASE_PROJECTILE_RADIUS * projectile_scale
		projectile.pool = projectile_pool
		projectile.direction = adjusted_direction
		projectile.speed = projectile_speed
		projectile.damage = shot_stats["damage"]
		projectile.is_crit = shot_stats["crit"]
		projectile.pierce = projectile_pierce
		projectile.radius = projectile_radius
		projectile.global_position = global_position + adjusted_direction * (hit_radius + projectile_radius + 4.0)
		projectile.on_pool_acquire()
	muzzle_flash_timer = 0.08
	AudioManager.play_sfx_limited("player_shot", 45, "player_shot", -5.0, randf_range(0.96, 1.05))


func _roll_shot_stats() -> Dictionary:
	var damage := attack_damage * damage_multiplier * randf_range(0.92, 1.08)
	var crit := false
	if randf() < crit_chance:
		damage *= crit_multiplier
		crit = true
	return {
		"damage": damage,
		"crit": crit,
	}


func _update_orbit_spores(delta: float) -> void:
	if orbit_spore_level <= 0:
		return

	var orbit_count := orbit_spore_level
	var orbit_radius := 56.0 + orbit_spore_level * 6.0
	var damage_per_second := (10.0 + orbit_spore_level * 4.0) * damage_multiplier

	if enemy_source == null:
		return
	for enemy in enemy_source.get_children():
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("can_be_hit") and not enemy.can_be_hit():
			continue
		var enemy_local := to_local(enemy.global_position)
		for index in orbit_count:
			var angle := orbit_rotation + TAU * float(index) / float(orbit_count)
			var orbit_position := Vector2.RIGHT.rotated(angle) * orbit_radius
			if enemy_local.distance_to(orbit_position) <= enemy.radius + 11.0:
				enemy.take_damage(damage_per_second * delta, global_position, false)


func _draw_spore_pod(position: Vector2, angle: float, size: float) -> void:
	draw_circle(position + Vector2(3.0, 4.0), size + 3.0, Color(0.0, 0.0, 0.0, 0.18))
	draw_circle(position, size, Color("f3c96a"))
	draw_circle(position, size * 0.42, Color("6a4120"))


func _add_trauma(amount: float) -> void:
	trauma = min(1.0, trauma + amount)


func _get_scalar_value(rarity: String, common_value: float, rare_value: float, legendary_value: float) -> float:
	match rarity:
		"rare":
			return rare_value
		"legendary":
			return legendary_value
	return common_value

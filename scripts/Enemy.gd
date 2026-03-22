extends CharacterBody2D

signal damaged(world_position: Vector2, amount: float, crit: bool, fatal: bool)
signal defeated(enemy_type: String, xp_reward: int, dna_reward: int, is_boss: bool, death_position: Vector2)

const ACTIVE_COLLISION_LAYER := 2
const ACTIVE_COLLISION_MASK := 0
const POOL_PARK_POSITION := Vector2(-100000.0, -100000.0)

var collision_shape: CollisionShape2D
var pool: ScenePool

var player

var enemy_type := "scout"
var radius := 14.0
var max_health := 24.0
var health := 24.0
var speed := 92.0
var contact_damage := 8.0
var attack_interval := 0.65
var xp_reward := 4
var dna_reward := 0
var is_boss := false
var color := Color("c74f59")

var attack_mode := "contact"
var preferred_range := 240.0
var behavior_state := "move"
var state_timer := 0.0
var action_direction := Vector2.ZERO
var dash_velocity := Vector2.ZERO
var dash_hit_consumed := false
var laser_range := 430.0
var laser_width := 18.0
var laser_fired := false
var strafe_sign := 1.0
var boss_pattern_index := 0
var boss_pulse_radius := 0.0
var boss_pulse_hit := false

var attack_cooldown := 0.1
var knockback_velocity := Vector2.ZERO
var defeated_emitted := false
var hit_flash_timer := 0.0
var feedback_cooldown := 0.0
var was_last_hit_crit := false


func _ready() -> void:
	add_to_group("enemies")
	_ensure_collision_shape()


func setup(kind: String, intensity: float) -> void:
	enemy_type = kind
	is_boss = false
	attack_mode = "contact"
	preferred_range = 240.0
	behavior_state = "move"
	state_timer = 0.0
	action_direction = Vector2.DOWN
	dash_velocity = Vector2.ZERO
	dash_hit_consumed = false
	laser_fired = false
	strafe_sign = -1.0 if randf() < 0.5 else 1.0
	laser_range = 430.0
	laser_width = 18.0
	attack_interval = 0.65
	boss_pattern_index = 0
	boss_pulse_radius = 0.0
	boss_pulse_hit = false
	defeated_emitted = false
	hit_flash_timer = 0.0
	feedback_cooldown = 0.0
	was_last_hit_crit = false
	attack_cooldown = 0.1
	knockback_velocity = Vector2.ZERO

	match kind:
		"scout":
			radius = 12.0
			max_health = 22.0 * intensity
			speed = 120.0 + 6.0 * intensity
			contact_damage = 7.0 + 0.5 * intensity
			xp_reward = 4
			dna_reward = 0
			color = Color("d46363")
		"brute":
			radius = 18.0
			max_health = 48.0 * intensity
			speed = 78.0 + 5.0 * intensity
			contact_damage = 12.0 + intensity
			xp_reward = 7
			dna_reward = 0
			color = Color("a95839")
		"stalker":
			radius = 15.0
			max_health = 34.0 * intensity
			speed = 102.0 + 6.0 * intensity
			contact_damage = 10.0 + 0.8 * intensity
			xp_reward = 6
			dna_reward = 1
			color = Color("7f52ce")
		"charger":
			radius = 16.0
			max_health = 42.0 * intensity
			speed = 86.0 + 5.0 * intensity
			contact_damage = 12.0 + 0.9 * intensity
			xp_reward = 8
			dna_reward = 1
			color = Color("ff7e61")
			attack_mode = "charge"
			attack_interval = 1.7
		"ray":
			radius = 14.0
			max_health = 30.0 * intensity
			speed = 72.0 + 4.0 * intensity
			contact_damage = 11.0 + 0.8 * intensity
			xp_reward = 8
			dna_reward = 1
			color = Color("6ea9ff")
			attack_mode = "ray"
			preferred_range = 260.0
			attack_interval = 2.1
			laser_range = 460.0
			laser_width = 20.0
		"elite":
			radius = 24.0
			max_health = 150.0 * intensity
			speed = 82.0 + 4.0 * intensity
			contact_damage = 18.0 + 1.2 * intensity
			xp_reward = 20
			dna_reward = 4
			color = Color("f0a94b")
		"boss":
			radius = 42.0
			max_health = 560.0 * intensity
			speed = 74.0 + 3.2 * intensity
			contact_damage = 26.0 + 1.9 * intensity
			xp_reward = 70
			dna_reward = 18
			color = Color("ffbc5a")
			is_boss = true
			attack_mode = "boss"
			preferred_range = 230.0
			attack_interval = 1.9
			laser_range = 560.0
			laser_width = 26.0

	health = max_health
	_ensure_collision_shape()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	_set_collision_active(true)
	visible = true
	set_physics_process(true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	hit_flash_timer = max(hit_flash_timer - delta, 0.0)
	feedback_cooldown = max(feedback_cooldown - delta, 0.0)
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 820.0 * delta)

	var to_player: Vector2 = player.global_position - global_position
	var direction: Vector2 = to_player.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	var behavior_velocity := direction * speed
	match attack_mode:
		"charge":
			behavior_velocity = _process_charge(direction, to_player.length(), delta)
		"ray":
			behavior_velocity = _process_ray(direction, to_player.length(), delta)
		"boss":
			behavior_velocity = _process_boss(direction, to_player.length(), delta)

	velocity = behavior_velocity + knockback_velocity
	move_and_slide()
	_apply_contact_damage(global_position.distance_to(player.global_position))
	queue_redraw()


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, apply_push := true, crit: bool = false) -> void:
	if health <= 0.0:
		return
	health -= amount
	hit_flash_timer = 0.11
	was_last_hit_crit = crit
	if apply_push and source_position != Vector2.ZERO:
		var push_direction: Vector2 = (global_position - source_position).normalized()
		if push_direction != Vector2.ZERO:
			knockback_velocity += push_direction * min(260.0, amount * 9.0)
	var fatal := health <= 0.0
	if fatal or crit or amount >= 6.0 or feedback_cooldown <= 0.0:
		emit_signal("damaged", global_position, amount, crit, fatal)
		feedback_cooldown = 0.08
	queue_redraw()
	if fatal:
		_die()


func can_be_hit() -> bool:
	return health > 0.0 and visible and collision_layer == ACTIVE_COLLISION_LAYER


func _die() -> void:
	if defeated_emitted:
		return
	defeated_emitted = true
	emit_signal("defeated", enemy_type, xp_reward, dna_reward, is_boss, global_position)
	release_to_pool()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0036 + radius)
	var facing: Vector2 = Vector2.DOWN
	if player != null and is_instance_valid(player):
		facing = (player.global_position - global_position).normalized()
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN
	var side: Vector2 = facing.orthogonal()
	var health_ratio: float = clamp(health / max_health, 0.0, 1.0)
	var flash_mix: float = clamp(hit_flash_timer / 0.11, 0.0, 1.0)
	var fill_color: Color = color.lerp(Color("fff9ea") if was_last_hit_crit else Color("ffffff"), flash_mix * (0.72 if was_last_hit_crit else 0.42))
	if enemy_type == "charger" and behavior_state == "charge_windup":
		var windup_progress: float = 1.0 - clamp(state_timer / 0.55, 0.0, 1.0)
		fill_color = fill_color.lerp(Color("ffb27a"), windup_progress * 0.6)
	elif enemy_type == "charger" and behavior_state == "charge_dash":
		fill_color = fill_color.lerp(Color("ffe0b8"), 0.48)
	var deep_color: Color = fill_color.darkened(0.62)

	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_circle(Vector2.ZERO, max(3.0, radius - 6.0), deep_color)

	match enemy_type:
		"scout":
			draw_line(Vector2.ZERO, facing * (radius * 0.82), Color("fff4ea"), 1.8)
		"brute":
			draw_line(-side * (radius * 0.42), side * (radius * 0.42), Color("ffe4c8"), 3.0)
		"stalker":
			draw_line(-side * (radius * 0.32) - facing * (radius * 0.24), side * (radius * 0.32) + facing * (radius * 0.24), Color("f4d6ff"), 1.8)
			draw_line(-side * (radius * 0.32) + facing * (radius * 0.24), side * (radius * 0.32) - facing * (radius * 0.24), Color("f4d6ff"), 1.8)
		"charger":
			draw_line(Vector2.ZERO, facing * (radius * 0.88), Color("ffe6ce"), 2.2)
			if behavior_state == "charge_windup":
				var windup_progress: float = 1.0 - clamp(state_timer / 0.55, 0.0, 1.0)
				draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 26, Color(1.0, 0.63, 0.38, 0.35 + windup_progress * 0.45), 2.0 + windup_progress * 1.4)
				draw_line(Vector2.ZERO, action_direction * (radius + 28.0 + windup_progress * 10.0), Color(1.0, 0.64, 0.34, 0.82), 2.4 + windup_progress * 1.2)
				draw_circle(action_direction * (radius + 10.0 + windup_progress * 5.0), 2.4 + windup_progress * 1.8, Color("fff0dc"))
			elif behavior_state == "charge_dash":
				draw_line(-action_direction * (radius * 0.55), action_direction * (radius + 18.0), Color(1.0, 0.74, 0.42, 0.95), 3.6)
		"ray":
			draw_line(-side * (radius * 0.42), side * (radius * 0.42), Color("ddeaff"), 2.0)
			draw_circle(Vector2.ZERO, 2.0 + pulse * 0.6, Color("eef5ff"))
			if behavior_state == "ray_windup":
				draw_line(Vector2.ZERO, action_direction * laser_range, Color(1.0, 0.8, 0.66, 0.3), 2.0)
			elif behavior_state == "ray_fire":
				draw_line(Vector2.ZERO, action_direction * laser_range, Color("fff0a8"), 4.0)
		"elite":
			draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 28, Color("ffe7b0"), 2.0)
			draw_line(-side * (radius * 0.54), side * (radius * 0.54), Color("fff3cf"), 2.2)
			draw_circle(Vector2.ZERO, 2.6, Color("fff3cf"))
		"boss":
			draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 40, Color("fff2cb"), 2.6)
			draw_line(-side * (radius * 0.48), side * (radius * 0.48), Color("fff2cb"), 2.4)
			draw_line(-facing * (radius * 0.48), facing * (radius * 0.48), Color("fff2cb"), 2.4)
			match behavior_state:
				"boss_charge_windup":
					draw_line(Vector2.ZERO, action_direction * (radius + 40.0), Color(1.0, 0.76, 0.48, 0.86), 3.0)
				"boss_charge_dash":
					draw_line(-action_direction * (radius * 0.35), action_direction * (radius + 18.0), Color(1.0, 0.66, 0.38, 0.95), 4.0)
				"boss_ray_windup":
					draw_line(Vector2.ZERO, action_direction * laser_range, Color(1.0, 0.84, 0.58, 0.46), 3.0)
				"boss_ray_fire":
					draw_line(Vector2.ZERO, action_direction * laser_range, Color(1.0, 0.94, 0.66, 0.92), 6.0)
				"boss_pulse_windup", "boss_pulse_fire":
					draw_arc(Vector2.ZERO, boss_pulse_radius, 0.0, TAU, 48, Color(1.0, 0.82, 0.56, 0.85), 3.0)

	if is_boss:
		draw_arc(Vector2.ZERO, radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * health_ratio, 40, Color("fff2cb"), 4.0)
	elif enemy_type == "elite":
		draw_arc(Vector2.ZERO, radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * health_ratio, 32, Color("ffe7b0"), 3.0)


func _process_charge(direction: Vector2, distance_to_player: float, delta: float) -> Vector2:
	match behavior_state:
		"move":
			if distance_to_player <= 290.0 and attack_cooldown <= 0.0:
				behavior_state = "charge_windup"
				state_timer = 0.55
				action_direction = direction
				dash_hit_consumed = false
				AudioManager.play_sfx_limited("enemy_charge_windup", 120, "enemy_charge", -5.0, 0.94)
				return -action_direction * 26.0
			return direction * speed
		"charge_windup":
			state_timer -= delta
			action_direction = _blend_direction(action_direction, direction, delta * 4.0)
			if state_timer <= 0.0:
				behavior_state = "charge_dash"
				state_timer = 0.42
				dash_velocity = action_direction * (560.0 + speed * 2.0)
				dash_hit_consumed = false
				AudioManager.play_sfx_limited("enemy_charge_dash", 120, "enemy_charge", -3.0, 1.08)
			return -action_direction * 18.0
		"charge_dash":
			state_timer -= delta
			dash_velocity = dash_velocity.move_toward(action_direction * 340.0, 1000.0 * delta)
			if state_timer <= 0.0:
				behavior_state = "recover"
				state_timer = 0.32
				attack_cooldown = max(attack_cooldown, attack_interval)
			return dash_velocity
		"recover":
			state_timer -= delta
			if state_timer <= 0.0:
				behavior_state = "move"
			return Vector2.ZERO
	return direction * speed


func _process_ray(direction: Vector2, distance_to_player: float, delta: float) -> Vector2:
	match behavior_state:
		"move":
			if distance_to_player <= laser_range - 40.0 and attack_cooldown <= 0.0:
				behavior_state = "ray_windup"
				state_timer = 0.68
				action_direction = direction
				laser_fired = false
				AudioManager.play_sfx_limited("enemy_ray_windup", 120, "enemy_ray", -8.0, 0.92)
				return Vector2.ZERO
			if distance_to_player > preferred_range + 50.0:
				return direction * speed
			if distance_to_player < preferred_range - 35.0:
				return -direction * speed * 0.8
			return direction.orthogonal() * strafe_sign * speed * 0.55
		"ray_windup":
			state_timer -= delta
			action_direction = _blend_direction(action_direction, direction, delta * 3.0)
			if state_timer <= 0.0:
				behavior_state = "ray_fire"
				state_timer = 0.16
				_fire_ray(1.35)
				AudioManager.play_sfx_limited("enemy_ray_fire", 120, "enemy_ray", -2.0, 1.08)
			return Vector2.ZERO
		"ray_fire":
			state_timer -= delta
			if state_timer <= 0.0:
				behavior_state = "move"
				attack_cooldown = max(attack_cooldown, attack_interval)
				strafe_sign *= -1.0
			return Vector2.ZERO
	return direction * speed


func _process_boss(direction: Vector2, distance_to_player: float, delta: float) -> Vector2:
	var aggression_scale: float = 1.0 + (1.0 - clamp(health / max_health, 0.0, 1.0)) * 0.25
	match behavior_state:
		"move":
			if attack_cooldown <= 0.0:
				match boss_pattern_index % 3:
					0:
						behavior_state = "boss_charge_windup"
						state_timer = 0.62
						action_direction = direction
						dash_hit_consumed = false
						AudioManager.play_sfx_limited("boss_charge_windup", 180, "enemy_charge", -2.0, 0.82)
					1:
						behavior_state = "boss_ray_windup"
						state_timer = 0.82
						action_direction = direction
						laser_fired = false
						AudioManager.play_sfx_limited("boss_ray_windup", 180, "enemy_ray", -4.0, 0.84)
					2:
						behavior_state = "boss_pulse_windup"
						state_timer = 0.9
						boss_pulse_radius = radius + 6.0
						boss_pulse_hit = false
						AudioManager.play_sfx_limited("boss_pulse_windup", 180, "enemy_charge", -6.0, 0.72)
				boss_pattern_index += 1
				return Vector2.ZERO
			if distance_to_player > preferred_range + 40.0:
				return direction * speed * 0.9
			if distance_to_player < preferred_range - 30.0:
				return -direction * speed * 0.75
			return direction.orthogonal() * strafe_sign * speed * 0.62
		"boss_charge_windup":
			state_timer -= delta
			action_direction = _blend_direction(action_direction, direction, delta * 3.2)
			if state_timer <= 0.0:
				behavior_state = "boss_charge_dash"
				state_timer = 0.34
				dash_velocity = action_direction * (520.0 + speed * 1.8 * aggression_scale)
				dash_hit_consumed = false
				AudioManager.play_sfx_limited("boss_charge_dash", 180, "enemy_charge", 0.0, 0.98)
			return -action_direction * 22.0
		"boss_charge_dash":
			state_timer -= delta
			dash_velocity = dash_velocity.move_toward(action_direction * 360.0, 1800.0 * delta)
			if state_timer <= 0.0:
				behavior_state = "recover"
				state_timer = 0.28
				attack_cooldown = max(attack_cooldown, attack_interval * 0.92)
			return dash_velocity
		"boss_ray_windup":
			state_timer -= delta
			action_direction = _blend_direction(action_direction, direction, delta * 2.8)
			if state_timer <= 0.0:
				behavior_state = "boss_ray_fire"
				state_timer = 0.24
				_fire_ray(1.9)
				AudioManager.play_sfx_limited("boss_ray_fire", 180, "enemy_ray", -0.5, 0.96)
			return Vector2.ZERO
		"boss_ray_fire":
			state_timer -= delta
			if state_timer <= 0.0:
				behavior_state = "recover"
				state_timer = 0.24
				attack_cooldown = max(attack_cooldown, attack_interval)
				strafe_sign *= -1.0
			return Vector2.ZERO
		"boss_pulse_windup":
			state_timer -= delta
			boss_pulse_radius = lerp(radius + 8.0, 170.0, 1.0 - state_timer / 0.9)
			if state_timer <= 0.0:
				behavior_state = "boss_pulse_fire"
				state_timer = 0.18
				boss_pulse_radius = 180.0
				_fire_pulse(180.0, 1.55)
				AudioManager.play_sfx_limited("boss_pulse_fire", 180, "enemy_ray", -1.0, 0.68)
			return Vector2.ZERO
		"boss_pulse_fire":
			state_timer -= delta
			boss_pulse_radius = lerp(180.0, 225.0, 1.0 - state_timer / 0.18)
			if state_timer <= 0.0:
				behavior_state = "recover"
				state_timer = 0.26
				attack_cooldown = max(attack_cooldown, attack_interval * 0.88)
			return Vector2.ZERO
		"recover":
			state_timer -= delta
			if state_timer <= 0.0:
				behavior_state = "move"
			return Vector2.ZERO
	return direction * speed


func _apply_contact_damage(distance_to_player: float) -> void:
	var collision_distance = radius + player.hit_radius + 4.0
	if attack_mode == "charge" and behavior_state == "charge_dash":
		if not dash_hit_consumed and distance_to_player <= collision_distance + 6.0:
			player.take_damage(contact_damage * 1.45)
			dash_hit_consumed = true
			attack_cooldown = max(attack_cooldown, attack_interval)
	elif attack_mode == "boss" and behavior_state == "boss_charge_dash":
		if not dash_hit_consumed and distance_to_player <= collision_distance + 10.0:
			player.take_damage(contact_damage * 1.7)
			dash_hit_consumed = true
			attack_cooldown = max(attack_cooldown, attack_interval)
	elif distance_to_player <= collision_distance and attack_cooldown <= 0.0 and behavior_state != "ray_fire":
		player.take_damage(contact_damage)
		attack_cooldown = attack_interval


func _fire_ray(damage_scale: float = 1.35) -> void:
	if laser_fired or player == null or not is_instance_valid(player):
		return
	laser_fired = true
	var start := global_position
	var finish := global_position + action_direction * laser_range
	var distance_to_line: float = _distance_to_segment(player.global_position, start, finish)
	var distance_from_origin: float = global_position.distance_to(player.global_position)
	if distance_to_line <= player.hit_radius + laser_width and distance_from_origin <= laser_range + player.hit_radius:
		player.take_damage(contact_damage * damage_scale)


func _fire_pulse(pulse_radius: float, damage_scale: float) -> void:
	if boss_pulse_hit or player == null or not is_instance_valid(player):
		return
	boss_pulse_hit = true
	if global_position.distance_to(player.global_position) <= pulse_radius + player.hit_radius:
		player.take_damage(contact_damage * damage_scale)


func _blend_direction(current: Vector2, target: Vector2, weight: float) -> Vector2:
	var blended := current
	if blended == Vector2.ZERO:
		blended = target
	else:
		blended = blended.lerp(target, min(1.0, weight))
	if blended == Vector2.ZERO:
		return target
	return blended.normalized()


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_length_sq: float = ab.length_squared()
	if ab_length_sq <= 0.0001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / ab_length_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)


func _ensure_collision_shape() -> void:
	if collision_shape != null:
		return
	collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)


func _set_collision_active(active: bool) -> void:
	_ensure_collision_shape()
	collision_layer = ACTIVE_COLLISION_LAYER if active else 0
	collision_mask = ACTIVE_COLLISION_MASK if active else 0
	collision_shape.set_deferred("disabled", not active)


func on_pool_acquire() -> void:
	_set_collision_active(true)
	visible = true
	set_physics_process(true)
	queue_redraw()


func on_pool_release() -> void:
	_set_collision_active(false)
	visible = false
	set_physics_process(false)
	player = null
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	global_position = POOL_PARK_POSITION


func release_to_pool() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()

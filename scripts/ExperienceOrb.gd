extends Node2D

signal collected(amount: int, world_position: Vector2)

var pool: ScenePool
var amount: int = 1
var velocity: Vector2 = Vector2.ZERO
var player
var base_radius: float = 8.0
var bob_phase: float = 0.0
var age: float = 0.0
var attracted: bool = false


func _ready() -> void:
	on_pool_acquire()


func setup(value: int, initial_velocity: Vector2, player_ref) -> void:
	amount = max(value, 1)
	velocity = initial_velocity
	player = player_ref
	base_radius = 6.0 + min(7.0, amount * 1.15)
	attracted = false
	age = 0.0
	bob_phase = randf() * TAU
	queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	if player != null and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position
		var distance: float = to_player.length()
		if distance <= player.pickup_radius:
			emit_signal("collected", amount, global_position)
			release_to_pool()
			return
		if distance <= player.magnet_radius:
			attracted = true
		if attracted:
			var target_speed: float = player.orb_pull_speed + max(0.0, player.magnet_radius - distance) * 2.2
			velocity = velocity.move_toward(to_player.normalized() * target_speed, player.orb_pull_acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)

	global_position += velocity * delta
	queue_redraw()


func _draw() -> void:
	var time_s: float = Time.get_ticks_msec() * 0.001
	var bob_offset: float = sin(age * 5.0 + bob_phase) * 1.8
	var glow_strength: float = 0.1 + 0.08 * (0.5 + 0.5 * sin(age * 8.0 + bob_phase))
	var center := Vector2(0.0, bob_offset)
	var shell_color: Color = Color("a6ffd9") if attracted else Color("f4d16e")
	var core_color: Color = Color("f9fffd") if attracted else Color("6a431b")
	var opacity: float = clamp(float(MetaProgress.get_setting("orb_opacity", 0.72)), 0.12, 1.0)
	draw_circle(center + Vector2(2.0, 3.0), base_radius + 2.0, Color(0.0, 0.0, 0.0, 0.16 * opacity))
	draw_circle(center, base_radius + 6.0, Color(0.54, 1.0, 0.85, glow_strength * opacity) if attracted else Color(1.0, 0.83, 0.4, glow_strength * opacity))
	draw_arc(center, base_radius + 2.0, time_s * 1.8 + bob_phase, time_s * 1.8 + bob_phase + PI * 1.15, 18, Color(1.0, 0.95, 0.82, 0.72 * opacity), 1.3)
	draw_circle(center, base_radius, Color(shell_color, opacity))
	draw_circle(center, base_radius * 0.52, Color(core_color, opacity))
	if attracted:
		var tail_dir: Vector2 = velocity.normalized()
		if tail_dir != Vector2.ZERO:
			draw_line(center - tail_dir * (base_radius * 2.2), center, Color(0.68, 1.0, 0.87, 0.38 * opacity), base_radius * 0.7)


func on_pool_acquire() -> void:
	visible = true
	set_physics_process(true)
	age = 0.0
	attracted = false
	queue_redraw()


func on_pool_release() -> void:
	visible = false
	set_physics_process(false)
	player = null
	velocity = Vector2.ZERO
	attracted = false


func release_to_pool() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()

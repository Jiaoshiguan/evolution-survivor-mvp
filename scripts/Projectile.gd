extends Area2D

var collision_shape: CollisionShape2D
var pool: ScenePool

var direction := Vector2.RIGHT
var speed := 620.0
var damage := 12.0
var pierce := 0
var radius := 5.0
var is_crit := false
var remaining_hits := 1
var lifetime := 1.45
var hit_targets := {}


func _ready() -> void:
	_ensure_collision_shape()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	on_pool_acquire()
	queue_redraw()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		release_to_pool()


func _draw() -> void:
	var forward: Vector2 = direction.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var time_s: float = Time.get_ticks_msec() * 0.001
	draw_circle(Vector2(2.0, 2.0), radius + 2.0, Color(0.0, 0.0, 0.0, 0.16))
	var shell_color: Color = Color("fff0a8") if is_crit else Color("cffff3")
	var core_color: Color = Color("ffd74b") if is_crit else Color("73ffd0")
	draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.93, 0.65, 0.16) if is_crit else Color(0.66, 1.0, 0.91, 0.14))
	draw_line(-forward * (radius * 2.6), forward * (radius * 0.9), Color(1.0, 0.93, 0.65, 0.62) if is_crit else Color(0.66, 1.0, 0.91, 0.52), radius * 0.9)
	draw_circle(Vector2.ZERO, radius + 1.2, shell_color)
	draw_circle(Vector2.ZERO, radius * 0.58, core_color)
	draw_arc(Vector2.ZERO, radius + 2.0, time_s * 3.0, time_s * 3.0 + PI * 1.1, 14, Color(shell_color, 0.75), 1.2)
	draw_circle(Vector2.ZERO, radius * 0.22, Color("473200") if is_crit else Color("114f3b"))


func _on_body_entered(body) -> void:
	if not body.is_in_group("enemies"):
		return
	if body.has_method("can_be_hit") and not body.can_be_hit():
		return
	var instance_id: int = body.get_instance_id()
	if hit_targets.has(instance_id):
		return
	hit_targets[instance_id] = true
	body.take_damage(damage, global_position, true, is_crit)
	remaining_hits -= 1
	if remaining_hits <= 0:
		release_to_pool()


func _ensure_collision_shape() -> void:
	if collision_shape != null:
		return
	collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)


func on_pool_acquire() -> void:
	_ensure_collision_shape()
	var shape: CircleShape2D = collision_shape.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		collision_shape.shape = shape
	shape.radius = radius
	remaining_hits = pierce + 1
	lifetime = 1.45
	hit_targets.clear()
	visible = true
	monitoring = true
	set_physics_process(true)
	queue_redraw()


func on_pool_release() -> void:
	visible = false
	monitoring = false
	set_physics_process(false)
	hit_targets.clear()


func release_to_pool() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()

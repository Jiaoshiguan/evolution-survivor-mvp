extends Node2D

var pool: ScenePool
var color: Color = Color.WHITE
var outer_radius: float = 24.0
var lifetime: float = 0.24
var age: float = 0.0
var spoke_count: int = 6
var ring_width: float = 3.0
var fill_alpha: float = 0.16


func setup(tint: Color, radius: float, duration: float = 0.24, spokes: int = 6, width: float = 3.0, alpha: float = 0.16) -> void:
	color = tint
	outer_radius = radius
	lifetime = duration
	spoke_count = spokes
	ring_width = width
	fill_alpha = alpha
	queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		release_to_pool()
	else:
		queue_redraw()


func _draw() -> void:
	var progress: float = clamp(age / lifetime, 0.0, 1.0)
	var radius_now: float = lerp(4.0, outer_radius, progress)
	var alpha: float = 1.0 - progress
	draw_circle(Vector2.ZERO, radius_now * 0.45, Color(color, fill_alpha * alpha))
	draw_arc(Vector2.ZERO, radius_now, 0.0, TAU, 36, Color(color, alpha), ring_width)
	for index in spoke_count:
		var angle: float = TAU * float(index) / float(spoke_count) + progress * 0.45
		var point: Vector2 = Vector2.RIGHT.rotated(angle) * (radius_now + 2.0 + progress * 6.0)
		draw_circle(point, max(1.0, ring_width - 0.4), Color(color, alpha * 0.92))


func on_pool_acquire() -> void:
	visible = true
	set_physics_process(true)
	queue_redraw()


func on_pool_release() -> void:
	visible = false
	set_physics_process(false)


func release_to_pool() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()

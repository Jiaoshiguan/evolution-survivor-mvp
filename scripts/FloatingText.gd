extends Node2D

var pool: ScenePool
var text: String = ""
var color: Color = Color.WHITE
var lifetime: float = 0.8
var age: float = 0.0
var velocity: Vector2 = Vector2(0.0, -42.0)
var scale_boost: float = 1.0


func setup(label_text: String, tint: Color, float_velocity: Vector2, duration: float = 0.8, size_boost: float = 1.0) -> void:
	text = label_text
	color = tint
	velocity = float_velocity
	lifetime = duration
	scale_boost = size_boost
	queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2(0.0, -24.0), 80.0 * delta)
	if age >= lifetime:
		release_to_pool()
	else:
		queue_redraw()


func _draw() -> void:
	var progress: float = clamp(age / lifetime, 0.0, 1.0)
	var alpha: float = 1.0 - progress
	var draw_color: Color = Color(color, alpha)
	var font_size: int = int(round(18.0 * scale_boost))
	var shadow_color: Color = Color(0.0, 0.0, 0.0, alpha * 0.35)
	var ascent: float = ThemeDB.fallback_font.get_ascent(font_size)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-22.0, ascent) + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
	draw_string(font, Vector2(-22.0, ascent), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, draw_color)


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

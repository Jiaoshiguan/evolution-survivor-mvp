extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const EXPERIENCE_ORB_SCENE := preload("res://scenes/ExperienceOrb.tscn")
const FLOATING_TEXT_SCENE := preload("res://scenes/FloatingText.tscn")
const BURST_FX_SCENE := preload("res://scenes/BurstFx.tscn")
const ScenePool := preload("res://scripts/ScenePool.gd")
const MAX_ACTIVE_ENEMIES_BY_STAGE := [18, 24, 28, 30, 1]
const MAX_ORBS := 90
const MAX_FLOATING_TEXTS := 24
const MAX_BURSTS := 32
const TRACKED_UPGRADES := [
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

const UPGRADE_DEFINITIONS := {
	"damage_boost": {
		"name": "Razor Gland",
		"description": "基础伤害 +6。稳妥、纯粹、每个流派都吃得到。",
	},
	"rapid_cycle": {
		"name": "Rapid Cycle",
		"description": "攻击间隔降低 12%。更快进入清场节奏。",
	},
	"adrenal_drive": {
		"name": "Adrenal Drive",
		"description": "移动速度 +24。更像土豆兄弟式走位和拉扯。",
	},
	"piercing_rounds": {
		"name": "Piercing Rounds",
		"description": "投射物穿透 +1。对密集敌群收益极高。",
	},
	"double_shot": {
		"name": "Double Shot",
		"description": "额外发射 1 枚投射物。强化中后期覆盖率。",
	},
	"bio_armor": {
		"name": "Bio Armor",
		"description": "最大生命 +18，并立刻回复 24 点生命。",
	},
	"spore_satellite": {
		"name": "Spore Satellite",
		"description": "获得 1 个环绕孢体，对贴身敌人造成持续伤害。",
	},
	"crit_matrix": {
		"name": "Crit Matrix",
		"description": "暴击率 +12%。配合多重射击会越来越强。",
	},
	"pulse_shell": {
		"name": "Pulse Shell",
		"description": "子弹体积显著放大，拿到后就该有明确体感。",
	},
}
const RARITY_INFO := {
	"common": {
		"name": "普通",
		"border": Color("c4cbd3"),
		"bean": Color("f2f5f8"),
	},
	"rare": {
		"name": "稀有",
		"border": Color("7ec4ff"),
		"bean": Color("8fcfff"),
	},
	"legendary": {
		"name": "传奇",
		"border": Color("ffd061"),
		"bean": Color("ffe08a"),
	},
}

@onready var enemy_layer: Node2D = $EnemyLayer
@onready var orb_layer: Node2D = $OrbLayer
@onready var projectile_layer: Node2D = $ProjectileLayer
@onready var fx_layer: Node2D = $FxLayer
@onready var ui_layer: CanvasLayer = $UI

var player
var arena_bounds := Rect2(Vector2(-980.0, -560.0), Vector2(1960.0, 1120.0))

var elapsed := 0.0
var run_duration := 480.0
var boss_warning_time := 315.0
var boss_trigger_time := 345.0
var spawn_timer := 0.25
var elite_spawn_timer := 14.0
var boss_spawned := false
var boss_alive := false
var run_finished := false
var combat_stage := -1

var xp := 0.0
var xp_to_next := 20.0
var level := 1
var pending_upgrades := 0
var current_upgrade_choices: Array[Dictionary] = []
var enemies_killed := 0
var dna_earned := 0
var result_saved := false
var announcement_timer := 0.0

var level_label: Label
var timer_label: Label
var dna_label: Label
var health_label: Label
var announcement_label: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var upgrade_overlay: Control
var result_overlay: Control
var result_label: Label
var summary_label: Label
var upgrade_cards: Array[Dictionary] = []
var tracker_rows := {}
var tracker_panel: PanelContainer
var tracker_container: GridContainer
var pool_storage: Node
var enemy_pool: ScenePool
var projectile_pool: ScenePool
var orb_pool: ScenePool
var text_pool: ScenePool
var burst_pool: ScenePool


func _ready() -> void:
	randomize()
	_setup_pools()
	_build_ui()
	_spawn_player()
	_update_hud()
	_announce("进入侦查期。先稳住节奏，Boss 将在 5:45 进入战场。", 4.0)
	AudioManager.play_music("run_loop")


func _draw() -> void:
	var ambient: float = 0.5 + 0.5 * sin(elapsed * 0.65)
	draw_rect(arena_bounds, Color("0e141c"), true)
	draw_rect(arena_bounds.grow(-22.0), Color("141f29"), true)
	draw_rect(arena_bounds.grow(-68.0), Color("16212a"), true)
	draw_rect(arena_bounds, Color("4d897a"), false, 6.0)
	draw_rect(arena_bounds.grow(-18.0), Color(0.4, 0.96, 0.82, 0.08), false, 2.0)

	for row in range(6):
		for column in range(9):
			var x_pos: float = arena_bounds.position.x + 110.0 + column * 220.0
			var y_pos: float = arena_bounds.position.y + 100.0 + row * 160.0
			var wave: float = sin(elapsed * 0.9 + column * 0.8 + row * 0.6)
			draw_circle(Vector2(x_pos, y_pos + wave * 8.0), 3.0 + ambient * 0.8, Color(0.46, 1.0, 0.84, 0.06))

	for column in range(5):
		var x_base: float = arena_bounds.position.x + 180.0 + column * 360.0
		draw_line(
			Vector2(x_base, arena_bounds.position.y + 80.0),
			Vector2(x_base, arena_bounds.end.y - 80.0),
			Color(0.36, 0.92, 0.8, 0.035),
			2.0
		)


func _physics_process(delta: float) -> void:
	if run_finished:
		return

	elapsed += delta
	queue_redraw()
	spawn_timer -= delta
	elite_spawn_timer -= delta
	announcement_timer = max(announcement_timer - delta, 0.0)
	_update_combat_stage()
	if announcement_timer == 0.0:
		announcement_label.text = ""

	if spawn_timer <= 0.0:
		_spawn_standard_wave()
		spawn_timer = _spawn_interval()

	if elite_spawn_timer <= 0.0 and elapsed < boss_warning_time and _can_spawn_more_enemies(1):
		_spawn_enemy("elite")
		elite_spawn_timer = max(11.0, 22.0 - elapsed * 0.02)
		_announce("精英孢群入场。", 2.0)

	if elapsed >= boss_warning_time and elapsed < boss_trigger_time and announcement_timer <= 0.0 and int(elapsed) % 3 == 0:
		_announce("裂隙主脑正在逼近，准备终局战。", 1.0)

	if elapsed >= boss_trigger_time and not boss_spawned:
		boss_spawned = true
		_spawn_enemy("boss")
		_announce("BOSS 出现。击杀它来稳定战场。", 3.4)

	if elapsed >= run_duration:
		_finish_run(not boss_alive)
		return

	_update_hud()


func _build_ui() -> void:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(hud)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	hud.add_child(margin)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	layout.add_child(top_row)

	var level_panel := _make_hud_panel(Color("13222b"), Color("4d897a"))
	top_row.add_child(level_panel)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 20)
	level_panel.get_child(0).add_child(level_label)

	var spacer_a := Control.new()
	spacer_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_a)

	var timer_panel := _make_hud_panel(Color("13222b"), Color("4f7482"))
	top_row.add_child(timer_panel)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 20)
	timer_panel.get_child(0).add_child(timer_label)

	var spacer_b := Control.new()
	spacer_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer_b)

	var dna_panel := _make_hud_panel(Color("2a2415"), Color("b79849"))
	top_row.add_child(dna_panel)
	dna_label = Label.new()
	dna_label.modulate = Color("f2d58b")
	dna_label.add_theme_font_size_override("font_size", 20)
	dna_panel.get_child(0).add_child(dna_label)

	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 12)
	layout.add_child(mid_row)

	var health_panel := PanelContainer.new()
	health_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_panel.add_theme_stylebox_override("panel", _make_style_box(Color("13222b"), Color("4d897a"), 20, 2))
	mid_row.add_child(health_panel)

	var health_margin := MarginContainer.new()
	health_margin.add_theme_constant_override("margin_left", 16)
	health_margin.add_theme_constant_override("margin_top", 8)
	health_margin.add_theme_constant_override("margin_right", 16)
	health_margin.add_theme_constant_override("margin_bottom", 8)
	health_panel.add_child(health_margin)

	var health_box := VBoxContainer.new()
	health_box.add_theme_constant_override("separation", 4)
	health_margin.add_child(health_box)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 12)
	health_box.add_child(health_row)

	health_bar = ProgressBar.new()
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.custom_minimum_size = Vector2(0, 22)
	health_bar.show_percentage = false
	_apply_progress_style(health_bar, Color("56d3b6"), Color("0c151c"))
	health_row.add_child(health_bar)

	health_label = Label.new()
	health_label.custom_minimum_size = Vector2(140, 0)
	health_label.add_theme_font_size_override("font_size", 16)
	health_row.add_child(health_label)

	var announce_panel := PanelContainer.new()
	announce_panel.custom_minimum_size = Vector2(380, 0)
	announce_panel.add_theme_stylebox_override("panel", _make_style_box(Color("13222b"), Color("4f7482"), 20, 2))
	mid_row.add_child(announce_panel)

	var announce_margin := MarginContainer.new()
	announce_margin.add_theme_constant_override("margin_left", 14)
	announce_margin.add_theme_constant_override("margin_top", 8)
	announce_margin.add_theme_constant_override("margin_right", 14)
	announce_margin.add_theme_constant_override("margin_bottom", 8)
	announce_panel.add_child(announce_margin)

	announcement_label = Label.new()
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement_label.modulate = Color("d4f7ee")
	announcement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announce_margin.add_child(announcement_label)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(fill)

	var xp_panel := PanelContainer.new()
	xp_panel.add_theme_stylebox_override("panel", _make_style_box(Color("13222b"), Color("4d897a"), 20, 2))
	layout.add_child(xp_panel)

	var xp_margin := MarginContainer.new()
	xp_margin.add_theme_constant_override("margin_left", 14)
	xp_margin.add_theme_constant_override("margin_top", 8)
	xp_margin.add_theme_constant_override("margin_right", 14)
	xp_margin.add_theme_constant_override("margin_bottom", 8)
	xp_panel.add_child(xp_margin)

	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 20)
	xp_bar.show_percentage = false
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_progress_style(xp_bar, Color("86d8ff"), Color("0c151c"))
	xp_margin.add_child(xp_bar)

	tracker_panel = PanelContainer.new()
	tracker_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tracker_panel.position = Vector2(24, 180)
	tracker_panel.custom_minimum_size = Vector2(180, 0)
	tracker_panel.visible = false
	tracker_panel.add_theme_stylebox_override("panel", _make_style_box(Color(0.07, 0.13, 0.16, 0.68), Color("355a56"), 14, 1))
	hud.add_child(tracker_panel)

	var tracker_margin := MarginContainer.new()
	tracker_margin.add_theme_constant_override("margin_left", 8)
	tracker_margin.add_theme_constant_override("margin_top", 6)
	tracker_margin.add_theme_constant_override("margin_right", 8)
	tracker_margin.add_theme_constant_override("margin_bottom", 6)
	tracker_panel.add_child(tracker_margin)

	tracker_container = GridContainer.new()
	tracker_container.columns = 1
	tracker_container.add_theme_constant_override("h_separation", 4)
	tracker_container.add_theme_constant_override("v_separation", 3)
	tracker_margin.add_child(tracker_container)

	_build_upgrade_tracker_rows()

	_build_upgrade_overlay()
	_build_result_overlay()


func _build_upgrade_overlay() -> void:
	upgrade_overlay = Control.new()
	upgrade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.visible = false
	upgrade_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	ui_layer.add_child(upgrade_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.05, 0.88)
	upgrade_overlay.add_child(shade)

	var back_pattern := Control.new()
	back_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.add_child(back_pattern)
	for index in range(9):
		var stripe := ColorRect.new()
		stripe.color = Color(0.32, 0.95, 0.82, 0.035 if index % 2 == 0 else 0.02)
		stripe.position = Vector2(-240.0 + index * 220.0, -120.0)
		stripe.size = Vector2(120.0, 1500.0)
		stripe.rotation = -0.22
		back_pattern.add_child(stripe)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1320, 620)
	panel.add_theme_stylebox_override("panel", _make_style_box(Color("101922"), Color("467f73"), 26, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)

	var header_chip := Label.new()
	header_chip.text = "Mutation Draft"
	header_chip.modulate = Color("7ee8c5")
	header_chip.add_theme_font_size_override("font_size", 16)
	layout.add_child(header_chip)

	var title := Label.new()
	title.text = "选择一项本局进化"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "这次选择会决定你接下来几分钟的打法。优先选能立刻改变战斗节奏的那一项。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color("d7dee7")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(subtitle)

	var cards_row := HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 20)
	layout.add_child(cards_row)

	var accent_color := Color("59d6b5")

	for card_index in 3:
		var card_panel := PanelContainer.new()
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_panel.add_theme_stylebox_override("panel", _make_style_box(Color("16222c"), accent_color.darkened(0.22), 24, 2))
		cards_row.add_child(card_panel)

		var card_root := VBoxContainer.new()
		card_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_panel.add_child(card_root)

		var accent_bar := ColorRect.new()
		accent_bar.color = accent_color
		accent_bar.custom_minimum_size = Vector2(0, 8)
		card_root.add_child(accent_bar)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 20)
		card_margin.add_theme_constant_override("margin_top", 18)
		card_margin.add_theme_constant_override("margin_right", 20)
		card_margin.add_theme_constant_override("margin_bottom", 20)
		card_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_root.add_child(card_margin)

		var card_box := VBoxContainer.new()
		card_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_box.add_theme_constant_override("separation", 14)
		card_margin.add_child(card_box)

		var card_tag := Label.new()
		card_tag.text = "0%d" % (card_index + 1)
		card_tag.modulate = accent_color
		card_tag.add_theme_font_size_override("font_size", 18)
		card_box.add_child(card_tag)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_box.add_child(name_label)

		var desc_label := Label.new()
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_label.modulate = Color("cfd8e3")
		card_box.add_child(desc_label)

		var helper_label := Label.new()
		helper_label.text = "这会直接改变你的战斗手感。"
		helper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		helper_label.modulate = Color(1.0, 1.0, 1.0, 0.44)
		card_box.add_child(helper_label)

		var choose_button := Button.new()
		choose_button.text = "选择"
		choose_button.custom_minimum_size = Vector2(0, 54)
		choose_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		choose_button.add_theme_stylebox_override("normal", _make_style_box(accent_color.darkened(0.38), accent_color, 16, 2))
		choose_button.add_theme_stylebox_override("hover", _make_style_box(accent_color.darkened(0.18), accent_color.lightened(0.08), 16, 2))
		choose_button.add_theme_stylebox_override("pressed", _make_style_box(accent_color.darkened(0.48), accent_color.lightened(0.12), 16, 2))
		choose_button.add_theme_color_override("font_color", Color("f7fbff"))
		choose_button.pressed.connect(_on_upgrade_chosen.bind(card_index))
		card_box.add_child(choose_button)

		upgrade_cards.append({
			"name": name_label,
			"description": desc_label,
			"helper": helper_label,
			"tag": card_tag,
			"accent_bar": accent_bar,
			"button": choose_button,
			"panel": card_panel,
		})

	var footer := Label.new()
	footer.text = "没有固定答案。选最能让你下一波打得更顺的。"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.modulate = Color("94a7b9")
	layout.add_child(footer)


func _build_result_overlay() -> void:
	result_overlay = Control.new()
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	ui_layer.add_child(result_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.05, 0.88)
	result_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 460)
	panel.add_theme_stylebox_override("panel", _make_style_box(Color("101922"), Color("4f7482"), 28, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var result_chip := Label.new()
	result_chip.text = "Run Summary"
	result_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_chip.modulate = Color("8ad8ff")
	result_chip.add_theme_font_size_override("font_size", 16)
	layout.add_child(result_chip)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 34)
	layout.add_child(result_label)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.modulate = Color("d4dde7")
	layout.add_child(summary_label)

	var retry_button := Button.new()
	retry_button.text = "再来一局"
	retry_button.custom_minimum_size = Vector2(0, 50)
	retry_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_style_action_button(retry_button, Color("1d5e52"), Color("67d6b8"))
	retry_button.pressed.connect(_on_retry_pressed)
	layout.add_child(retry_button)

	var menu_button := Button.new()
	menu_button.text = "回到主菜单"
	menu_button.custom_minimum_size = Vector2(0, 46)
	menu_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_style_action_button(menu_button, Color("18252f"), Color("4f7482"))
	menu_button.pressed.connect(_on_menu_pressed)
	layout.add_child(menu_button)


func _setup_pools() -> void:
	pool_storage = Node.new()
	pool_storage.name = "PoolStorage"
	add_child(pool_storage)

	enemy_pool = ScenePool.new(ENEMY_SCENE, pool_storage)
	projectile_pool = ScenePool.new(preload("res://scenes/Projectile.tscn"), pool_storage)
	orb_pool = ScenePool.new(EXPERIENCE_ORB_SCENE, pool_storage)
	text_pool = ScenePool.new(FLOATING_TEXT_SCENE, pool_storage)
	burst_pool = ScenePool.new(BURST_FX_SCENE, pool_storage)

	enemy_pool.warmup(18)
	projectile_pool.warmup(64)
	orb_pool.warmup(40)
	text_pool.warmup(24)
	burst_pool.warmup(24)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = arena_bounds.get_center()
	player.projectile_parent = projectile_layer
	player.projectile_pool = projectile_pool
	player.enemy_source = enemy_layer
	player.arena_bounds = arena_bounds
	player.apply_meta_bonuses(MetaProgress.get_run_bonuses())
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	player.upgrade_applied.connect(_on_player_upgrade_applied)
	add_child(player)
	_refresh_upgrade_tracker_rows()


func _spawn_standard_wave() -> void:
	if _current_stage() >= 4 and boss_alive:
		return
	var available_slots := _get_active_enemy_cap() - enemy_layer.get_child_count()
	if available_slots <= 0:
		return
	var enemies_to_spawn := 1
	match _current_stage():
		0:
			enemies_to_spawn = 1
		1:
			enemies_to_spawn = 2
		2:
			enemies_to_spawn = 2 + int(randf() < 0.35)
		3:
			enemies_to_spawn = 3
		_:
			enemies_to_spawn = 1 + int(randf() < 0.35)
	enemies_to_spawn = min(enemies_to_spawn, available_slots)
	for _index in enemies_to_spawn:
		_spawn_enemy(_roll_enemy_type())


func _spawn_enemy(enemy_type: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	if enemy_type != "boss" and not _can_spawn_more_enemies(1):
		return
	var enemy = enemy_pool.acquire(enemy_layer)
	enemy.pool = enemy_pool
	enemy.global_position = _get_spawn_position()
	enemy.player = player
	enemy.setup(enemy_type, _difficulty_scale())
	if not enemy.damaged.is_connected(_on_enemy_damaged):
		enemy.damaged.connect(_on_enemy_damaged)
	if not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)
	if enemy_type == "boss":
		boss_alive = true


func _roll_enemy_type() -> String:
	var stage := _current_stage()
	var roll := randf()
	if stage == 0:
		if roll < 0.6:
			return "scout"
		return "brute"
	if stage == 1:
		if roll < 0.24:
			return "scout"
		if roll < 0.52:
			return "brute"
		if roll < 0.8:
			return "stalker"
		return "charger"
	if stage == 2:
		if roll < 0.16:
			return "brute"
		if roll < 0.38:
			return "stalker"
		if roll < 0.76:
			return "charger"
		return "ray"
	if stage == 3:
		if roll < 0.28:
			return "stalker"
		if roll < 0.64:
			return "charger"
		return "ray"
	if roll < 0.48:
		return "scout"
	if roll < 0.76:
		return "charger"
	return "ray"


func _difficulty_scale() -> float:
	return 1.0 + elapsed * 0.0026 + level * 0.03


func _get_spawn_position() -> Vector2:
	for _attempt in 8:
		var angle := randf() * TAU
		var distance := randf_range(620.0, 820.0)
		var candidate = player.global_position + Vector2.RIGHT.rotated(angle) * distance
		var margin := 40.0
		var min_corner := arena_bounds.position + Vector2.ONE * margin
		var max_corner := arena_bounds.position + arena_bounds.size - Vector2.ONE * margin
		if candidate.x >= min_corner.x and candidate.y >= min_corner.y and candidate.x <= max_corner.x and candidate.y <= max_corner.y:
			return candidate
	return Vector2(
		randf_range(arena_bounds.position.x + 48.0, arena_bounds.end.x - 48.0),
		randf_range(arena_bounds.position.y + 48.0, arena_bounds.end.y - 48.0)
	)


func _spawn_interval() -> float:
	match _current_stage():
		0:
			return 0.92
		1:
			return 0.74
		2:
			return 0.58
		3:
			return 0.5
		_:
			return 0.92


func _on_enemy_damaged(world_position: Vector2, amount: float, crit: bool, fatal: bool) -> void:
	var damage_value: int = max(1, int(round(amount)))
	var text_color: Color = Color("fff0a8") if crit else Color("e4f9ff")
	var velocity: Vector2 = Vector2(randf_range(-18.0, 18.0), -62.0 if crit else -48.0)
	var size_boost: float = 1.15 if crit else 1.0
	AudioManager.play_sfx_limited("enemy_hit", 35, "enemy_hit", -6.0 if not crit else -3.0, 1.04 if crit else randf_range(0.94, 1.02))
	_spawn_floating_text(world_position + Vector2(randf_range(-8.0, 8.0), -10.0), str(damage_value), text_color, velocity, 0.7, size_boost)
	if fatal:
		_spawn_burst(world_position, Color("ffd789"), 34.0, 0.3, 9, 3.2, 0.2)
	elif crit:
		_spawn_burst(world_position, Color("ffe58b"), 24.0, 0.22, 7, 2.4, 0.15)
	else:
		_spawn_burst(world_position, Color("a4fff0"), 14.0, 0.16, 5, 1.8, 0.11)


func _on_enemy_defeated(_enemy_type: String, xp_reward: int, dna_reward: int, is_boss: bool, death_position: Vector2) -> void:
	enemies_killed += 1
	dna_earned += dna_reward
	AudioManager.play_sfx("enemy_death", -4.0, randf_range(0.92, 1.08))
	_spawn_xp_orbs(death_position, xp_reward)
	if is_boss:
		boss_alive = false
		dna_earned += 10
		_spawn_burst(death_position, Color("fff0af"), 58.0, 0.42, 12, 4.0, 0.24)
		_spawn_floating_text(death_position + Vector2(-8.0, -22.0), "BOSS DOWN", Color("fff0af"), Vector2(0.0, -58.0), 1.0, 1.2)
		_announce("终局体已清除，战场稳定。", 2.0)
		_finish_run(true)


func _gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		pending_upgrades += 1
		xp_to_next = _xp_target_for(level)
	if pending_upgrades > 0 and not get_tree().paused:
		call_deferred("_open_upgrade_if_needed")


func _xp_target_for(target_level: int) -> float:
	return 18.0 + target_level * 11.0 + pow(target_level, 1.25) * 2.6


func _open_upgrade_if_needed() -> void:
	if pending_upgrades <= 0 or run_finished:
		return

	current_upgrade_choices.clear()
	var pool = player.get_available_upgrades()
	pool.shuffle()
	for upgrade_id in pool:
		current_upgrade_choices.append({
			"id": upgrade_id,
			"rarity": _roll_upgrade_rarity(),
		})
		if current_upgrade_choices.size() == 3:
			break
	if current_upgrade_choices.is_empty():
		return

	for index in upgrade_cards.size():
		var card: Dictionary = upgrade_cards[index]
		var is_available := index < current_upgrade_choices.size()
		card["panel"].visible = is_available
		if not is_available:
			continue
		var offer: Dictionary = current_upgrade_choices[index]
		var upgrade_id: String = offer["id"]
		var rarity: String = offer["rarity"]
		var info: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
		var rarity_info: Dictionary = RARITY_INFO[rarity]
		card["name"].text = info["name"]
		card["description"].text = _get_upgrade_effect_text(upgrade_id, rarity)
		card["helper"].text = "%s。%s" % [info["description"], _get_upgrade_hint(upgrade_id)]
		card["tag"].text = "%s  0%d" % [rarity_info["name"], index + 1]
		card["tag"].modulate = rarity_info["border"]
		card["accent_bar"].color = rarity_info["border"]
		card["panel"].add_theme_stylebox_override("panel", _make_style_box(Color("16222c"), rarity_info["border"], 24, 2))

	pending_upgrades -= 1
	upgrade_overlay.visible = true
	get_tree().paused = true


func _on_upgrade_chosen(card_index: int) -> void:
	if card_index >= current_upgrade_choices.size():
		return
	var offer: Dictionary = current_upgrade_choices[card_index]
	var upgrade_id: String = offer["id"]
	var rarity: String = offer["rarity"]
	player.apply_upgrade(upgrade_id, rarity)
	var info: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
	var rarity_name: String = RARITY_INFO[rarity]["name"]
	AudioManager.play_sfx("upgrade_pick", -2.0, 1.0)
	upgrade_overlay.visible = false
	get_tree().paused = false
	_announce("%s %s 已接入。" % [rarity_name, info["name"]], 2.2)
	_update_hud()
	call_deferred("_open_upgrade_if_needed")


func _on_player_died() -> void:
	_finish_run(false)


func _on_player_health_changed(_current: float, _maximum: float) -> void:
	_update_hud()


func _update_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	level_label.text = "Lv.%d  Kills %d" % [level, enemies_killed]
	timer_label.text = "Time %s" % _format_time(max(run_duration - elapsed, 0.0))
	dna_label.text = "DNA %d" % dna_earned
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	health_label.text = "HP %.0f / %.0f" % [player.health, player.max_health]
	xp_bar.max_value = xp_to_next
	xp_bar.value = xp


func _format_time(seconds: float) -> String:
	var total_seconds := int(ceil(seconds))
	var minutes := total_seconds / 60
	var remainder := total_seconds % 60
	return "%02d:%02d" % [minutes, remainder]


func _announce(text: String, duration: float = 2.0) -> void:
	announcement_label.text = text
	announcement_timer = duration


func _spawn_xp_orbs(origin: Vector2, total_xp: int) -> void:
	if orb_layer.get_child_count() >= MAX_ORBS:
		var condensed_orb = orb_pool.acquire(orb_layer)
		condensed_orb.pool = orb_pool
		condensed_orb.global_position = origin
		condensed_orb.setup(total_xp, Vector2.ZERO, player)
		if not condensed_orb.collected.is_connected(_on_orb_collected):
			condensed_orb.collected.connect(_on_orb_collected)
		return
	var chunks: Array[int] = _split_xp_into_orbs(total_xp)
	if orb_layer.get_child_count() + chunks.size() > MAX_ORBS:
		var combined_value: int = 0
		for chunk in chunks:
			combined_value += chunk
		var merged_orb = orb_pool.acquire(orb_layer)
		merged_orb.pool = orb_pool
		merged_orb.global_position = origin
		merged_orb.setup(combined_value, Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)), player)
		if not merged_orb.collected.is_connected(_on_orb_collected):
			merged_orb.collected.connect(_on_orb_collected)
		return
	for index in chunks.size():
		var orb = orb_pool.acquire(orb_layer)
		orb.pool = orb_pool
		var angle: float = TAU * float(index) / max(1.0, float(chunks.size())) + randf_range(-0.22, 0.22)
		var speed: float = randf_range(48.0, 116.0)
		orb.global_position = origin + Vector2.RIGHT.rotated(angle) * randf_range(4.0, 10.0)
		orb.setup(chunks[index], Vector2.RIGHT.rotated(angle) * speed, player)
		if not orb.collected.is_connected(_on_orb_collected):
			orb.collected.connect(_on_orb_collected)


func _split_xp_into_orbs(total_xp: int) -> Array[int]:
	var chunks: Array[int] = []
	var remaining: int = max(total_xp, 0)
	while remaining > 0:
		var piece: int = 1
		if remaining >= 18:
			piece = 6
		elif remaining >= 10:
			piece = 4
		elif remaining >= 5:
			piece = 2
		chunks.append(piece)
		remaining -= piece
	return chunks


func _on_orb_collected(amount: int, world_position: Vector2) -> void:
	_gain_xp(amount)
	AudioManager.play_sfx_limited("xp_collect", 28, "xp_collect", -5.0, 1.0 + min(0.08, amount * 0.01))
	_spawn_burst(world_position, Color("8cffd6"), 18.0 + amount * 1.5, 0.18, 6, 2.0, 0.12)
	_spawn_floating_text(world_position + Vector2(-10.0, -10.0), "+%d XP" % amount, Color("8cffd6"), Vector2(0.0, -40.0), 0.55, 0.92)


func _spawn_floating_text(world_position: Vector2, label_text: String, tint: Color, float_velocity: Vector2, duration: float = 0.8, size_boost: float = 1.0) -> void:
	if fx_layer.get_child_count() >= MAX_FLOATING_TEXTS:
		return
	var text_fx = text_pool.acquire(fx_layer)
	text_fx.pool = text_pool
	text_fx.global_position = world_position
	text_fx.setup(label_text, tint, float_velocity, duration, size_boost)


func _spawn_burst(world_position: Vector2, tint: Color, radius: float, duration: float, spokes: int, width: float, alpha: float) -> void:
	if fx_layer.get_child_count() >= MAX_BURSTS:
		return
	var burst = burst_pool.acquire(fx_layer)
	burst.pool = burst_pool
	burst.global_position = world_position
	burst.setup(tint, radius, duration, spokes, width, alpha)


func _make_style_box(bg: Color, border: Color, corner_radius: int = 16, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _style_action_button(button: Button, bg: Color, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_style_box(bg, accent, 16, 2))
	button.add_theme_stylebox_override("hover", _make_style_box(bg.lightened(0.1), accent.lightened(0.08), 16, 2))
	button.add_theme_stylebox_override("pressed", _make_style_box(bg.darkened(0.12), accent.lightened(0.15), 16, 2))
	button.add_theme_color_override("font_color", Color("f7fbff"))
	button.add_theme_color_override("font_hover_color", Color("f7fbff"))
	button.add_theme_color_override("font_pressed_color", Color("f7fbff"))


func _make_hud_panel(bg: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style_box(bg, border, 18, 2))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	return panel


func _apply_progress_style(bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = bg_color
	background.set_corner_radius_all(12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)


func _build_upgrade_tracker_rows() -> void:
	for upgrade_id in TRACKED_UPGRADES:
		var row := HBoxContainer.new()
		row.visible = false
		row.add_theme_constant_override("separation", 4)
		tracker_container.add_child(row)

		var label := Label.new()
		label.custom_minimum_size = Vector2(26, 0)
		label.modulate = Color("dbe6ee")
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)

		var beans := HBoxContainer.new()
		beans.add_theme_constant_override("separation", 1)
		row.add_child(beans)

		var bean_nodes := []
		for _index in range(10):
			var bean := PanelContainer.new()
			bean.custom_minimum_size = Vector2(6, 6)
			bean.add_theme_stylebox_override("panel", _make_bean_style(Color("32404c"), false))
			beans.add_child(bean)
			bean_nodes.append(bean)

		tracker_rows[upgrade_id] = {
			"row": row,
			"label": label,
			"beans": bean_nodes,
		}


func _refresh_upgrade_tracker_rows() -> void:
	if player == null or not is_instance_valid(player):
		return
	var any_visible := false
	for upgrade_id in tracker_rows.keys():
		var row_info: Dictionary = tracker_rows[upgrade_id]
		var picks: Array = player.upgrade_pick_rarities.get(upgrade_id, [])
		row_info["row"].visible = not picks.is_empty()
		if row_info["row"].visible:
			any_visible = true
		row_info["label"].text = _get_upgrade_short_name(upgrade_id)
		for index in range(row_info["beans"].size()):
			var bean: PanelContainer = row_info["beans"][index]
			if index < picks.size():
				var rarity: String = picks[index]
				bean.add_theme_stylebox_override("panel", _make_bean_style(RARITY_INFO[rarity]["bean"], true))
			else:
				bean.add_theme_stylebox_override("panel", _make_bean_style(Color("32404c"), false))
	tracker_panel.visible = any_visible


func _make_bean_style(color: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg_color: Color = color
	bg_color.a = 1.0 if active else 0.26
	style.bg_color = bg_color
	style.border_color = color.lightened(0.08) if active else Color("566472")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _on_player_upgrade_applied(_upgrade_id: String, _rarity: String) -> void:
	_refresh_upgrade_tracker_rows()


func _roll_upgrade_rarity() -> String:
	var stage: int = _current_stage()
	var roll := randf()
	if stage <= 0:
		if roll < 0.76:
			return "common"
		if roll < 0.96:
			return "rare"
		return "legendary"
	if stage == 1:
		if roll < 0.62:
			return "common"
		if roll < 0.9:
			return "rare"
		return "legendary"
	if roll < 0.48:
		return "common"
	if roll < 0.82:
		return "rare"
	return "legendary"


func _get_upgrade_effect_text(upgrade_id: String, rarity: String) -> String:
	match upgrade_id:
		"damage_boost":
			return "伤害 +%d" % int(_get_rarity_value(rarity, 4, 6, 12))
		"rapid_cycle":
			return "攻击间隔降低 %d%%" % int(round((1.0 - _get_rarity_value_float(rarity, 0.94, 0.9, 0.84)) * 100.0))
		"adrenal_drive":
			return "移动 +%d，吸附范围 +%d" % [int(_get_rarity_value(rarity, 16, 24, 40)), int(_get_rarity_value(rarity, 8, 14, 24))]
		"piercing_rounds":
			return "穿透 +%d" % int(_get_rarity_value(rarity, 1, 1, 2))
		"double_shot":
			return "额外投射物 +%d" % int(_get_rarity_value(rarity, 1, 1, 2))
		"bio_armor":
			return "最大生命 +%d，回复 %d" % [int(_get_rarity_value(rarity, 10, 18, 32)), int(_get_rarity_value(rarity, 14, 24, 40))]
		"spore_satellite":
			return "环绕孢体 +%d" % int(_get_rarity_value(rarity, 1, 1, 2))
		"crit_matrix":
			return "暴击率 +%d%%" % int(round(_get_rarity_value_float(rarity, 0.08, 0.12, 0.2) * 100.0))
		"pulse_shell":
			return "弹体尺寸 +%d%%" % int(round(_get_rarity_value_float(rarity, 0.18, 0.28, 0.42) * 100.0))
	return UPGRADE_DEFINITIONS[upgrade_id]["description"]


func _get_upgrade_short_name(upgrade_id: String) -> String:
	match upgrade_id:
		"damage_boost":
			return "伤"
		"rapid_cycle":
			return "速"
		"adrenal_drive":
			return "移"
		"piercing_rounds":
			return "穿"
		"double_shot":
			return "多"
		"bio_armor":
			return "甲"
		"spore_satellite":
			return "孢"
		"crit_matrix":
			return "暴"
		"pulse_shell":
			return "壳"
	return upgrade_id


func _get_rarity_value(rarity: String, common_value: int, rare_value: int, legendary_value: int) -> int:
	match rarity:
		"rare":
			return rare_value
		"legendary":
			return legendary_value
	return common_value


func _get_rarity_value_float(rarity: String, common_value: float, rare_value: float, legendary_value: float) -> float:
	match rarity:
		"rare":
			return rare_value
		"legendary":
			return legendary_value
	return common_value


func _get_upgrade_hint(upgrade_id: String) -> String:
	match upgrade_id:
		"damage_boost":
			return "稳定输出。适合任何流派起手。"
		"rapid_cycle":
			return "节奏强化。让清怪和压制更流畅。"
		"adrenal_drive":
			return "机动强化。更适合拉扯和卷经验球。"
		"piercing_rounds":
			return "穿透强化。对密集敌潮最有效。"
		"double_shot":
			return "覆盖强化。中后期收益会更高。"
		"bio_armor":
			return "生存强化。血线危险时优先考虑。"
		"spore_satellite":
			return "近身压制。贴脸时能持续磨血。"
		"crit_matrix":
			return "爆发强化。适合多射和高频攻击。"
		"pulse_shell":
			return "容错强化。单次拿到就该能看出命中面变大。"
	return "围绕你当前最缺的那一环来选。"


func _current_stage() -> int:
	if elapsed < 60.0:
		return 0
	if elapsed < 180.0:
		return 1
	if elapsed < boss_warning_time:
		return 2
	if elapsed < boss_trigger_time:
		return 3
	return 4


func _get_active_enemy_cap() -> int:
	var stage: int = clamp(_current_stage(), 0, MAX_ACTIVE_ENEMIES_BY_STAGE.size() - 1)
	return MAX_ACTIVE_ENEMIES_BY_STAGE[stage]


func _can_spawn_more_enemies(extra_count: int = 1) -> bool:
	return enemy_layer.get_child_count() + extra_count <= _get_active_enemy_cap()


func _update_combat_stage() -> void:
	var stage := _current_stage()
	if stage == combat_stage:
		return
	combat_stage = stage
	match combat_stage:
		0:
			_announce("侦查期。先处理近身威胁，建立经验优势。", 2.2)
		1:
			_announce("压迫期。高机动敌人开始登场，但还没有射线压制。", 2.6)
		2:
			_announce("特种期。射线敌人开始出现，优先观察前摇。", 2.8)
		3:
			_announce("终局预警。Boss 即将进入战场。", 2.8)
		4:
			_announce("Boss 战阶段。优先读前摇并保持安全距离。", 3.0)


func _finish_run(victory: bool) -> void:
	if run_finished:
		return
	run_finished = true
	AudioManager.play_sfx("run_end", -1.5 if victory else -3.0, 1.0 if victory else 0.92)

	if not result_saved:
		var time_bonus := int(elapsed / 60.0)
		var kill_bonus := int(enemies_killed / 20.0)
		var completion_bonus := 14 if victory else 4
		var total_dna := dna_earned + time_bonus + kill_bonus + completion_bonus
		MetaProgress.add_dna(total_dna)
		dna_earned = total_dna
		result_saved = true

	result_label.text = "Run Stabilized" if victory else "Core Lost"
	summary_label.text = "存活时间: %s\n击杀数量: %d\n带回 DNA: %d\n\n节奏规划:\n0:00-1:00 侦查期\n1:00-3:00 压迫期\n3:00-5:15 特种期\n5:15-5:45 终局预警\n5:45 后 Boss 战" % [
		_format_time(elapsed),
		enemies_killed,
		dna_earned,
	]
	result_overlay.visible = true
	get_tree().paused = true


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

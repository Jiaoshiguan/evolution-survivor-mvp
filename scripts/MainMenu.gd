extends Control

var dna_label: Label
var upgrades_container: VBoxContainer
var settings_overlay: Control
var orb_opacity_slider: HSlider
var orb_opacity_value_label: Label


func _ready() -> void:
	_build_ui()
	_refresh_meta_panel()
	AudioManager.play_music("menu_loop")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0e141c")
	add_child(background)

	for index in range(9):
		var stripe := ColorRect.new()
		stripe.color = Color(0.28, 0.9, 0.78, 0.028 if index % 2 == 0 else 0.016)
		stripe.position = Vector2(-280.0 + index * 240.0, -120.0)
		stripe.size = Vector2(120.0, 1700.0)
		stripe.rotation = -0.22
		add_child(stripe)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 64)
	root_margin.add_theme_constant_override("margin_top", 56)
	root_margin.add_theme_constant_override("margin_right", 64)
	root_margin.add_theme_constant_override("margin_bottom", 56)
	add_child(root_margin)

	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 36)
	root_margin.add_child(layout)

	var menu_wrapper := VBoxContainer.new()
	menu_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(menu_wrapper)

	var menu_card := PanelContainer.new()
	menu_card.custom_minimum_size = Vector2(660, 0)
	menu_card.add_theme_stylebox_override("panel", _make_style_box(Color("101922"), Color("467f73"), 30, 2))
	menu_wrapper.add_child(menu_card)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 34)
	menu_margin.add_theme_constant_override("margin_top", 34)
	menu_margin.add_theme_constant_override("margin_right", 34)
	menu_margin.add_theme_constant_override("margin_bottom", 34)
	menu_card.add_child(menu_margin)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 18)
	menu_margin.add_child(menu_box)

	var eyebrow := Label.new()
	eyebrow.text = "Single-player Evolution Roguelite"
	eyebrow.modulate = Color("7fd1ac")
	eyebrow.add_theme_font_size_override("font_size", 16)
	menu_box.add_child(eyebrow)

	var title := Label.new()
	title.text = "Evolution Survivor"
	title.add_theme_font_size_override("font_size", 42)
	menu_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "短局刷潮、局外成长、局内随机强化。现在这版重点验证战斗节奏、经验球吸附和构筑选择。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.modulate = Color("d3d8de")
	menu_box.add_child(subtitle)

	var feature_row := HBoxContainer.new()
	feature_row.add_theme_constant_override("separation", 10)
	menu_box.add_child(feature_row)
	for feature in ["8 分钟单局", "随机三选一", "局外 DNA"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _make_style_box(Color("16222c"), Color("2e5f57"), 18, 1))
		feature_row.add_child(chip)
		var chip_margin := MarginContainer.new()
		chip_margin.add_theme_constant_override("margin_left", 12)
		chip_margin.add_theme_constant_override("margin_top", 8)
		chip_margin.add_theme_constant_override("margin_right", 12)
		chip_margin.add_theme_constant_override("margin_bottom", 8)
		chip.add_child(chip_margin)
		var chip_label := Label.new()
		chip_label.text = feature
		chip_label.modulate = Color("d7fff4")
		chip_margin.add_child(chip_label)

	var start_button := Button.new()
	start_button.text = "开始一局"
	start_button.custom_minimum_size = Vector2(0, 58)
	_style_action_button(start_button, Color("1d5e52"), Color("67d6b8"))
	start_button.pressed.connect(_on_start_pressed)
	menu_box.add_child(start_button)

	var settings_button := Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size = Vector2(0, 50)
	_style_action_button(settings_button, Color("1a2832"), Color("8ad8ff"))
	settings_button.pressed.connect(_on_settings_pressed)
	menu_box.add_child(settings_button)

	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.custom_minimum_size = Vector2(0, 48)
	_style_action_button(quit_button, Color("18252f"), Color("4f7482"))
	quit_button.pressed.connect(_on_quit_pressed)
	menu_box.add_child(quit_button)

	var note := Label.new()
	note.text = "当前保留程序化极简风格，先把节奏、识别度和可读性做稳，再决定是否接入外部素材。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("9ca7b5")
	menu_box.add_child(note)

	var meta_panel := PanelContainer.new()
	meta_panel.custom_minimum_size = Vector2(620, 0)
	meta_panel.add_theme_stylebox_override("panel", _make_style_box(Color("101922"), Color("4f7482"), 30, 2))
	layout.add_child(meta_panel)

	var meta_margin := MarginContainer.new()
	meta_margin.add_theme_constant_override("margin_left", 28)
	meta_margin.add_theme_constant_override("margin_top", 28)
	meta_margin.add_theme_constant_override("margin_right", 28)
	meta_margin.add_theme_constant_override("margin_bottom", 28)
	meta_panel.add_child(meta_margin)

	var meta_box := VBoxContainer.new()
	meta_box.add_theme_constant_override("separation", 14)
	meta_margin.add_child(meta_box)

	var meta_chip := Label.new()
	meta_chip.text = "Meta Progress"
	meta_chip.modulate = Color("8ad8ff")
	meta_chip.add_theme_font_size_override("font_size", 16)
	meta_box.add_child(meta_chip)

	var meta_title := Label.new()
	meta_title.text = "局外进化"
	meta_title.add_theme_font_size_override("font_size", 34)
	meta_box.add_child(meta_title)

	dna_label = Label.new()
	dna_label.modulate = Color("f7d27b")
	dna_label.add_theme_font_size_override("font_size", 20)
	meta_box.add_child(dna_label)

	var meta_desc := Label.new()
	meta_desc.text = "永久成长只提供轻量数值优势，让你更快进入流派，而不是直接把局内策略做平。"
	meta_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_desc.modulate = Color("cbd5e1")
	meta_box.add_child(meta_desc)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meta_box.add_child(scroll)

	upgrades_container = VBoxContainer.new()
	upgrades_container.add_theme_constant_override("separation", 10)
	scroll.add_child(upgrades_container)

	_build_settings_overlay()


func _refresh_meta_panel() -> void:
	dna_label.text = "DNA 储备: %d" % MetaProgress.dna
	for child in upgrades_container.get_children():
		child.queue_free()

	var upgrade_ids: Array = MetaProgress.UPGRADE_INFO.keys()
	upgrade_ids.sort()
	for upgrade_id in upgrade_ids:
		var info: Dictionary = MetaProgress.UPGRADE_INFO[upgrade_id]
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 110)
		row.add_theme_stylebox_override("panel", _make_style_box(Color("16222c"), Color("2b4653"), 22, 1))
		upgrades_container.add_child(row)

		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 16)
		row_margin.add_theme_constant_override("margin_top", 14)
		row_margin.add_theme_constant_override("margin_right", 16)
		row_margin.add_theme_constant_override("margin_bottom", 14)
		row.add_child(row_margin)

		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 16)
		row_margin.add_child(row_box)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(text_box)

		var name_label := Label.new()
		name_label.text = "%s  Lv.%d/%d" % [
			info["name"],
			MetaProgress.get_upgrade_level(upgrade_id),
			info["max_level"],
		]
		name_label.add_theme_font_size_override("font_size", 18)
		text_box.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = info["description"]
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.modulate = Color("c9d4df")
		text_box.add_child(desc_label)

		var cost_label := Label.new()
		if MetaProgress.get_upgrade_level(upgrade_id) >= int(info["max_level"]):
			cost_label.text = "已满级"
		else:
			cost_label.text = "升级花费: %d DNA" % MetaProgress.get_upgrade_cost(upgrade_id)
		cost_label.modulate = Color("f7d27b")
		text_box.add_child(cost_label)

		var buy_button := Button.new()
		buy_button.text = "购买"
		buy_button.custom_minimum_size = Vector2(110, 44)
		buy_button.disabled = not MetaProgress.can_buy(upgrade_id)
		_style_action_button(buy_button, Color("1d5e52"), Color("67d6b8"))
		buy_button.pressed.connect(_buy_upgrade.bind(upgrade_id))
		row_box.add_child(buy_button)


func _buy_upgrade(upgrade_id: String) -> void:
	if MetaProgress.buy_upgrade(upgrade_id):
		AudioManager.play_sfx("upgrade_pick", -1.0, 1.0)
		_refresh_meta_panel()


func _on_start_pressed() -> void:
	AudioManager.play_sfx("ui_click", -2.0, 1.0)
	get_tree().change_scene_to_file("res://scenes/Run.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("ui_click", -3.0, 1.0)
	_refresh_settings_panel()
	settings_overlay.visible = true


func _on_quit_pressed() -> void:
	AudioManager.play_sfx("ui_click", -3.0, 0.9)
	get_tree().quit()


func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	add_child(settings_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.05, 0.88)
	settings_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 360)
	panel.add_theme_stylebox_override("panel", _make_style_box(Color("101922"), Color("4f7482"), 28, 2))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var chip := Label.new()
	chip.text = "Settings"
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.modulate = Color("8ad8ff")
	chip.add_theme_font_size_override("font_size", 16)
	layout.add_child(chip)

	var title := Label.new()
	title.text = "显示设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	var desc := Label.new()
	desc.text = "调整经验球透明度，降低密集掉落时对战斗视线的影响。"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color("d7dee7")
	layout.add_child(desc)

	var setting_panel := PanelContainer.new()
	setting_panel.add_theme_stylebox_override("panel", _make_style_box(Color("16222c"), Color("2b4653"), 22, 1))
	layout.add_child(setting_panel)

	var setting_margin := MarginContainer.new()
	setting_margin.add_theme_constant_override("margin_left", 18)
	setting_margin.add_theme_constant_override("margin_top", 18)
	setting_margin.add_theme_constant_override("margin_right", 18)
	setting_margin.add_theme_constant_override("margin_bottom", 18)
	setting_panel.add_child(setting_margin)

	var setting_box := VBoxContainer.new()
	setting_box.add_theme_constant_override("separation", 12)
	setting_margin.add_child(setting_box)

	var label_row := HBoxContainer.new()
	label_row.add_theme_constant_override("separation", 12)
	setting_box.add_child(label_row)

	var setting_label := Label.new()
	setting_label.text = "经验球透明度"
	setting_label.add_theme_font_size_override("font_size", 20)
	label_row.add_child(setting_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(spacer)

	orb_opacity_value_label = Label.new()
	orb_opacity_value_label.modulate = Color("f2d58b")
	label_row.add_child(orb_opacity_value_label)

	orb_opacity_slider = HSlider.new()
	orb_opacity_slider.min_value = 0.15
	orb_opacity_slider.max_value = 1.0
	orb_opacity_slider.step = 0.01
	orb_opacity_slider.value_changed.connect(_on_orb_opacity_changed)
	setting_box.add_child(orb_opacity_slider)

	var helper := Label.new()
	helper.text = "推荐值 0.45 - 0.70。数值越低，经验球越不挡视野。"
	helper.modulate = Color("94a7b9")
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setting_box.add_child(helper)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 48)
	_style_action_button(close_button, Color("18252f"), Color("4f7482"))
	close_button.pressed.connect(_close_settings)
	layout.add_child(close_button)


func _refresh_settings_panel() -> void:
	var opacity: float = clamp(float(MetaProgress.get_setting("orb_opacity", 0.72)), 0.15, 1.0)
	orb_opacity_slider.value = opacity
	orb_opacity_value_label.text = "%d%%" % int(round(opacity * 100.0))


func _on_orb_opacity_changed(value: float) -> void:
	MetaProgress.set_setting("orb_opacity", snapped(value, 0.01))
	orb_opacity_value_label.text = "%d%%" % int(round(value * 100.0))


func _close_settings() -> void:
	AudioManager.play_sfx("ui_click", -4.0, 0.96)
	settings_overlay.visible = false


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
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.35))

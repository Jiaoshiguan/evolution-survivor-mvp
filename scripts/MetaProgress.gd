extends Node

const SAVE_PATH := "user://meta_progress.cfg"

const UPGRADE_INFO := {
	"vitality": {
		"name": "Vitality Weave",
		"description": "+12 max HP every run.",
		"base_cost": 15,
		"cost_step": 10,
		"max_level": 5,
	},
	"fury": {
		"name": "Fury Kernel",
		"description": "+6% weapon damage every run.",
		"base_cost": 15,
		"cost_step": 12,
		"max_level": 5,
	},
	"agility": {
		"name": "Agility Lattice",
		"description": "+18 move speed every run.",
		"base_cost": 15,
		"cost_step": 8,
		"max_level": 5,
	},
}

var dna: int = 0
var upgrades := {
	"vitality": 0,
	"fury": 0,
	"agility": 0,
}
var settings := {
	"orb_opacity": 0.72,
}


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	var config := ConfigFile.new()
	var result := config.load(SAVE_PATH)
	if result != OK:
		save_progress()
		return

	dna = int(config.get_value("meta", "dna", 0))
	for key in upgrades.keys():
		upgrades[key] = int(config.get_value("upgrades", key, 0))
	for key in settings.keys():
		settings[key] = float(config.get_value("settings", key, settings[key]))


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "dna", dna)
	for key in upgrades.keys():
		config.set_value("upgrades", key, upgrades[key])
	for key in settings.keys():
		config.set_value("settings", key, settings[key])
	config.save(SAVE_PATH)


func add_dna(amount: int) -> void:
	dna += max(amount, 0)
	save_progress()


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func get_upgrade_cost(upgrade_id: String) -> int:
	var info: Dictionary = UPGRADE_INFO.get(upgrade_id, {})
	var level := get_upgrade_level(upgrade_id)
	return int(info.get("base_cost", 9999)) + int(info.get("cost_step", 0)) * level


func can_buy(upgrade_id: String) -> bool:
	var info: Dictionary = UPGRADE_INFO.get(upgrade_id, {})
	if info.is_empty():
		return false
	var current_level := get_upgrade_level(upgrade_id)
	return current_level < int(info.get("max_level", 0)) and dna >= get_upgrade_cost(upgrade_id)


func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy(upgrade_id):
		return false
	dna -= get_upgrade_cost(upgrade_id)
	upgrades[upgrade_id] = get_upgrade_level(upgrade_id) + 1
	save_progress()
	return true


func get_run_bonuses() -> Dictionary:
	return {
		"max_health_bonus": get_upgrade_level("vitality") * 12.0,
		"damage_multiplier": 1.0 + get_upgrade_level("fury") * 0.06,
		"move_speed_bonus": get_upgrade_level("agility") * 18.0,
	}


func get_setting(key: String, default_value = null):
	if settings.has(key):
		return settings[key]
	return default_value


func set_setting(key: String, value) -> void:
	if not settings.has(key):
		return
	settings[key] = value
	save_progress()

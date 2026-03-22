extends Node

const MUSIC_VOLUME_DB := -14.0
const SFX_VOLUME_DB := -7.0
const SFX_POOL_SIZE := 12

var streams := {}
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var current_music := ""
var next_sfx_index := 0
var last_play_ms := {}


func _ready() -> void:
	_load_streams()
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_VOLUME_DB
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	for _index in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = SFX_VOLUME_DB
		add_child(player)
		sfx_players.append(player)


func play_music(name: String) -> void:
	if current_music == name and music_player.playing:
		return
	var stream: AudioStream = streams.get(name)
	if stream == null:
		return
	current_music = name
	music_player.stop()
	music_player.stream = stream
	music_player.play()


func stop_music() -> void:
	current_music = ""
	music_player.stop()


func play_sfx(name: String, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = streams.get(name)
	if stream == null or sfx_players.is_empty():
		return
	var player := sfx_players[next_sfx_index]
	next_sfx_index = (next_sfx_index + 1) % sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = SFX_VOLUME_DB + volume_offset_db
	player.pitch_scale = pitch_scale
	player.play()


func play_sfx_limited(tag: String, interval_ms: int, name: String, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var now: int = Time.get_ticks_msec()
	var previous: int = int(last_play_ms.get(tag, 0))
	if now - previous < interval_ms:
		return
	last_play_ms[tag] = now
	play_sfx(name, volume_offset_db, pitch_scale)


func _on_music_finished() -> void:
	if current_music != "":
		play_music(current_music)


func _load_streams() -> void:
	var mapping := {
		"player_shot": "res://audio/player_shot.wav",
		"enemy_hit": "res://audio/enemy_hit.wav",
		"enemy_death": "res://audio/enemy_death.wav",
		"player_hurt": "res://audio/player_hurt.wav",
		"xp_collect": "res://audio/xp_collect.wav",
		"upgrade_pick": "res://audio/upgrade_pick.wav",
		"ui_click": "res://audio/ui_click.wav",
		"enemy_charge": "res://audio/enemy_charge.wav",
		"enemy_ray": "res://audio/enemy_ray.wav",
		"run_end": "res://audio/run_end.wav",
		"menu_loop": "res://audio/menu_loop.wav",
		"run_loop": "res://audio/run_loop.wav",
	}
	for key in mapping.keys():
		streams[key] = load(mapping[key])

extends Node

## Runtime audio library for the mastered Katana Kitsune sound set.
## Event families are inferred from numbered filenames, so adding another
## variation to the folder automatically makes it eligible for playback.

const AUDIO_ROOT := "res://assets/audio/generated/final"
const MUSIC_FADE := 0.8
const AMBIENCE_FADE := 1.2
const POSITIONAL_MAX_DISTANCE := 1300.0

var _families: Dictionary = {}
var _exact: Dictionary = {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _status_loop: AudioStreamPlayer
var _ui_players: Array[AudioStreamPlayer] = []
var _last_frames: Dictionary = {}
var _step_cooldown: Dictionary = {}
var _voice_cooldown: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_index_library()
	_music = _loop_player("Music")
	_ambience = _loop_player("Ambience")
	_status_loop = _loop_player("StatusLoop")
	for i in 8:
		var player := AudioStreamPlayer.new()
		player.name = "UI_%02d" % i
		add_child(player)
		_ui_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_wire_tree", get_tree().root)
	call_deferred("_on_scene_changed")


func _process(delta: float) -> void:
	for id in _step_cooldown.keys():
		_step_cooldown[id] = maxf(float(_step_cooldown[id]) - delta, 0.0)
	for id in _voice_cooldown.keys():
		_voice_cooldown[id] = maxf(float(_voice_cooldown[id]) - delta, 0.0)
	_track_footsteps("player")
	_track_footsteps("enemy")
	_update_status_loop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		play("ui_nav_back", -3.0)


func _index_library() -> void:
	for filename in DirAccess.get_files_at(AUDIO_ROOT):
		if not filename.get_extension().to_lower() in ["wav", "ogg"]:
			continue
		var stem := filename.get_basename()
		var path := AUDIO_ROOT.path_join(filename)
		_exact[stem] = path
		var family := stem
		var suffix := RegEx.create_from_string("_[0-9]+$").search(stem)
		if suffix != null:
			family = stem.left(suffix.get_start())
		if not _families.has(family):
			_families[family] = []
		_families[family].append(path)


func has_event(event: String) -> bool:
	return _exact.has(event) or _families.has(event)


func play(event: String, volume_db: float = 0.0, pitch_variance: float = 0.04) -> void:
	var path := _pick(event)
	if path.is_empty():
		return
	var player := _free_ui_player()
	player.stream = load(path)
	player.volume_db = volume_db
	player.pitch_scale = _rng.randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.play()


func play_at(event: String, position: Vector2, volume_db: float = 0.0,
		pitch_variance: float = 0.05) -> void:
	var path := _pick(event)
	if path.is_empty():
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = load(path)
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = _rng.randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.max_distance = POSITIONAL_MAX_DISTANCE
	player.attenuation = 1.2
	get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_for(event: String, source: Node, volume_db: float = 0.0) -> void:
	if source is Node2D:
		play_at(event, (source as Node2D).global_position, volume_db)
	else:
		play(event, volume_db)


func play_music(event: String, volume_db: float = -5.0) -> void:
	_crossfade_loop(_music, event, volume_db, MUSIC_FADE)


func play_ambience(event: String, volume_db: float = -9.0) -> void:
	_crossfade_loop(_ambience, event, volume_db, AMBIENCE_FADE)


func stop_ambience() -> void:
	_fade_out(_ambience, AMBIENCE_FADE)


func _update_status_loop() -> void:
	var low_health := false
	for body in get_tree().get_nodes_in_group("player"):
		if body.get("is_dead") == true:
			continue
		var health = body.get("health")
		var maximum = body.get("max_health")
		if health != null and maximum != null and float(maximum) > 0.0 \
				and float(health) / float(maximum) <= 0.25:
			low_health = true
			break
	if low_health and not _status_loop.playing:
		_crossfade_loop(_status_loop, "ui_low_health_loop", -13.0, 0.25)
	elif not low_health and _status_loop.playing:
		_fade_out(_status_loop, 0.35)


func enemy_event(enemy: Node, action: String) -> void:
	var source := enemy.scene_file_path.to_lower()
	var code := ""
	for entry in [
		["jorogumo", "jor"], ["kappa", "kap"], ["karasu", "kar"],
		["kasha", "kas"], ["ninja", "nin"], ["oni", "oni"],
		["tengu", "ten"], ["yokai", "yok"], ["yuki", "yuk"]]:
		if source.contains(entry[0]):
			code = entry[1]
			break
	if code.is_empty():
		play_for("sfx_enemy_defeat" if action == "death" else "sfx_enemy_" + action, enemy)
		return
	var family := "sfx_enemy_%s_%s" % [code, "hurtdeath" if action in ["hurt", "death"] else action]
	play_for(family, enemy)


func _pick(event: String) -> String:
	if _exact.has(event):
		return _exact[event]
	var choices: Array = _families.get(event, [])
	if choices.is_empty():
		push_warning("Unknown audio event: %s" % event)
		return ""
	return choices[_rng.randi_range(0, choices.size() - 1)]


func _free_ui_player() -> AudioStreamPlayer:
	for player in _ui_players:
		if not player.playing:
			return player
	return _ui_players[_rng.randi_range(0, _ui_players.size() - 1)]


func _loop_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player


func _crossfade_loop(player: AudioStreamPlayer, event: String, target_db: float,
		duration: float) -> void:
	var path := _pick(event)
	if path.is_empty() or (player.stream != null and player.stream.resource_path == path and player.playing):
		return
	var change := func() -> void:
		player.stream = load(path)
		if player.stream is AudioStreamOggVorbis:
			(player.stream as AudioStreamOggVorbis).loop = true
		player.volume_db = -45.0
		player.play()
		create_tween().tween_property(player, "volume_db", target_db, duration)
	if player.playing:
		var fade := create_tween()
		fade.tween_property(player, "volume_db", -45.0, duration * 0.5)
		fade.tween_callback(change)
	else:
		change.call()


func _fade_out(player: AudioStreamPlayer, duration: float) -> void:
	if not player.playing:
		return
	var fade := create_tween()
	fade.tween_property(player, "volume_db", -45.0, duration)
	fade.tween_callback(player.stop)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path.to_lower()
	if path.contains("title"):
		play_music("music_main_theme")
		stop_ambience()
	elif path.contains("characterselect"):
		play_music("music_character_select")
	elif path.contains("onlinelobby"):
		play_music("music_online_lobby")
	elif path.contains("maze") or path.contains("game"):
		play_music("music_exploration")
		play_ambience("amb_sakura_gardens")


func _on_node_added(node: Node) -> void:
	call_deferred("_wire_tree", node)


func _wire_tree(root: Node) -> void:
	if not is_instance_valid(root):
		return
	if root is BaseButton:
		var button := root as BaseButton
		if not button.has_meta("audio_wired"):
			button.set_meta("audio_wired", true)
			button.focus_entered.connect(play.bind("ui_nav_move", -5.0, 0.03))
			button.mouse_entered.connect(play.bind("ui_nav_move", -7.0, 0.03))
			button.pressed.connect(play.bind("ui_nav_confirm", -3.0, 0.02))
	elif root is LineEdit:
		var line := root as LineEdit
		if not line.has_meta("audio_wired"):
			line.set_meta("audio_wired", true)
			line.text_changed.connect(func(_text: String) -> void: play("ui_dialogue_type", -9.0, 0.08))
	for child in root.get_children():
		_wire_tree(child)


func _track_footsteps(group: String) -> void:
	for body in get_tree().get_nodes_in_group(group):
		if not (body is Node2D) or body.get("is_dead") == true:
			continue
		var sprite := body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite == null or not sprite.is_playing():
			continue
		var animation := String(sprite.animation).to_lower()
		if not (animation.contains("walk") or animation.contains("run")):
			continue
		var id := body.get_instance_id()
		var marker := "%s:%d" % [sprite.animation, sprite.frame]
		if _last_frames.get(id, "") == marker:
			continue
		_last_frames[id] = marker
		if float(_step_cooldown.get(id, 0.0)) > 0.0 or sprite.frame % 3 != 1:
			continue
		_step_cooldown[id] = 0.18 if animation.contains("run") else 0.3
		if group == "enemy":
			var heavy: bool = (body as Node2D).scale.x > 1.25 \
					or body.scene_file_path.to_lower().contains("oni")
			play_for("sfx_enemy_step_heavy" if heavy else "sfx_enemy_step_light", body, -7.0)
		elif animation.contains("stealth") or animation.contains("ninja"):
			play_for("sfx_player_stealth_step", body, -9.0)
		elif animation.contains("run"):
			play_for("sfx_player_step_run", body, -5.0)
		else:
			var event := "sfx_player_step_hard_walk"
			var scene := get_tree().current_scene
			var theme = scene.get("_level_theme") if scene != null else null
			if theme != null and theme.id == LevelTheme.Id.FROZEN_PASS:
				event = "sfx_player_step_snow_walk"
			elif scene != null and scene.get("_ext") != null:
				event = "sfx_player_step_earth_walk"
			play_for(event, body, -7.0)
		if body.has_method("winded") and body.winded() and float(_voice_cooldown.get(id, 0.0)) <= 0.0:
			_voice_cooldown[id] = 4.0
			play_for("vox_kitsune_exhausted", body, -8.0)

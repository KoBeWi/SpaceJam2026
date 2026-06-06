extends Node2D

const PLAYER_SPEED: float = 300.0
const PLAYER_RADIUS: float = 14.0
const MAX_RADIATION: float = 100.0
const SURVIVE_SECONDS: float = 90.0
const BASE_ZONE_COUNT: int = 4
const MAX_ZONES: int = 8
const ZONE_ADD_INTERVAL: float = 18.0
const MAX_PICKUPS: int = 4
const PICKUP_INTERVAL_BASE: float = 8.8
const PICKUP_INTERVAL_MIN: float = 4.6
const SAMPLE_RATE: int = 44100
const BEST_SCORE_SAVE_PATH: String = "user://save.cfg"

var player_position: Vector2
var shelter_position: Vector2
var shelter_radius: float = 70.0
var radiation_level: float = 0.0
var elapsed_time: float = 0.0
var pickup_timer: float = 0.0
var zone_spawn_timer: float = 0.0
var iodine_collected: int = 0
var danger_level: float = 0.0
var difficulty_level: float = 1.0
var score: int = 0
var best_score: int = 0
var flash_timer: float = 0.0
var geiger_timer: float = 0.1
var game_over: bool = false
var won: bool = false
var paused: bool = false
var audio_muted: bool = false
var prev_pause_pressed: bool = false
var prev_mute_pressed: bool = false

var zones: Array[Dictionary] = []
var pickups: Array[Vector2] = []

var hud_label: Label
var info_label: Label

var music_player: AudioStreamPlayer
var alarm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var audio_library: Dictionary = {}

func _ready() -> void:
	randomize()
	best_score = _load_best_score()
	player_position = get_viewport_rect().size * 0.5
	shelter_position = _find_safe_point(180.0)
	_create_zones()
	_create_ui()
	_create_audio()
	_update_hud()
	queue_redraw()

func _physics_process(delta: float) -> void:
	_handle_global_input()
	if paused and not game_over:
		_update_hud()
		queue_redraw()
		return

	if game_over:
		_update_game_over_audio(delta)
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		if Input.is_key_pressed(KEY_ESCAPE):
			get_tree().change_scene_to_file("res://Title.tscn")
		return

	elapsed_time += delta
	pickup_timer += delta
	zone_spawn_timer += delta
	flash_timer = maxf(flash_timer - delta, 0.0)
	difficulty_level = 1.0 + (elapsed_time / SURVIVE_SECONDS) * 1.35

	_move_player(delta)
	_update_zones(delta)
	_update_pickups()
	_apply_radiation(delta)
	_spawn_progression_content()
	_update_score(delta)
	_update_audio(delta)

	if radiation_level >= MAX_RADIATION:
		_finish_game(false)
	elif elapsed_time >= SURVIVE_SECONDS:
		_finish_game(true)

	_update_hud()
	queue_redraw()

func _draw() -> void:
	var view_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("0c1320"))
	_draw_background_grid(view_size)

	if radiation_level > 55.0:
		var vignette_alpha := clampf((radiation_level - 55.0) / 55.0, 0.0, 0.35)
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.95, 0.12, 0.08, vignette_alpha))

	draw_circle(shelter_position, shelter_radius, Color(0.25, 0.78, 0.36, 0.22))
	draw_arc(shelter_position, shelter_radius, 0.0, TAU, 42, Color(0.45, 1.0, 0.58, 0.75), 3.0)

	for zone in zones:
		var l_position: Vector2 = zone["position"]
		var l_radius: float = zone["radius"]
		draw_circle(l_position, l_radius, Color(0.32, 0.95, 0.18, 0.12))
		draw_circle(l_position, l_radius * 0.52, Color(0.7, 1.0, 0.45, 0.2))
		draw_arc(l_position, l_radius, 0.0, TAU, 30, Color(0.8, 1.0, 0.55, 0.58), 2.2)

	for pickup in pickups:
		draw_circle(pickup, 10.0, Color(0.4, 0.88, 1.0, 0.95))
		draw_arc(pickup, 14.0, 0.0, TAU, 16, Color(0.7, 0.97, 1.0, 0.8), 2.0)

	var player_color := Color(0.95, 0.97, 1.0, 1.0)
	if flash_timer > 0.0:
		player_color = Color(1.0, 0.65, 0.65, 1.0)
	draw_circle(player_position, PLAYER_RADIUS, player_color)
	draw_arc(player_position, PLAYER_RADIUS + 4.0, 0.0, TAU, 24, Color(0.45, 0.84, 1.0, 0.85), 2.2)

func _draw_background_grid(view_size: Vector2) -> void:
	var step: float = 44.0
	var line_color := Color(0.2, 0.28, 0.39, 0.22)

	var x := 0.0
	while x <= view_size.x:
		draw_line(Vector2(x, 0), Vector2(x, view_size.y), line_color, 1.0)
		x += step

	var y := 0.0
	while y <= view_size.y:
		draw_line(Vector2(0, y), Vector2(view_size.x, y), line_color, 1.0)
		y += step

func _move_player(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player_position += direction * PLAYER_SPEED * delta
	var view_size := get_viewport_rect().size
	player_position.x = clampf(player_position.x, PLAYER_RADIUS, view_size.x - PLAYER_RADIUS)
	player_position.y = clampf(player_position.y, PLAYER_RADIUS, view_size.y - PLAYER_RADIUS)

func _update_zones(delta: float) -> void:
	var view_size := get_viewport_rect().size
	for i in zones.size():
		var zone := zones[i]
		var position: Vector2 = zone["position"]
		var base_velocity: Vector2 = zone["velocity"]
		var radius_base: float = zone["base_radius"]
		var pulse_offset: float = zone["pulse_offset"]

		var speed_scale := 0.72 + difficulty_level * 0.58
		var velocity := base_velocity * speed_scale
		position += velocity * delta

		var radius := radius_base + sin((elapsed_time * 1.2) + pulse_offset) * 8.0
		radius = clampf(radius, 52.0, 140.0)

		if position.x < radius or position.x > view_size.x - radius:
			base_velocity.x *= -1.0
		if position.y < radius or position.y > view_size.y - radius:
			base_velocity.y *= -1.0

		position.x = clampf(position.x, radius, view_size.x - radius)
		position.y = clampf(position.y, radius, view_size.y - radius)

		zone["position"] = position
		zone["velocity"] = base_velocity
		zone["radius"] = radius
		zones[i] = zone

func _apply_radiation(delta: float) -> void:
	var exposure := 0.0
	for zone in zones:
		var zone_position: Vector2 = zone["position"]
		var radius: float = zone["radius"]
		var intensity: float = zone["intensity"]
		var dist := player_position.distance_to(zone_position)
		if dist < radius:
			exposure += (1.0 - dist / radius) * intensity

	var in_shelter := player_position.distance_to(shelter_position) <= shelter_radius
	var recovery := 5.0
	if in_shelter:
		recovery = 30.0
		score += int(6.0 * delta)

	danger_level = clampf(exposure / 2.9, 0.0, 1.0)
	var pressure_scale := 0.82 + (difficulty_level - 1.0) * 0.55
	radiation_level += exposure * delta * 12.5 * pressure_scale
	radiation_level -= recovery * delta
	radiation_level = clampf(radiation_level, 0.0, MAX_RADIATION)

	if exposure > 1.35:
		flash_timer = 0.08

func _update_pickups() -> void:
	for i in range(pickups.size() - 1, -1, -1):
		if player_position.distance_to(pickups[i]) <= PLAYER_RADIUS + 12.0:
			pickups.remove_at(i)
			radiation_level = maxf(radiation_level - 22.0, 0.0)
			iodine_collected += 1
			score += 150
			_play_named_sfx("pickup")

func _spawn_progression_content() -> void:
	var progress := clampf((difficulty_level - 1.0) / 1.35, 0.0, 1.0)
	var pickup_interval := lerpf(PICKUP_INTERVAL_BASE, PICKUP_INTERVAL_MIN, progress)
	if pickup_timer >= pickup_interval and pickups.size() < MAX_PICKUPS:
		pickup_timer = 0.0
		_spawn_pickup()

	if zone_spawn_timer >= ZONE_ADD_INTERVAL and zones.size() < MAX_ZONES:
		zone_spawn_timer = 0.0
		_add_zone()
		_play_named_sfx("zone_up")

func _spawn_pickup() -> void:
	var point := _find_safe_point(90.0)
	pickups.append(point)

func _find_safe_point(min_distance: float) -> Vector2:
	var view_size := get_viewport_rect().size
	var candidate := Vector2(view_size.x * 0.5, view_size.y * 0.5)
	for _i in 24:
		candidate = Vector2(
			randf_range(50.0, view_size.x - 50.0),
			randf_range(50.0, view_size.y - 50.0)
		)
		if candidate.distance_to(player_position) >= min_distance and candidate.distance_to(shelter_position) >= min_distance * 0.7:
			return candidate
	return candidate

func _create_zones() -> void:
	for _i in BASE_ZONE_COUNT:
		_add_zone()

func _add_zone() -> void:
	var view_size := get_viewport_rect().size
	var zone_position := Vector2(
		randf_range(86.0, view_size.x - 86.0),
		randf_range(86.0, view_size.y - 86.0)
	)
	zones.append({
		"position": zone_position,
		"radius": randf_range(68.0, 120.0),
		"base_radius": randf_range(68.0, 120.0),
		"intensity": randf_range(0.65, 1.35),
		"velocity": Vector2(randf_range(-88.0, 88.0), randf_range(-88.0, 88.0)),
		"pulse_offset": randf_range(0.0, TAU)
	})

func _update_score(delta: float) -> void:
	score += int((1.6 + difficulty_level * 0.42) * delta * 11.0)

func _finish_game(did_win: bool) -> void:
	if game_over:
		return
	game_over = true
	won = did_win
	if score > best_score:
		best_score = score
		_save_best_score(best_score)

	if won:
		_play_named_sfx("win")
	else:
		_play_named_sfx("lose")

	if alarm_player != null:
		alarm_player.volume_db = -80.0

	_update_hud()

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hud_label = Label.new()
	hud_label.position = Vector2(18, 14)
	hud_label.add_theme_font_size_override("font_size", 21)
	layer.add_child(hud_label)

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.size = get_viewport_rect().size
	info_label.add_theme_font_size_override("font_size", 32)
	info_label.visible = false
	layer.add_child(info_label)

func _update_hud() -> void:
	var time_left := maxf(SURVIVE_SECONDS - elapsed_time, 0.0)
	var danger_percent := int(round(danger_level * 100.0))
	var audio_state := "OFF" if audio_muted else "ON"
	hud_label.text = "Promieniowanie: %.0f%%\nCzas do ewakuacji: %.0fs\nPoziom zagrozenia: %d%%\nPunkty: %d   Rekord: %d\nTabletki jodowe: %d\n[P] Pauza  [M] Audio: %s" % [radiation_level, time_left, danger_percent, score, best_score, iodine_collected, audio_state]

	if game_over:
		info_label.visible = true
		if won:
			info_label.text = "Ewakuacja udana!\nWynik: %d   Rekord: %d\n[R] Zagraj ponownie   [ESC] Menu" % [score, best_score]
		else:
			info_label.text = "Przekroczona dawka promieniowania.\nWynik: %d   Rekord: %d\n[R] Sprobuj jeszcze raz   [ESC] Menu" % [score, best_score]
	elif paused:
		info_label.visible = true
		info_label.text = "PAUZA\n[P] Wznow   [ESC] Menu"
	else:
		info_label.visible = false

func _handle_global_input() -> void:
	var pause_pressed := Input.is_key_pressed(KEY_P)
	if pause_pressed and not prev_pause_pressed and not game_over:
		paused = not paused
	prev_pause_pressed = pause_pressed

	var mute_pressed := Input.is_key_pressed(KEY_M)
	if mute_pressed and not prev_mute_pressed:
		audio_muted = not audio_muted
		AudioServer.set_bus_mute(0, audio_muted)
	prev_mute_pressed = mute_pressed

func _create_audio() -> void:
	_build_audio_library()

	music_player = AudioStreamPlayer.new()
	music_player.stream = audio_library["music"]
	music_player.volume_db = -16.0
	add_child(music_player)
	music_player.play()

	alarm_player = AudioStreamPlayer.new()
	alarm_player.stream = audio_library["alarm_loop"]
	alarm_player.volume_db = -80.0
	add_child(alarm_player)
	alarm_player.play()

	for _i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		sfx_players.append(player)

func _build_audio_library() -> void:
	audio_library["music"] = _make_loop_stream(4.0, [[92.0, 0.2, "sine"], [138.0, 0.13, "sine"], [184.0, 0.09, "triangle"]], 0.9)
	audio_library["alarm_loop"] = _make_loop_stream(0.7, [[680.0, 0.2, "sine"]], 0.65, 4.0)
	audio_library["geiger_a"] = _make_tone_stream(1500.0, 0.03, 0.4, "square")
	audio_library["geiger_b"] = _make_tone_stream(2000.0, 0.026, 0.4, "square")
	audio_library["pickup"] = _make_sequence_stream([
		{"freq": 720.0, "duration": 0.07, "volume": 0.35, "wave": "triangle"},
		{"freq": 1080.0, "duration": 0.08, "volume": 0.3, "wave": "sine"}
	])
	audio_library["zone_up"] = _make_sequence_stream([
		{"freq": 260.0, "duration": 0.08, "volume": 0.35, "wave": "saw"},
		{"freq": 210.0, "duration": 0.08, "volume": 0.4, "wave": "saw"}
	])
	audio_library["win"] = _make_sequence_stream([
		{"freq": 520.0, "duration": 0.12, "volume": 0.35, "wave": "triangle"},
		{"freq": 660.0, "duration": 0.12, "volume": 0.32, "wave": "triangle"},
		{"freq": 820.0, "duration": 0.18, "volume": 0.3, "wave": "sine"}
	])
	audio_library["lose"] = _make_sequence_stream([
		{"freq": 280.0, "duration": 0.12, "volume": 0.38, "wave": "saw"},
		{"freq": 220.0, "duration": 0.18, "volume": 0.4, "wave": "saw"},
		{"freq": 160.0, "duration": 0.2, "volume": 0.42, "wave": "sine"}
	])

func _update_audio(delta: float) -> void:
	if music_player != null:
		music_player.volume_db = lerpf(-18.0, -11.0, clampf(radiation_level / MAX_RADIATION, 0.0, 1.0))

	var alarm_target := -80.0
	if radiation_level > 70.0:
		alarm_target = lerpf(-26.0, -12.0, clampf((radiation_level - 70.0) / 30.0, 0.0, 1.0))
	if alarm_player != null:
		alarm_player.volume_db = lerpf(alarm_player.volume_db, alarm_target, 4.2 * delta)

	geiger_timer -= delta
	if geiger_timer <= 0.0:
		var click_intensity := clampf(danger_level * 0.7 + (radiation_level / MAX_RADIATION) * 0.55, 0.0, 1.0)
		if click_intensity > 0.08:
			if randf() > 0.45:
				_play_named_sfx("geiger_a", -12.0 + click_intensity * 8.0, randf_range(0.95, 1.08))
			else:
				_play_named_sfx("geiger_b", -12.0 + click_intensity * 8.0, randf_range(0.92, 1.08))
		geiger_timer = lerpf(0.52, 0.07, click_intensity)

func _update_game_over_audio(delta: float) -> void:
	if music_player != null:
		music_player.volume_db = lerpf(music_player.volume_db, -24.0, 2.0 * delta)

func _play_named_sfx(name: String, volume_db: float = -5.0, pitch_scale: float = 1.0) -> void:
	if not audio_library.has(name):
		return
	for player in sfx_players:
		if not player.playing:
			player.stream = audio_library[name]
			player.volume_db = volume_db
			player.pitch_scale = pitch_scale
			player.play()
			return

	# If all players are busy, replace one to keep feedback snappy.
	var fallback := sfx_players[0]
	fallback.stop()
	fallback.stream = audio_library[name]
	fallback.volume_db = volume_db
	fallback.pitch_scale = pitch_scale
	fallback.play()

func _make_tone_stream(freq: float, duration: float, volume: float, wave: String) -> AudioStreamWAV:
	var sample_count := maxf(1.0, int(duration * SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)

	for i in sample_count:
		var t := float(i) / float(SAMPLE_RATE)
		var phase := fposmod(t * freq, 1.0)
		var envelope := _adsr(i, sample_count, 0.02, 0.75)
		var amp := _wave_sample(phase, wave) * volume * envelope
		_write_pcm16_mono(pcm, i * 2, amp)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

func _make_sequence_stream(notes: Array[Dictionary]) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	for note in notes:
		var stream := _make_tone_stream(note["freq"], note["duration"], note["volume"], note["wave"])
		pcm.append_array(stream.data)

	var final_stream := AudioStreamWAV.new()
	final_stream.format = AudioStreamWAV.FORMAT_16_BITS
	final_stream.mix_rate = SAMPLE_RATE
	final_stream.stereo = false
	final_stream.data = pcm
	return final_stream

func _make_loop_stream(duration: float, layers: Array, volume_scale: float = 1.0, pulse_hz: float = 0.0) -> AudioStreamWAV:
	var sample_count := maxf(1, int(duration * SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)

	for i in sample_count:
		var t := float(i) / float(SAMPLE_RATE)
		var amp := 0.0
		for layer in layers:
			var freq: float = layer[0]
			var layer_amp: float = layer[1]
			var wave: String = layer[2]
			var phase := fposmod(t * freq, 1.0)
			amp += _wave_sample(phase, wave) * layer_amp

		if pulse_hz > 0.0:
			amp *= 0.66 + 0.34 * (0.5 + 0.5 * sin(TAU * pulse_hz * t))

		amp *= volume_scale
		_write_pcm16_mono(pcm, i * 2, amp)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _wave_sample(phase: float, wave: String) -> float:
	if wave == "square":
		return 1.0 if phase < 0.5 else -1.0
	if wave == "triangle":
		return 1.0 - 4.0 * absf(phase - 0.5)
	if wave == "saw":
		return 2.0 * phase - 1.0
	return sin(TAU * phase)

func _adsr(index: int, total: int, attack_pct: float, release_pct: float) -> float:
	var attack_len := maxf(1, int(float(total) * attack_pct))
	var release_len := maxf(1, int(float(total) * release_pct))
	if index < attack_len:
		return float(index) / float(attack_len)
	if index > total - release_len:
		var release_pos := float(index - (total - release_len)) / float(release_len)
		return maxf(1.0 - release_pos, 0.0)
	return 1.0

func _write_pcm16_mono(pcm: PackedByteArray, offset: int, value: float) -> void:
	var sample := int(round(clampf(value, -1.0, 1.0) * 32767.0))
	if sample < 0:
		sample += 65536
	pcm[offset] = sample & 0xFF
	pcm[offset + 1] = (sample >> 8) & 0xFF

func _load_best_score() -> int:
	var config := ConfigFile.new()
	var err := config.load(BEST_SCORE_SAVE_PATH)
	if err != OK:
		return 0
	return int(config.get_value("score", "best", 0))

func _save_best_score(value: int) -> void:
	var config := ConfigFile.new()
	config.set_value("score", "best", value)
	config.save(BEST_SCORE_SAVE_PATH)

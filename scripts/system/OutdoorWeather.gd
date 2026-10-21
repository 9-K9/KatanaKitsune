class_name OutdoorWeather
extends Node2D

const PARTICLES := preload("res://scenes/weather/outdoor_particles.tscn")
const PARTICLE_CAP: int = 1024
const TRANSITION_SECONDS: float = 6.0
const MAX_VIEWS: int = 4

var current: int = ExteriorBiome.Weather.CALM
var intensity: float = 0.0
var _rng := RandomNumberGenerator.new()
var _forced: int = -1
var _strength: float = 1.0
var _remaining: float = 0.0
var _target: int = ExteriorBiome.Weather.CALM
var _available: Array[int] = [ExteriorBiome.Weather.CALM]
var _emitters: Dictionary = {}
var _mask: Texture2D
var _origin := Vector2.ZERO
var _inverse := Vector4.ZERO
var _grid := Vector2i.ONE
var _coverage := Rect2()
var _view_history: Array[Rect2] = []
var _history_times: Array[float] = []
var _clock: float = 0.0
var _audio_weather: int = ExteriorBiome.Weather.CALM


func setup(exterior: MazeExterior, seed_value: int, forced: int, strength: float) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = seed_value ^ 0x57454154
	_strength = clampf(strength, 0.0, 1.0)
	_grid = exterior.weather_grid()
	_origin = exterior.cell_centre(Vector2i.ZERO)
	_inverse = exterior.weather_inverse_lattice()
	_mask = exterior.weather_mask()
	for weather in exterior.biome.compatible_weather:
		if weather == ExteriorBiome.Weather.CALM:
			continue
		if not exterior.biome.weather_available(weather):
			push_warning("OutdoorWeather: effect %d awaits reviewed texture at %s." % [
					weather, ExteriorBiome.particle_path(weather)])
			continue
		_available.append(weather)
		_create_emitter(weather, load(ExteriorBiome.particle_path(weather)) as Texture2D)
	if forced >= 0:
		_forced = forced
		if not _available.has(forced):
			push_warning("OutdoorWeather: forced effect unavailable or incompatible; using calm.")
			_forced = ExteriorBiome.Weather.CALM
		_target = _forced
	_remaining = _rng.randf_range(35.0, 65.0)


func _create_emitter(weather: int, texture: Texture2D) -> void:
	var particles := PARTICLES.instantiate() as GPUParticles2D
	particles.name = "Weather_%d" % weather
	particles.texture = texture
	particles.amount = PARTICLE_CAP / 4
	particles.use_fixed_seed = true
	particles.seed = _rng.randi()
	particles.z_index = 100
	particles.z_as_relative = false
	add_child(particles)
	_emitters[weather] = particles
	var simulation := particles.process_material as ShaderMaterial
	var drawing := particles.material as ShaderMaterial
	for material in [simulation, drawing]:
		material.set_shader_parameter("outdoor_mask", _mask)
		material.set_shader_parameter("grid_size", Vector2(_grid))
		material.set_shader_parameter("lattice_origin", _origin)
		material.set_shader_parameter("inverse_lattice", _inverse)
	match weather:
		ExteriorBiome.Weather.PETALS:
			simulation.set_shader_parameter("wind", Vector2(90.0, 22.0))
			simulation.set_shader_parameter("fall_speed", 40.0)
			simulation.set_shader_parameter("flutter", 25.0)
		ExteriorBiome.Weather.RAIN:
			particles.lifetime = 0.5
			simulation.set_shader_parameter("wind", Vector2(30.0, 8.0))
			simulation.set_shader_parameter("fall_speed", 420.0)
		ExteriorBiome.Weather.SNOWFALL:
			simulation.set_shader_parameter("wind", Vector2(32.0, 8.0))
			simulation.set_shader_parameter("fall_speed", 50.0)
			simulation.set_shader_parameter("flutter", 18.0)
		ExteriorBiome.Weather.SANDSTORM:
			simulation.set_shader_parameter("wind", Vector2(240.0, 60.0))
			simulation.set_shader_parameter("fall_speed", 35.0)
			simulation.set_shader_parameter("flutter", 12.0)


func update_weather(delta: float, views: Array[Rect2]) -> void:
	if _emitters.is_empty():
		return
	_clock += delta
	if views.is_empty():
		for particles: GPUParticles2D in _emitters.values():
			particles.emitting = false
		return
	var coverage: Rect2 = views[0]
	var shader_views := PackedVector4Array()
	for i in mini(views.size(), MAX_VIEWS):
		var view := views[i].grow(180.0)
		coverage = coverage.merge(view)
		shader_views.append(Vector4(view.position.x, view.position.y, view.size.x, view.size.y))
	while shader_views.size() < MAX_VIEWS:
		shader_views.append(Vector4.ZERO)
	_coverage = coverage
	# Only four seconds of surviving world-space particles affect culling bounds.
	if _history_times.is_empty() or _clock - _history_times[-1] >= 0.1:
		_view_history.append(_coverage)
		_history_times.append(_clock)
	while not _history_times.is_empty() and _clock - _history_times[0] > 4.2:
		_history_times.pop_front()
		_view_history.pop_front()
	var bounds := _coverage
	for previous in _view_history:
		bounds = bounds.merge(previous)
	if _forced < 0:
		_remaining -= delta
		if _remaining <= 0.0:
			if _target != ExteriorBiome.Weather.CALM:
				_target = ExteriorBiome.Weather.CALM
			elif _available.size() > 1:
				_target = _available[_rng.randi_range(1, _available.size() - 1)]
			_remaining = _rng.randf_range(35.0, 65.0)
	var desired: float = _strength if current == _target and current != ExteriorBiome.Weather.CALM else 0.0
	intensity = move_toward(intensity, desired, delta / TRANSITION_SECONDS)
	if intensity <= 0.0 and current != _target:
		current = _target
	if current != _audio_weather:
		_audio_weather = current
		match current:
			ExteriorBiome.Weather.PETALS:
				AudioManager.play_ambience("amb_weather_petals", -11.0)
			ExteriorBiome.Weather.RAIN:
				AudioManager.play_ambience("amb_weather_rain", -9.0)
			ExteriorBiome.Weather.SNOWFALL:
				AudioManager.play_ambience("amb_weather_snow", -10.0)
			ExteriorBiome.Weather.SANDSTORM:
				AudioManager.play_ambience("amb_weather_sandstorm", -8.0)
	for weather: int in _emitters:
		var particles: GPUParticles2D = _emitters[weather]
		var simulation := particles.process_material as ShaderMaterial
		var active: bool = weather == current
		simulation.set_shader_parameter("opacity", intensity if active else 0.0)
		simulation.set_shader_parameter("coverage", Vector4(_coverage.position.x,
				_coverage.position.y, _coverage.size.x, _coverage.size.y))
		simulation.set_shader_parameter("views", shader_views)
		simulation.set_shader_parameter("view_count", mini(views.size(), MAX_VIEWS))
		simulation.set_shader_parameter("weather_time", _clock)
		particles.emitting = active and intensity > 0.0
		particles.visibility_rect = particles.global_transform.affine_inverse() * bounds.grow(220.0)


func stop() -> void:
	for particles: GPUParticles2D in _emitters.values():
		particles.emitting = false
		particles.visible = false

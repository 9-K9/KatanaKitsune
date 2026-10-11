shader_type particles;
render_mode disable_force, disable_velocity;

uniform sampler2D outdoor_mask : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(4.0);
uniform vec2 lattice_origin = vec2(0.0);
uniform vec4 inverse_lattice = vec4(0.000744, 0.001488, -0.000744, 0.001488);
uniform vec4 coverage = vec4(-768.0, -432.0, 1536.0, 864.0);
uniform vec4 views[4];
uniform int view_count = 0;
uniform vec2 wind = vec2(70.0, 20.0);
uniform float fall_speed = 100.0;
uniform float height_max = 140.0;
uniform float opacity = 0.0;
uniform float flutter = 0.0;
uniform float weather_time = 0.0;

vec2 lattice(vec2 ground) {
	vec2 q = ground - lattice_origin;
	return vec2(dot(q, inverse_lattice.xy), dot(q, inverse_lattice.zw));
}

bool outdoor_cell(vec2 cell) {
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThanEqual(cell, grid_size))) {
		return false;
	}
	return texture(outdoor_mask, (cell + 0.5) / grid_size).r > 0.5;
}

bool outside(vec2 ground) {
	return outdoor_cell(floor(lattice(ground) + 0.5));
}

bool outdoor_segment(vec2 from, vec2 to) {
	vec2 a = lattice(from) + 0.5;
	vec2 b = lattice(to) + 0.5;
	vec2 cell = floor(a);
	vec2 end = floor(b);
	vec2 d = b - a;
	vec2 direction = sign(d);
	vec2 interval = 1.0 / max(abs(d), vec2(0.000001));
	vec2 next = (cell + step(vec2(0.0), d) - a) / mix(vec2(0.000001), d, greaterThan(abs(d), vec2(0.000001)));
	for (int i = 0; i < 8; i++) {
		if (!outdoor_cell(cell)) {
			return false;
		}
		if (all(equal(cell, end))) {
			return true;
		}
		if (abs(next.x - next.y) < 0.00001) {
			if (!outdoor_cell(cell + vec2(direction.x, 0.0))
					|| !outdoor_cell(cell + vec2(0.0, direction.y))) {
				return false;
			}
			cell += direction;
			next += interval;
		} else if (next.x < next.y) {
			cell.x += direction.x;
			next.x += interval.x;
		} else {
			cell.y += direction.y;
			next.y += interval.y;
		}
	}
	return false;
}

bool covered(vec2 ground) {
	for (int i = 0; i < 4; i++) {
		if (i < view_count && all(greaterThanEqual(ground, views[i].xy))
				&& all(lessThanEqual(ground, views[i].xy + views[i].zw))) {
			return true;
		}
	}
	return false;
}

uint hash(uint n) {
	n = (n ^ (n >> 16u)) * 0x45d9f3bu;
	n = (n ^ (n >> 16u)) * 0x45d9f3bu;
	return n ^ (n >> 16u);
}

float random_value(inout uint seed) {
	seed = hash(seed);
	return float(seed % 65536u) / 65535.0;
}

void start() {
	uint seed = hash(NUMBER + RANDOM_SEED);
	CUSTOM.xy = coverage.xy + vec2(random_value(seed), random_value(seed)) * coverage.zw;
	CUSTOM.z = height_max * (0.25 + random_value(seed) * 0.75);
	CUSTOM.w = random_value(seed) * 6.283185;
	TRANSFORM[3].xy = CUSTOM.xy - vec2(0.0, CUSTOM.z);
	COLOR = vec4(1.0, 1.0, 1.0, opacity);
	if (!covered(CUSTOM.xy) || !outside(CUSTOM.xy) || !outside(TRANSFORM[3].xy)) {
		ACTIVE = false;
	}
}

void process() {
	vec2 previous = CUSTOM.xy;
	vec2 drift = wind * (0.7 + 0.3 * sin(weather_time * 0.7))
			+ vec2(sin(CUSTOM.w + weather_time * 2.0) * flutter, 0.0);
	// Bound the swept step even after a long frame, rather than skipping a footprint.
	float step = min(DELTA, 0.05);
	CUSTOM.xy += drift * step;
	CUSTOM.z -= fall_speed * step;
	TRANSFORM[3].xy = CUSTOM.xy - vec2(0.0, CUSTOM.z);
	COLOR.a = opacity * smoothstep(0.0, 16.0, CUSTOM.z);
	if (!outdoor_segment(previous, CUSTOM.xy)) {
		ACTIVE = false;
	}
	if (CUSTOM.z <= 0.0 || !covered(CUSTOM.xy) || !outside(TRANSFORM[3].xy)) {
		ACTIVE = false;
	}
}

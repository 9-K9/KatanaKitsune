shader_type canvas_item;
render_mode unshaded, world_vertex_coords;

uniform sampler2D outdoor_mask : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(4.0);
uniform vec2 lattice_origin = vec2(0.0);
uniform vec4 inverse_lattice = vec4(0.000744, 0.001488, -0.000744, 0.001488);
varying vec2 world_pixel;
varying float height;

bool outside(vec2 ground) {
	vec2 q = ground - lattice_origin;
	vec2 cell = floor(vec2(dot(q, inverse_lattice.xy), dot(q, inverse_lattice.zw)) + 0.5);
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThanEqual(cell, grid_size))) {
		return false;
	}
	return texture(outdoor_mask, (cell + 0.5) / grid_size).r > 0.5;
}

void vertex() {
	world_pixel = VERTEX;
	height = INSTANCE_CUSTOM.z;
}

void fragment() {
	if (!outside(world_pixel + vec2(0.0, height)) || !outside(world_pixel)) {
		discard;
	}
}

shader_type canvas_item;

// Fades the stretch of wall covering the player, rather than dimming every
// front wall in the map at once.
//
// Whether she is actually behind a wall is decided on the CPU in WallFade.gd
// and arrives as `behind`. A shader cannot answer it: a wall's pixels span
// ~350px upward from its base, so testing the pixel's own y only ever matched
// the bottom strip — which fell out as a fade around her feet that also fired
// while she stood in front of the wall.

// Player position in world space — her feet, since that is the body origin.
uniform vec2 player_world = vec2(0.0);
// 1.0 when she is behind a wall on this layer, 0.0 when she is not.
uniform float behind = 0.0;
// Half-size of the cutout. Tall and narrow, to match a character silhouette
// rather than a circle on the ground.
uniform vec2 extents = vec2(52.0, 105.0);
// How far above her feet to centre the cutout, so it covers her, not the floor.
uniform float rise = 86.0;
// Distance beyond `extents` over which the wall returns to solid.
uniform float softness : hint_range(0.01, 2.0) = 0.55;
// Never fully invisible; a ghost of the wall keeps the room readable.
uniform float min_alpha : hint_range(0.0, 1.0) = 0.18;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);

	vec2 centre = player_world - vec2(0.0, rise);
	// Normalised distance through an ellipse: 1.0 exactly on its edge.
	float d = length((world_pos - centre) / extents);
	float ring = smoothstep(1.0, 1.0 + softness, d);

	float fade = mix(min_alpha, 1.0, ring);
	COLOR.a *= mix(1.0, fade, behind);
}

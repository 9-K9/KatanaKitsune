shader_type canvas_item;

// Fades the stretch of wall covering anyone standing behind it, rather than
// dimming every front wall in the map at once.
//
// Takes a list of subjects, not just the player: a monster behind a wall was
// invisible while its health bar floated over the stone.
//
// Which of them are actually behind this layer is decided on the CPU in
// WallFade.gd and arrives already filtered. A shader cannot answer it — a
// wall's pixels run ~350px up from its base, so testing a pixel's own y only
// ever matched the bottom strip, which came out as a fade around the feet that
// also fired while standing in front of the wall.

const int MAX_SUBJECTS = 8;

// World positions of everyone this layer is currently covering. Feet, since
// that is the body origin.
uniform vec2 subjects[MAX_SUBJECTS];
uniform int subject_count = 0;
// Half-size of the cutout. Tall and narrow, to match a character silhouette
// rather than a circle on the ground.
uniform vec2 extents = vec2(52.0, 105.0);
// How far above the feet to centre the cutout, so it covers them, not the floor.
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

	// Whoever is most exposed at this pixel wins, so overlapping cutouts merge
	// instead of one subject re-solidifying the wall over another.
	float fade = 1.0;
	for (int i = 0; i < MAX_SUBJECTS; i++) {
		if (i >= subject_count) {
			break;
		}
		vec2 centre = subjects[i] - vec2(0.0, rise);
		// Normalised distance through an ellipse: 1.0 exactly on its edge.
		float d = length((world_pos - centre) / extents);
		fade = min(fade, mix(min_alpha, 1.0, smoothstep(1.0, 1.0 + softness, d)));
	}

	COLOR.a *= fade;
}

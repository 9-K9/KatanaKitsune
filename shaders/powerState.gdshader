shader_type canvas_item;

// Clothing-only elemental recolour for Katana Kitsune.
//
// The sprites carry their clothing as pure-red pixels (green and blue at or
// near zero) with the RED VALUE encoding the shading ramp. This reproduces
// exactly what tools/generate_kitsune_power_palettes.py does offline, but on
// the GPU, so the twelve power states cost two colours instead of 3168 PNGs.
//
// Hair, skin and everything else fail the chroma test below and pass through
// untouched.
//
// Known difference from the baked PNGs: the Python version additionally
// excluded a detected face bounding box. A fragment shader cannot do that
// connected-component pass, so roughly 0.13% of character pixels - dark red
// shade near the face, red 36..90 - recolour here where the baked version
// left them alone. Measured on IdleStanding_dir1: 78 px of ~59,500.

uniform bool enabled = false;

// Raw sRGB values divided by 255. Deliberately NOT source_color: the maths
// below matches the offline script, which works on raw 8-bit values. A
// source_color hint would linearise these and break the match.
uniform vec3 shadow_color = vec3(0.282353, 0.015686, 0.003922);
uniform vec3 highlight_color = vec3(0.949020, 0.227451, 0.078431);

void fragment() {
	vec4 t = texture(TEXTURE, UV);

	if (enabled && t.a > 0.0) {
		float mx = max(t.r, max(t.g, t.b));
		float mn = min(t.r, min(t.g, t.b));
		float sat = (mx - mn) / max(mx, 0.00392157); // guard matches max(mx,1) at 8-bit

		bool is_clothing =
			t.r >= mx
			&& t.r > 0.137255          // red > 35 at 8-bit
			&& sat > 0.72
			&& t.g < t.r * 0.42
			&& t.b < t.r * 0.35;

		if (is_clothing) {
			float amount = clamp((t.r * 255.0 - 45.0) / 85.0, 0.0, 1.0);
			t.rgb = mix(shadow_color, highlight_color, amount);
		}
	}

	COLOR = t;
}

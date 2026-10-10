shader_type canvas_item;

// Three things, one shader, because a CanvasItem only takes one material:
//
// 1. Clothing-only elemental recolour for Katana Kitsune (unchanged from
//    before). The sprites carry their clothing as pure-red pixels (green and
//    blue at or near zero) with the RED VALUE encoding the shading ramp. This
//    reproduces exactly what tools/generate_kitsune_power_palettes.py does
//    offline, but on the GPU, so the twelve power states cost two colours
//    instead of 3168 PNGs. Gated by `enabled`, off by default so monsters
//    that share this shader just to get effect 2 never pay for it.
//
// 2. Highlight softening, for every sprite. The 16-frame PixelOver re-export
//    shades with single-pixel light-grey/white dither rather than a blended
//    ramp, which reads as sparkly noise once blown up to 768px cells. This
//    finds pixels that are a local brightness spike against their 8
//    neighbours - regardless of hue, so it catches hair, skin and clothing
//    alike - and blends each one toward its neighbourhood average in
//    proportion to how much of an outlier it is. A large, deliberate
//    highlight (the katana blade, an eye) has neighbours just as bright, so
// its spike is ~0 and it is left alone; an isolated dither pixel sits well
// above its surroundings, so it gets a large spike and is pulled down
// toward them.
//
// 3. Hair/fur and skin recolour, same trick as clothing but on two more
//    colour bands. Every sprite in the project - player and monster alike -
//    paints its fur/hair/base-clothing as a neutral grey ramp (0, 67, 168,
//    ~227 - the same four steps everywhere, confirmed across both the player
//    and karasuShinobi), and exposed skin as a warm brown ramp distinct enough
//    in hue that it never overlaps the grey or the clothing red. Recolouring
//    each independently is what lets duplicate monsters in a wave look
//    different, and lets the player pick a hair/skin tone at the select
//    screen. Gated separately from `enabled` and from each other, so a
//    monster can get fur variety without the clothing-red logic running at
//    all.
//
//    The near-black lineart that traces the whole silhouette (body, clothing
//    edges, face) is the exact same (0,0,0) value as the darkest hair ramp
//    step, so it can't be told apart from fur by colour alone. recolour()
//    takes a `hair_context` flag - true when most of a pixel's opaque
//    neighbours are also near-grey (fur interior), false when they're mostly
//    skin/clothing/background (an outline edge) - computed once per fragment
//    from an 3x3 neighbour sample. Outline pixels keep their original black
//    instead of picking up the chosen hair tone.
//
//    Known limitation: the katana blade and any other genuinely neutral-grey
//    metal/prop pixels are themselves a solid grey blob (neighbours are also
//    grey), so they still read as "fur interior" and recolour_hair retints
//    them too. A fragment shader cannot do the connected-component
//    face/material split the offline prototypes (tools/recolor_kitsune_*_test.py)
//    used; accepted here the same way the clothing recolour already accepts
//    its own small face-pixel inaccuracy, documented below.
//
// Known difference from the baked clothing PNGs: the Python version
// additionally excluded a detected face bounding box. A fragment shader
// cannot do that connected-component pass, so roughly 0.13% of character
// pixels - dark red shade near the face, red 36..90 - recolour here where the
// baked version left them alone. Measured on IdleStanding_dir1: 78 px of
// ~59,500.

uniform bool enabled = false;

// Raw sRGB values divided by 255. Deliberately NOT source_color: the maths
// below matches the offline script, which works on raw 8-bit values. A
// source_color hint would linearise these and break the match.
uniform vec3 shadow_color = vec3(0.282353, 0.015686, 0.003922);
uniform vec3 highlight_color = vec3(0.949020, 0.227451, 0.078431);

// Hair/fur recolour. Defaults match the natural black-fur look, so turning
// this on with nothing chosen yet changes nothing.
uniform bool recolor_hair = false;
uniform vec3 hair_shadow_color = vec3(0.0, 0.0, 0.0);
uniform vec3 hair_highlight_color = vec3(0.659, 0.659, 0.659);

// Skin recolour. Defaults match the painted skin ramp exactly (108..238 raw),
// so turning this on with nothing chosen yet changes nothing either.
uniform bool recolor_skin = false;
uniform vec3 skin_shadow_color = vec3(0.423529, 0.250980, 0.188235);
uniform vec3 skin_highlight_color = vec3(0.933333, 0.666667, 0.556863);

uniform bool soften_highlights = true;
// How much of the neighbourhood average to mix in for the spikiest pixels.
uniform float soften_amount : hint_range(0.0, 1.0) = 0.85;
// Spike below this (self luma minus neighbour-average luma) is left alone -
// ordinary smooth shading, not dither.
uniform float spike_threshold : hint_range(0.0, 1.0) = 0.10;
// Spike at or above this gets the full soften_amount; between threshold and
// this it ramps up.
uniform float spike_range : hint_range(0.01, 1.0) = 0.35;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Clothing/hair/skin recolour for one already-sampled texel, so it can be
// applied identically to the centre pixel and to each neighbour before they
// are averaged together by the softening pass below.
//
// `hair_context` says whether this pixel sits inside a fur/hair blob (most of
// its opaque neighbours are also near-grey) as opposed to a near-black
// lineart edge tracing the silhouette against skin, clothing or background
// (whose neighbours are mostly NOT grey). The ramp maths can't tell a hair
// shadow pixel apart from an outline pixel in isolation - both are the same
// (0,0,0) - so this is the only way to keep outline black while still
// recolouring the fur it borders.
vec3 recolour(vec4 c, bool hair_context) {
	if (c.a <= 0.0) {
		return c.rgb;
	}
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.00392157); // guard matches max(mx,1) at 8-bit

	if (enabled) {
		bool is_clothing =
			c.r >= mx
			&& c.r > 0.137255          // red > 35 at 8-bit
			&& sat > 0.72
			&& c.g < c.r * 0.42
			&& c.b < c.r * 0.35;
		if (is_clothing) {
			float amount = clamp((c.r * 255.0 - 45.0) / 85.0, 0.0, 1.0);
			return mix(shadow_color, highlight_color, amount);
		}
	}

	if (recolor_skin && c.r > 0.0) {
		float g_ratio = c.g / c.r;
		float b_ratio = c.b / c.r;
		bool is_skin =
			c.r > 0.078431             // red > 20 at 8-bit, skips near-black noise
			&& c.r > c.g && c.g > c.b
			&& g_ratio > 0.55 && g_ratio < 0.85
			&& b_ratio > 0.40 && b_ratio < 0.75;
		if (is_skin) {
			float amount = clamp((c.r * 255.0 - 20.0) / 220.0, 0.0, 1.0);
			return mix(skin_shadow_color, skin_highlight_color, amount);
		}
	}

	if (recolor_hair && (mx - mn) <= 0.035) {
		// Near-perfect grey (absolute spread, not relative - a relative
		// saturation ratio blows up to "fully saturated" on the near-black
		// AA fringe around fur, which is still fur). The shared
		// fur/hair/base-clothing ramp.
		if (hair_context) {
			float amount = clamp(luma(c.rgb), 0.0, 1.0);
			return mix(hair_shadow_color, hair_highlight_color, amount);
		}
		// Outline pixel (lineart against skin/clothing/background, not fur
		// interior) - leave it exactly as painted so it stays black instead
		// of picking up the chosen hair tone.
		return c.rgb;
	}

	return c.rgb;
}

// How much of a pixel's near-grey-ness it takes for its neighbourhood to
// count as "fur interior" rather than "outline". Majority vote among opaque
// neighbours.
const float HAIR_CONTEXT_RATIO = 0.5;

void fragment() {
	vec4 t = texture(TEXTURE, UV);

	// Single 3x3 neighbour pass feeding both the hair/outline split above and
	// the highlight-softening blend below, so each neighbour texel is only
	// sampled once per fragment.
	float grey_neighbours = 0.0;
	float opaque_neighbours = 0.0;
	vec4 neighbour_texels[8];
	bool neighbour_opaque[8];
	int n_idx = 0;

	bool need_neighbours = (recolor_hair || soften_highlights) && t.a > 0.0;
	if (need_neighbours) {
		for (int dx = -1; dx <= 1; dx++) {
			for (int dy = -1; dy <= 1; dy++) {
				if (dx == 0 && dy == 0) {
					continue;
				}
				vec2 offset = vec2(float(dx), float(dy)) * TEXTURE_PIXEL_SIZE;
				vec4 n = texture(TEXTURE, UV + offset);
				neighbour_texels[n_idx] = n;
				bool n_opaque = n.a > 0.0;
				neighbour_opaque[n_idx] = n_opaque;
				n_idx += 1;
				if (n_opaque) {
					opaque_neighbours += 1.0;
					float nmx = max(n.r, max(n.g, n.b));
					float nmn = min(n.r, min(n.g, n.b));
					if ((nmx - nmn) <= 0.035) {
						grey_neighbours += 1.0;
					}
				}
			}
		}
	}

	// Fewer than 3 opaque neighbours means this pixel is itself a thin
	// isolated speck (e.g. a corner); default to "is fur" so it still gets
	// recoloured rather than popping out as a stray black dot.
	bool hair_context = opaque_neighbours < 3.0
		|| (grey_neighbours / max(opaque_neighbours, 1.0)) >= HAIR_CONTEXT_RATIO;

	vec3 color = recolour(t, hair_context);

	if (soften_highlights && t.a > 0.0) {
		vec3 acc = vec3(0.0);
		float lum_acc = 0.0;
		float count = 0.0;

		for (int i = 0; i < 8; i++) {
			if (neighbour_opaque[i]) {
				// Softening doesn't recompute each neighbour's own context -
				// assume fur interior, same small accepted imprecision as
				// the clothing/face exception documented above.
				vec3 nc = recolour(neighbour_texels[i], true);
				acc += nc;
				lum_acc += luma(nc);
				count += 1.0;
			}
		}

		if (count >= 3.0) {
			vec3 avg = acc / count;
			float avg_lum = lum_acc / count;
			float spike = max(0.0, luma(color) - avg_lum);
			float blend = clamp((spike - spike_threshold) / max(spike_range - spike_threshold, 0.001), 0.0, 1.0) * soften_amount;
			color = mix(color, avg, blend);
		}
	}

	COLOR = vec4(color, t.a);
}

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
// 4. Monster clothing hue rotation (recolor_clothing_hue). Monsters do not
//    use the pure-red clothing key, so each species supplies its own clothing
//    hue bands; enemies use this alone and leave hair and skin as painted.
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

// Clothing colour key. A texel is clothing when red is its largest channel,
// red > clothing_min_red, saturation > clothing_min_sat and green/blue are
// below the given fractions of red. Its position on the shadow->highlight
// ramp is (red8 - clothing_amount_offset) / clothing_amount_range.
// Defaults are Katana Kitsune's pure-red key (red > 35). Kitsune.tscn sets a
// wider key (red > 30, sat > 0.5, g/b < 0.5r, (red8 - 40) / 70) so her
// dark-red hair and skirt - the same paint - take the theme together while
// her pale skin and white top stay out of it.
uniform float clothing_min_red : hint_range(0.0, 1.0) = 0.137255;
uniform float clothing_min_sat : hint_range(0.0, 1.0) = 0.72;
uniform float clothing_max_green_ratio : hint_range(0.0, 1.0) = 0.42;
uniform float clothing_max_blue_ratio : hint_range(0.0, 1.0) = 0.35;
uniform float clothing_amount_offset : hint_range(0.0, 255.0) = 45.0;
uniform float clothing_amount_range : hint_range(1.0, 255.0) = 85.0;

// Stray fill. PixelOver leaves the odd dull brown pixel inside Kitsune's hair
// and skirt - the same paint, desaturated by downscaling - that misses the
// key and stays brown while everything around it takes the theme. A warm
// pixel (red the strongest channel) that fails the key but has at least
// stray_neighbour_ratio of its opaque neighbours keyed is treated as
// clothing too, ramped by its own red like any other. Outline stays: it is
// black, below stray_min_red. Skin stays: its saturation is under
// stray_min_sat (Kitsune's skin sits around 0.18-0.20).
uniform bool fill_strays = false;
uniform float stray_min_red : hint_range(0.0, 1.0) = 0.1;
uniform float stray_min_sat : hint_range(0.0, 1.0) = 0.25;
uniform float stray_neighbour_ratio : hint_range(0.0, 1.0) = 0.5;

// Master switch for the two legacy passes below. PowerState.apply_to always
// turns recolor_hair/recolor_skin on; a character whose paint does not fit
// those keys (Kitsune: red hair, pale skin, white top that the grey hair key
// would dim) sets this false in its material and the passes are skipped.
uniform bool hair_skin_passes = true;

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

// Monster clothing recolour. Monster sheets are not colour-keyed like the
// player's pure-red clothing, so each species names up to two hue bands its
// clothing is painted in (PowerState.ENEMY_CLOTHING). Pixels inside a band
// are hue-rotated by clothing_hue_shift with their saturation and value kept,
// so the shading survives. Each band is (centre°, half-width°, min saturation,
// min value); the floors keep dark hair and pale skin that carry a faint
// tint of the same hue out of it. Half-width 0 disables a band.
uniform bool recolor_clothing_hue = false;
uniform float clothing_hue_shift = 0.0;
uniform vec4 clothing_band_a = vec4(0.0);
uniform vec4 clothing_band_b = vec4(0.0);

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

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// 0..1 membership of `hsv` in a clothing band, softened over the outer third
// of the hue width so a band edge never leaves a hard seam across the cloth.
float band_weight(vec3 hsv, vec4 band) {
	if (band.y <= 0.0 || hsv.y < band.z || hsv.z < band.w) {
		return 0.0;
	}
	float delta = abs(mod(hsv.x * 360.0 - band.x + 540.0, 360.0) - 180.0);
	return 1.0 - smoothstep(band.y * 0.66, band.y, delta);
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
// The clothing key on its own, so the stray pass can count keyed neighbours
// without recolouring them.
bool clothing_key(vec4 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.00392157);
	return c.a > 0.0
		&& c.r >= mx
		&& c.r > clothing_min_red
		&& sat > clothing_min_sat
		&& c.g < c.r * clothing_max_green_ratio
		&& c.b < c.r * clothing_max_blue_ratio;
}

// `stray_context`: enough of this pixel's neighbours are keyed clothing that
// a warm off-key pixel here is a stray to be filled (see fill_strays).
vec3 recolour(vec4 c, bool hair_context, bool stray_context) {
	if (c.a <= 0.0) {
		return c.rgb;
	}
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.00392157); // guard matches max(mx,1) at 8-bit

	if (recolor_clothing_hue) {
		vec3 hsv = rgb_to_hsv(c.rgb);
		float weight = max(band_weight(hsv, clothing_band_a), band_weight(hsv, clothing_band_b));
		if (weight > 0.0) {
			vec3 shifted = hsv_to_rgb(vec3(fract(hsv.x + clothing_hue_shift / 360.0), hsv.y, hsv.z));
			return mix(c.rgb, shifted, weight);
		}
	}

	if (enabled) {
		bool is_clothing = clothing_key(c);
		if (!is_clothing && fill_strays && stray_context) {
			is_clothing = c.r >= mx && c.r > stray_min_red && sat > stray_min_sat;
		}
		if (is_clothing) {
			float amount = clamp((c.r * 255.0 - clothing_amount_offset) / clothing_amount_range, 0.0, 1.0);
			return mix(shadow_color, highlight_color, amount);
		}
	}

	if (!hair_skin_passes) {
		return c.rgb;
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
	float keyed_neighbours = 0.0;
	float opaque_neighbours = 0.0;
	vec4 neighbour_texels[8];
	bool neighbour_opaque[8];
	int n_idx = 0;

	bool need_neighbours = ((recolor_hair && hair_skin_passes) || soften_highlights
		|| (enabled && fill_strays)) && t.a > 0.0;
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
					if (clothing_key(n)) {
						keyed_neighbours += 1.0;
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

	// A stray needs real neighbours to be judged against; a lone speck with
	// fewer than 3 is left to the ordinary key.
	bool stray_context = opaque_neighbours >= 3.0
		&& (keyed_neighbours / max(opaque_neighbours, 1.0)) >= stray_neighbour_ratio;

	vec3 color = recolour(t, hair_context, stray_context);

	if (soften_highlights && t.a > 0.0) {
		vec3 acc = vec3(0.0);
		float lum_acc = 0.0;
		float count = 0.0;

		for (int i = 0; i < 8; i++) {
			if (neighbour_opaque[i]) {
				// Softening doesn't recompute each neighbour's own context -
				// assume fur interior, same small accepted imprecision as
				// the clothing/face exception documented above.
				vec3 nc = recolour(neighbour_texels[i], true, false);
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

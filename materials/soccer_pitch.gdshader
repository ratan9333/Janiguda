shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Grass pitch drawn procedurally across the plane's 0..1 UVs: mown stripes plus
// regulation markings. The plane is larger than the pitch itself, so the
// markings are laid out at true 105 x 68 m and centred, leaving a grass
// surround the way a real ground has one.

uniform vec2 plane_size_m = vec2(76.4, 111.23);   // the model's real size
uniform vec2 pitch_size_m = vec2(68.0, 105.0);    // regulation playing area
uniform float line_width_m : hint_range(0.05, 0.5) = 0.12;
uniform float stripe_width_m : hint_range(1.0, 15.0) = 5.5;
uniform float show_markings : hint_range(0.0, 1.0) = 1.0;

uniform vec3 grass_light : source_color = vec3(0.290, 0.498, 0.220);
uniform vec3 grass_dark : source_color = vec3(0.216, 0.404, 0.169);
uniform vec3 line_color : source_color = vec3(0.930, 0.950, 0.930);
uniform float grass_roughness : hint_range(0.0, 1.0) = 0.92;

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// A stroke of half-width w centred on the zero-crossing of d.
float stroke(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

float dot_mark(vec2 p, vec2 c, float r, float aa) {
	return 1.0 - smoothstep(r, r + aa, length(p - c));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Metres from the centre of the plane.
	vec2 p = (UV - 0.5) * plane_size_m;
	vec2 h = pitch_size_m * 0.5;              // (34, 52.5)
	float w = line_width_m * 0.5;
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.75 + 0.004;

	// Mown stripes running across the pitch.
	float band = floor((p.y + h.y) / stripe_width_m);
	vec3 col = mix(grass_dark, grass_light, mod(band, 2.0));

	// Break up the flat colour so it reads as turf rather than paint.
	col *= 0.94 + 0.12 * hash(floor(p * 6.0));
	col *= 0.97 + 0.06 * hash(floor(p * 23.0) + 7.0);

	float m = 0.0;

	// Touchlines and goal lines.
	m = max(m, stroke(sd_box(p, h), w, aa));
	// Halfway line, centre circle, centre spot.
	m = max(m, stroke(sd_seg(p, vec2(-h.x, 0.0), vec2(h.x, 0.0)), w, aa));
	m = max(m, stroke(length(p) - 9.15, w, aa));
	m = max(m, dot_mark(p, vec2(0.0), 0.18, aa));

	// Both ends.
	for (int i = 0; i < 2; i++) {
		float s = (i == 0) ? -1.0 : 1.0;

		// Penalty area 40.32 x 16.5, goal area 18.32 x 5.5.
		m = max(m, stroke(sd_box(p - vec2(0.0, s * (h.y - 8.25)), vec2(20.16, 8.25)), w, aa));
		m = max(m, stroke(sd_box(p - vec2(0.0, s * (h.y - 2.75)), vec2(9.16, 2.75)), w, aa));

		// Penalty spot 11 m out, and the arc - only the part clear of the box.
		vec2 spot = vec2(0.0, s * (h.y - 11.0));
		m = max(m, dot_mark(p, spot, 0.18, aa));
		m = max(m, stroke(length(p - spot) - 9.15, w, aa) * step(abs(p.y), h.y - 16.5));

		// Corner arcs; the clip below trims them to quarter circles.
		for (int j = 0; j < 2; j++) {
			float t = (j == 0) ? -1.0 : 1.0;
			m = max(m, stroke(length(p - vec2(t * h.x, s * h.y)) - 1.0, w, aa));
		}
	}

	// Nothing painted outside the playing area.
	m *= step(sd_box(p, h + vec2(w + aa)), 0.0) * show_markings;

	ALBEDO = mix(col, line_color, m);
	ROUGHNESS = mix(grass_roughness, 0.75, m);
	SPECULAR = 0.12;
}

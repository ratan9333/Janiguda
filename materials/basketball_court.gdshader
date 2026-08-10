shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Outdoor basketball court painted across the plane's 0..1 UVs.
//
// The court is fitted to whatever the plane measures, keeping the regulation
// 15 x 28 m proportions, so it stays square no matter how the node is scaled.
// All markings are then laid out in true court metres.

uniform vec2 plane_size_m = vec2(14.32, 29.95);   // the model's real size
uniform float court_fill : hint_range(0.5, 1.0) = 0.92;
uniform float line_width_m : hint_range(0.03, 0.4) = 0.05;
uniform float show_markings : hint_range(0.0, 1.0) = 1.0;

uniform vec3 court_color : source_color = vec3(0.259, 0.427, 0.337);
uniform vec3 key_color : source_color = vec3(0.604, 0.302, 0.235);
uniform vec3 surround_color : source_color = vec3(0.204, 0.235, 0.220);
uniform vec3 line_color : source_color = vec3(0.941, 0.949, 0.937);
uniform float court_roughness : hint_range(0.0, 1.0) = 0.78;

const vec2 COURT = vec2(15.0, 28.0);   // width, length

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

float stroke(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size_m;

	// Fit the court to the plane without distorting it.
	float fit = min(plane_size_m.x / COURT.x, plane_size_m.y / COURT.y) * court_fill;
	vec2 q = p / fit;                       // true court metres
	vec2 h = COURT * 0.5;                   // (7.5, 14.0)
	float w = (line_width_m / fit) * 0.5;
	float aa = max(fwidth(q.x), fwidth(q.y)) * 0.75 + 0.002;

	float inside = 1.0 - step(0.0, sd_box(q, h));

	// Painted key at each end: 4.9 wide x 5.8 deep from the baseline.
	float key = 0.0;
	for (int i = 0; i < 2; i++) {
		float s = (i == 0) ? -1.0 : 1.0;
		key = max(key, 1.0 - step(0.0, sd_box(q - vec2(0.0, s * (h.y - 2.9)), vec2(2.45, 2.9))));
	}

	vec3 col = mix(surround_color, court_color, inside);
	col = mix(col, key_color, key * inside);
	col *= 0.96 + 0.08 * hash(floor(q * 9.0));

	float m = 0.0;

	// Sidelines, baselines, halfway line, centre circle.
	m = max(m, stroke(sd_box(q, h), w, aa));
	m = max(m, stroke(sd_seg(q, vec2(-h.x, 0.0), vec2(h.x, 0.0)), w, aa));
	m = max(m, stroke(length(q) - 1.8, w, aa));

	for (int i = 0; i < 2; i++) {
		float s = (i == 0) ? -1.0 : 1.0;
		float base = s * h.y;
		vec2 basket = vec2(0.0, s * (h.y - 1.575));

		// Key outline and the free-throw circle at 5.8 m.
		m = max(m, stroke(sd_box(q - vec2(0.0, s * (h.y - 2.9)), vec2(2.45, 2.9)), w, aa));
		m = max(m, stroke(length(q - vec2(0.0, s * (h.y - 5.8))) - 1.8, w, aa));

		// Three-point line: straight runs 0.9 m in from each sideline, meeting a
		// 6.75 m arc struck from the basket. They join at 1.415 m along.
		float join = s * (h.y - 2.99);
		for (int j = 0; j < 2; j++) {
			float t = (j == 0) ? -1.0 : 1.0;
			m = max(m, stroke(sd_seg(q, vec2(t * 6.6, base), vec2(t * 6.6, join)), w, aa));
		}
		m = max(m, stroke(length(q - basket) - 6.75, w, aa) * step(abs(q.y), h.y - 2.99));

		// Restricted-area arc under the basket.
		m = max(m, stroke(length(q - basket) - 1.25, w, aa) * step(abs(q.y), h.y - 1.575));

		// Backboard mark on the baseline side.
		m = max(m, stroke(sd_seg(q, vec2(-0.9, s * (h.y - 1.2)), vec2(0.9, s * (h.y - 1.2))), w, aa));
	}

	m *= step(sd_box(q, h + vec2(w + aa)), 0.0) * show_markings;

	ALBEDO = mix(col, line_color, m);
	ROUGHNESS = mix(court_roughness, 0.65, m);
	SPECULAR = 0.2;
}

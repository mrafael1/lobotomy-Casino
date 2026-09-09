shader_type canvas_item;
uniform sampler2D enamel_reference : source_color, filter_nearest, repeat_disable;

void fragment() {
	vec2 p = floor(UV * vec2(160.0, 320.0));
	vec4 source = COLOR;
	bool outside = p.x < 39.0 || p.x >= 111.0 || p.y < 250.0 || p.y >= 278.0;
	bool corner = (p.x < 41.0 || p.x >= 109.0) && (p.y < 252.0 || p.y >= 276.0);
	if (outside || corner) {
		COLOR = vec4(0.0);
	} else {
		// Borrow the painted steel's grain, while retaining exact drum geometry.
		vec2 steel_uv = vec2(mix(25.0, 136.0, (p.x - 39.0) / 72.0), 105.5 + mod(p.y, 2.0)) / vec2(160.0, 320.0);
		vec3 steel = texture(enamel_reference, steel_uv).rgb;
		steel = mix(vec3(0.32, 0.34, 0.38), steel, 0.25);
		float bevel = min(min(p.x - 39.0, 110.0 - p.x), min(p.y - 250.0, 277.0 - p.y));
		if (bevel < 1.0) steel = vec3(0.08, 0.10, 0.12);
		else if (p.y < 253.0 || p.x < 42.0) steel = min(steel + vec3(0.18), vec3(0.85));
		else if (p.y > 274.0 || p.x > 107.0) steel *= 0.42;
		bool drum = p.x >= 44.0 && p.x < 92.0 && p.y >= 253.0 && p.y < 273.0;
		if (drum && source.a < 0.01) {
			COLOR = vec4(0.0);
		} else {
			if (p.x >= 94.0 && p.x < 105.0 && p.y >= 256.0 && p.y < 272.0) {
				float light = max(source.r, max(source.g, source.b));
				steel = mix(vec3(0.18, 0.17, 0.15), vec3(0.75, 0.66, 0.46), light);
			}
			COLOR = vec4(steel, 1.0);
		}
	}
}

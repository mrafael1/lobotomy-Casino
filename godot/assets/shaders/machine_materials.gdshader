shader_type canvas_item;
uniform bool phosphor_text = false;

// Match legacy mechanical sheets to the cabinet without changing their frames,
// transparency, or the colours of gameplay symbols and warning overlays.
void fragment() {
	vec4 source = COLOR;
	float light = max(source.r, max(source.g, source.b));
	if (phosphor_text) {
		source.rgb = vec3(0.93, 0.88, 0.72);
	} else if (source.r > source.g * 1.35 && source.b > source.g * 1.35) {
		source.rgb = mix(vec3(0.13, 0.065, 0.10), vec3(0.70, 0.24, 0.31), light);
	} else if (source.g > source.b * 1.3 && source.r > source.b * 1.3) {
		source.rgb = mix(vec3(0.15, 0.17, 0.20), vec3(0.82, 0.76, 0.60), light);
	} else if (source.g > source.r * 1.3 && source.b > source.r * 1.3) {
		source.rgb = mix(vec3(0.12, 0.19, 0.23), vec3(0.51, 0.78, 0.69), light);
	}
	COLOR = source;
}

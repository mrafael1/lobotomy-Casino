shader_type canvas_item;

// Shaded paper drums, fitted to the settled strip and its per-reel covers.
// This changes the supporting surface only; symbols remain independent sprites.
void fragment() {
	vec2 p = floor(UV * vec2(160.0, 320.0));
	bool reel = (p.x >= 33.0 && p.x < 54.0) || (p.x >= 65.0 && p.x < 86.0)
		|| (p.x >= 97.0 && p.x < 118.0);
	if (!reel || p.y < 169.0 || p.y >= 203.0) {
		COLOR = vec4(0.0);
	} else {
		float distance = abs(p.y - 185.0);
		float band = floor(clamp(1.0 - distance / 18.0, 0.0, 1.0) * 5.0) / 5.0;
		vec3 paper = mix(vec3(0.14, 0.19, 0.19), vec3(0.83, 0.81, 0.68), band);
		COLOR = vec4(paper, 1.0);
	}
}

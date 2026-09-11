shader_type canvas_item;

uniform sampler2D aperture_mask : filter_nearest, repeat_disable;
uniform sampler2D control_surface : source_color, filter_nearest, repeat_disable;
uniform sampler2D preview_shelf : source_color, filter_nearest, repeat_disable;

// Registration in virtual pixels. The painting has no gameplay baked into it;
// each horizontal assembly is fitted to the existing machine's live controls.
float fit(float v, float a, float b, float c, float d) {
	return mix(c, d, (v - a) / (b - a));
}

void fragment() {
	vec2 p = floor(UV * vec2(160.0, 320.0)) + vec2(0.5);
	vec2 q = p;
	if (p.y < 39.0) q.y = fit(p.y, 0.0, 39.0, 0.0, 26.0);
	else if (p.y < 46.0) q.y = fit(p.y, 39.0, 46.0, 26.0, 40.0);
	else if (p.y < 114.0) q.y = fit(p.y, 46.0, 114.0, 40.0, 103.0);
	else if (p.y < 139.0) q.y = fit(p.y, 114.0, 139.0, 103.0, 127.0);
	else if (p.y < 153.0) q.y = fit(p.y, 139.0, 153.0, 127.0, 139.0);
	else if (p.y < 169.0) q.y = fit(p.y, 153.0, 169.0, 139.0, 149.0);
	else if (p.y < 203.0) q.y = fit(p.y, 169.0, 203.0, 149.0, 195.0);
	else if (p.y < 241.0) q.y = fit(p.y, 203.0, 241.0, 195.0, 222.0);
	else if (p.y < 288.0) q.y = fit(p.y, 241.0, 288.0, 238.0, 261.0);
	else if (p.y < 299.0) q.y = fit(p.y, 288.0, 299.0, 288.0, 300.0);
	else q.y = fit(p.y, 299.0, 320.0, 262.0, 287.0);
	q.x = fit(p.x, 20.0, 132.0, 22.0, 138.0);
	if (p.y >= 153.0 && p.y < 207.0) {
		if (p.x < 33.0) q.x = fit(p.x, 20.0, 33.0, 22.0, 35.0);
		else if (p.x < 54.0) q.x = fit(p.x, 33.0, 54.0, 35.0, 61.0);
		else if (p.x < 65.0) q.x = fit(p.x, 54.0, 65.0, 61.0, 67.0);
		else if (p.x < 86.0) q.x = fit(p.x, 65.0, 86.0, 67.0, 93.0);
		else if (p.x < 97.0) q.x = fit(p.x, 86.0, 97.0, 93.0, 100.0);
		else if (p.x < 118.0) q.x = fit(p.x, 97.0, 118.0, 100.0, 126.0);
		else q.x = fit(p.x, 118.0, 140.0, 126.0, 147.0);
	}
	vec4 paint = texture(TEXTURE, q / vec2(160.0, 320.0));
	vec4 controls = texture(control_surface, p / vec2(160.0, 320.0));
	if (p.y >= 207.0) controls = texture(preview_shelf, p / vec2(160.0, 320.0));
	paint.rgb = mix(paint.rgb, controls.rgb, controls.a);
	paint.a *= texture(aperture_mask, p / vec2(160.0, 320.0)).a;
	COLOR = paint;
}

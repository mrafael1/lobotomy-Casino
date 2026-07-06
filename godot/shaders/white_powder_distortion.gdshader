shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float ripple_time = 0.0;
uniform vec2 center = vec2(0.5, 0.58);
uniform float radius : hint_range(0.05, 1.0) = 0.38;

void fragment() {
	vec2 delta = SCREEN_UV - center;
	float dist = length(delta);
	float mask = 1.0 - smoothstep(0.0, radius, dist);
	float wave = sin((dist * 54.0) - ripple_time * 18.0);
	vec2 dir = dist > 0.0001 ? delta / dist : vec2(0.0, 1.0);
	vec2 offset = dir * wave * amount * mask * 0.012;
	COLOR = texture(screen_texture, SCREEN_UV + offset);
	COLOR.a = mask * amount;
}

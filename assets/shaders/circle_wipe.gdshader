shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = SCREEN_UV;
	uv.x = (uv.x - 0.5) * aspect + 0.5;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);
	// max_radius = distance from center to corner (corrected coords)
	float corner_x = 0.5 * aspect + 0.5;
	float max_radius = distance(vec2(corner_x, 1.0), center);
	float radius = max_radius * (1.0 - progress);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(radius - 0.005, radius, dist));
}

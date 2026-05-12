shader_type canvas_item;

uniform float bg_hue : hint_range(0.0, 360.0) = 210.0;
uniform float scroll_x : hint_range(0.0, 1.0) = 0.0;
uniform float grid_size : hint_range(10.0, 120.0) = 48.0;
uniform float grid_alpha : hint_range(0.0, 1.0) = 1.0;

vec3 hsl2rgb(float h, float s, float l) {
	float c = (1.0 - abs(2.0 * l - 1.0)) * s;
	float x = c * (1.0 - abs(mod(h / 60.0, 2.0) - 1.0));
	float m = l - c * 0.5;
	vec3 rgb;
	if      (h < 60.0)  rgb = vec3(c, x, 0.0);
	else if (h < 120.0) rgb = vec3(x, c, 0.0);
	else if (h < 180.0) rgb = vec3(0.0, c, x);
	else if (h < 240.0) rgb = vec3(0.0, x, c);
	else if (h < 300.0) rgb = vec3(x, 0.0, c);
	else                rgb = vec3(c, 0.0, x);
	return rgb + m;
}

void fragment() {
	vec2 uv = UV;
	uv.x = mod(uv.x + scroll_x, 1.0);

	vec2 grid_uv = uv * vec2(900.0, 500.0) / grid_size;
	vec2 cell    = fract(grid_uv);
	float line_w = 0.045;
	float on_line = step(1.0 - line_w, cell.x) + step(1.0 - line_w, cell.y);
	on_line = clamp(on_line, 0.0, 1.0);

	// Pulse the grid lines with time
	float pulse = 0.60 + 0.40 * sin(TIME * 1.4);
	vec3 line_col = hsl2rgb(mod(bg_hue, 360.0), 1.0, 0.55 * pulse);

	// Base is TRANSPARENT — bg images and sky_rect show through
	// Only the grid lines are drawn
	COLOR = vec4(line_col * 1.8, on_line * grid_alpha * 0.75);
}

shader_type canvas_item;

uniform sampler2D bg_tex : source_color, repeat_enable, filter_linear;
uniform float scroll_x = 0.0;

void fragment() {
	// Show image 2x wide for smooth looping parallax; stretch vertically to fill
	vec2 uv = vec2(fract(UV.x * 2.0 + scroll_x * 2.0), UV.y);
	vec4 c = texture(bg_tex, uv);
	COLOR = c;
}

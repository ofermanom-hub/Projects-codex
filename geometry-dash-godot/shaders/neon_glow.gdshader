shader_type canvas_item;

uniform float glow_size  : hint_range(1.0, 8.0) = 3.0;
uniform vec4  glow_color : source_color = vec4(3.0, 2.2, 0.5, 1.0);
uniform float pulse_speed = 2.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// 8-tap outline sample
	vec2 ps = TEXTURE_PIXEL_SIZE * glow_size;
	float outer = 0.0;
	outer += texture(TEXTURE, UV + vec2( ps.x,  0.0 )).a;
	outer += texture(TEXTURE, UV + vec2(-ps.x,  0.0 )).a;
	outer += texture(TEXTURE, UV + vec2( 0.0,   ps.y)).a;
	outer += texture(TEXTURE, UV + vec2( 0.0,  -ps.y)).a;
	outer += texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a * 0.707;
	outer += texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a * 0.707;
	outer += texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a * 0.707;
	outer += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a * 0.707;
	outer = clamp(outer / 5.828, 0.0, 1.0) * (1.0 - col.a);

	// Pulsing glow intensity
	float pulse = 1.0 + 0.3 * sin(TIME * pulse_speed);
	vec4 glow   = glow_color * outer * pulse;

	COLOR = col + glow;
}

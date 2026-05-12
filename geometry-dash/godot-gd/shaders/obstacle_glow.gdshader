shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float glow_strength : hint_range(0.0, 8.0) = 3.5;
uniform float glow_speed   : hint_range(0.0, 8.0) = 2.5;
uniform float glow_phase   : hint_range(0.0, 6.283) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Core pulse
	float pulse = 0.60 + 0.40 * sin(TIME * glow_speed + glow_phase);

	// Edge flare: brighter at texture silhouette edges
	vec2 edge_uv = abs(UV * 2.0 - 1.0);
	float edge   = pow(max(edge_uv.x, edge_uv.y), 3.0);

	vec3 glow = glow_color.rgb * tex.a * glow_strength * pulse;
	glow += glow_color.rgb * tex.a * edge * glow_strength * 1.2;

	// Secondary color complement flicker
	vec3 comp = vec3(glow_color.b, glow_color.r, glow_color.g);
	float flicker = 0.5 + 0.5 * sin(TIME * glow_speed * 1.7 + glow_phase + 1.57);
	glow += comp * tex.a * glow_strength * 0.35 * flicker;

	COLOR = vec4(tex.rgb + glow, tex.a);
}

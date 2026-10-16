shader_type spatial;
// Baldosas de plástico con junta, en coordenadas de mundo: dan escala a las superficies grandes y lisas.
// El color de cada superficie llega en los vértices (Kit.bake funde todas en pocas mallas).

varying vec3 world_pos;
varying vec3 base;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	base = mix(pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));  // sRGB → lineal
}

void fragment() {
	vec2 cell = world_pos.xz / 1.6;
	vec2 f = abs(fract(cell) - 0.5) * 2.0;
	float joint = smoothstep(0.88, 0.97, max(f.x, f.y));
	float tint = 0.97 + 0.03 * fract(sin(dot(floor(cell), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = base * tint * (1.0 - 0.2 * joint);
	ROUGHNESS = mix(0.2, 0.7, joint);
}

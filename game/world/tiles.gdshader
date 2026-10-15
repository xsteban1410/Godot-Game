shader_type spatial;
// Baldosas de plástico con junta, en coordenadas de mundo: dan escala a las superficies grandes y lisas.

instance uniform vec3 base : source_color = vec3(0.93, 0.95, 0.98);
uniform float size = 1.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = world_pos.xz / size;
	vec2 f = abs(fract(cell) - 0.5) * 2.0;
	float joint = smoothstep(0.88, 0.97, max(f.x, f.y));
	float tint = 0.97 + 0.03 * fract(sin(dot(floor(cell), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = base * tint * (1.0 - 0.2 * joint);
	ROUGHNESS = mix(0.25, 0.7, joint);
	CLEARCOAT = 0.5;
	CLEARCOAT_ROUGHNESS = 0.15;
}

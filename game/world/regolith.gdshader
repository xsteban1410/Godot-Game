shader_type spatial;
// Suelo lunar: regolito gris con manchas y cráteres pequeños dibujados (cada celda de 9 m puede tener uno).

varying vec2 ground;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 cell = floor(ground / 9.0);
	vec2 center = (cell + 0.25 + 0.5 * vec2(hash(cell), hash(cell + 7.0))) * 9.0;
	float r = 1.0 + 2.5 * hash(cell + 3.0);
	float d = length(ground - center) / r;
	float has = step(0.45, hash(cell + 11.0));
	float bowl = has * (1.0 - smoothstep(0.7, 1.0, d)) * 0.35;  // fondo más oscuro
	float rim = has * smoothstep(0.85, 1.0, d) * (1.0 - smoothstep(1.0, 1.25, d)) * 0.3;  // borde iluminado
	float grain = hash(floor(ground * 3.0)) * 0.025;
	ALBEDO = vec3(0.4, 0.41, 0.44) * (1.0 - bowl + rim) + grain;
	ROUGHNESS = 0.95;
}

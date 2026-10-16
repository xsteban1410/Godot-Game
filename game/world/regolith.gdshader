shader_type spatial;
// Suelo lunar: regolito gris con manchas suaves (los "mares") y cráteres con relieve: la pared del cuenco
// y el borde levantado inclinan la normal, así la luz rasante del Sol los dibuja. Cada celda de 9 m
// puede tener uno, siempre dentro de su celda (si no, se cortaban en el borde).

varying vec2 ground;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 cell = floor(ground / 9.0);
	vec2 center = (cell + 0.35 + 0.3 * vec2(hash(cell), hash(cell + 7.0))) * 9.0;
	float r = 1.0 + 1.6 * hash(cell + 3.0);
	vec2 off = (ground - center) / r;
	float d = length(off);
	float has = step(0.45, hash(cell + 11.0));
	// Pendiente del perfil: sube hacia el borde dentro del cuenco y baja por fuera.
	float slope = smoothstep(0.1, 0.8, d) * (1.0 - smoothstep(0.85, 1.0, d)) - 0.6 * smoothstep(1.0, 1.1, d) * (1.0 - smoothstep(1.1, 1.5, d));
	vec2 tilt = off / max(d, 0.001) * slope * has * 0.7;
	NORMAL = normalize((VIEW_MATRIX * vec4(-tilt.x, 1.0, -tilt.y, 0.0)).xyz);
	float maria = noise(ground * 0.03);
	float grain = noise(ground * 3.0) * 0.6 + noise(ground * 9.0) * 0.4;
	float bowl = has * (1.0 - smoothstep(0.4, 0.95, d)) * 0.2;
	ALBEDO = vec3(0.43, 0.44, 0.47) * (0.78 + 0.3 * maria) * (0.93 + 0.14 * grain) * (1.0 - bowl);
	ROUGHNESS = 0.95;
}

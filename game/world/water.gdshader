shader_type spatial;
// Agua de juguete: azul que se aclara en los bordes (fresnel), ondas que corren con la corriente
// (eje X de la malla) y crestas de espuma. La normal sigue a las ondas: el Sol deja destellos.

uniform vec3 deep : source_color = vec3(0.0, 0.36, 0.92);
uniform vec3 shallow : source_color = vec3(0.3, 0.85, 1.0);

varying vec2 flat_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float waves(vec2 p) {
	return noise(p + vec2(TIME * 0.7, 0.0)) * 0.65 + noise(p * 2.1 + vec2(TIME * 1.1, TIME * 0.3)) * 0.35;
}

void vertex() {
	flat_pos = VERTEX.xz * vec2(0.6, 1.1);
}

void fragment() {
	float h = waves(flat_pos);
	float dx = waves(flat_pos + vec2(0.08, 0.0)) - h;
	float dz = waves(flat_pos + vec2(0.0, 0.08)) - h;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(-dx * 4.0, 0.0, -dz * 4.0, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float crest = smoothstep(0.66, 0.72, h) * (1.0 - smoothstep(0.72, 0.8, h));
	ALBEDO = mix(deep, shallow, clamp(h * 0.7 + fresnel * 0.5, 0.0, 1.0)) + vec3(crest * 0.7);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}

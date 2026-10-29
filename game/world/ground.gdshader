shader_type spatial;
// Césped: dos verdes apagados (DESING: mundo en tonos neutros) mezclados con ruido suave y baldosas de 4 m apenas marcadas.

uniform vec3 dark : source_color = vec3(0.4, 0.48, 0.38);
uniform vec3 light : source_color = vec3(0.56, 0.64, 0.52);

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
	vec2 tile = floor(ground / 4.0);
	ALBEDO = mix(dark, light, noise(ground * 0.07) * 0.6 + noise(ground * 0.6) * 0.4)
		* (0.95 + 0.05 * mod(tile.x + tile.y, 2.0));
	ROUGHNESS = 0.55;
}

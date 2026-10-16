shader_type spatial;
// La Tierra vista desde la Luna: océanos, continentes, casquetes polares y nubes con ruido 3D sobre la
// esfera (gira con su nodo), y el halo azul de la atmósfera en el borde.

varying vec3 dir;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.5 + noise(p * 2.03) * 0.3 + noise(p * 4.1) * 0.2;
}

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(dir);
	float land = smoothstep(0.53, 0.56, fbm(d * 2.4));
	vec3 terrain = mix(vec3(0.16, 0.55, 0.2), vec3(0.78, 0.64, 0.38), smoothstep(0.45, 0.65, noise(d * 7.0)));
	vec3 color = mix(vec3(0.02, 0.2, 0.72), terrain, land);
	color = mix(color, vec3(0.95), smoothstep(0.8, 0.86, abs(d.y)));
	float clouds = smoothstep(0.55, 0.72, fbm(d * 4.5 + vec3(TIME * 0.01, 0.0, 0.0)));
	color = mix(color, vec3(1.0), clouds * 0.9);
	ALBEDO = color;
	ROUGHNESS = mix(0.25, 0.9, max(land, clouds));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = vec3(0.35, 0.65, 1.0) * rim * 1.6 + color * 0.12;
}

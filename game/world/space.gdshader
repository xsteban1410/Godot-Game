shader_type sky;
// Cielo estrellado. En la Luna (valores por defecto): negro, sin atmósfera; las estrellas no titilan (no hay
// aire que desvíe su luz), franja tenue de la Vía Láctea y el disco del Sol. En la Tierra de noche: degradado
// azul hacia el horizonte (las estrellas se apagan donde el cielo brilla) y la Luna llena en lugar del Sol.
// Sin TIME a propósito: así el mapa de radiancia se calcula una vez y no en cada fotograma.

uniform vec3 zenith : source_color = vec3(0.0);
uniform vec3 horizon : source_color = vec3(0.0);
uniform vec3 disc_color : source_color = vec3(1.0, 0.96, 0.88);
uniform float disc_size = 0.9993;  // coseno del radio del disco del astro (Luna llena: más grande)

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Una estrella como mucho por celda de la rejilla; el brillo y el color cambian con cada una.
vec3 stars(vec3 dir, float scale, float density) {
	vec3 cell = floor(dir * scale);
	float h = hash(cell);
	float spot = 1.0 - smoothstep(0.08, 0.32, length(fract(dir * scale) - 0.5));
	vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.7), fract(h * 31.0));
	return tint * step(density, h) * spot * (0.5 + 1.5 * fract(h * 17.0));
}

void sky() {
	vec3 d = EYEDIR;
	vec3 gradient = mix(horizon, zenith, smoothstep(-0.05, 0.55, d.y));
	float band = exp(-pow(dot(d, normalize(vec3(0.35, 0.75, -0.55))) * 3.0, 2.0));
	vec3 color = vec3(0.004, 0.006, 0.02) + gradient;
	float dark = 1.0 - smoothstep(0.0, 0.12, max(gradient.r, max(gradient.g, gradient.b)));
	if (band > 0.02) {
		color += vec3(0.07, 0.06, 0.12) * band * (noise(d * 6.0) * 0.6 + noise(d * 15.0) * 0.4) * (0.4 + 0.6 * dark);
	}
	color += (stars(d, 260.0, 0.996 - 0.004 * band) + stars(d, 80.0, 0.997) * 1.5) * (0.25 + 0.75 * dark);
	float disc = smoothstep(disc_size, disc_size + 0.0004, dot(d, LIGHT0_DIRECTION));
	color += disc_color * disc * 6.0 * (0.85 + 0.15 * noise(d * 300.0));  // manchas: los "mares" de la Luna
	color += disc_color * pow(max(dot(d, LIGHT0_DIRECTION), 0.0), 200.0) * 0.3;  // halo
	COLOR = color;
}

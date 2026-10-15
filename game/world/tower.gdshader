shader_type spatial;
// Torre de juguete estilo Astro Bot: plástico brillante de color caramelo, filas de ojos de buey
// que brillan al azar y un borde de luz (fresnel). Color y semilla cambian por torre.

instance uniform vec3 body_color : source_color = vec3(1.0);
instance uniform vec3 light_color : source_color = vec3(0.3, 0.85, 1.0);
instance uniform float seed = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = body_color;
	ROUGHNESS = 0.2;
	CLEARCOAT = 0.8;
	CLEARCOAT_ROUGHNESS = 0.08;
	if (abs(world_normal.y) < 0.5 && world_pos.y > 1.6) {
		vec2 cell = vec2(UV.x * 14.0, world_pos.y / 2.6);
		float d = length((fract(cell) - 0.5) * vec2(1.0, 1.3));
		float hole = 1.0 - smoothstep(0.22, 0.26, d);
		float frame = smoothstep(0.25, 0.28, d) * (1.0 - smoothstep(0.31, 0.34, d));  // aro alrededor de la ventana
		float lit = step(0.3, fract(sin(dot(floor(cell) + seed, vec2(12.9898, 78.233))) * 43758.5453));
		ALBEDO = mix(body_color * (1.0 - 0.25 * frame), vec3(0.03, 0.05, 0.1), hole);
		ROUGHNESS = mix(0.2, 0.04, hole);
		EMISSION = light_color * hole * lit * 3.0;
	}
	ALBEDO *= mix(0.6, 1.0, smoothstep(0.0, 2.5, world_pos.y));  // sombra de contacto falsa: la torre se asienta en el suelo
	EMISSION += body_color * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.3;
}

shader_type spatial;
// Edificios de Kenney de noche: la textura de paleta (colormap) da el color; los píxeles azul claro son
// cristales y, al azar por planta y tramo de fachada (celdas de 3 × 2,6 m), se encienden con luz cálida de interior.

uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform vec3 light_color : source_color = vec3(1.0, 0.82, 0.52);

varying vec3 world_pos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	float glass = smoothstep(0.06, 0.14, c.b - c.r) * step(0.45, c.b);
	float lit = step(0.55, hash(floor(world_pos / vec3(3.0, 2.6, 3.0))));
	ALBEDO = mix(c, c * 0.35, glass);  // cristal oscuro si la ventana está apagada
	ROUGHNESS = mix(0.55, 0.08, glass);
	EMISSION = light_color * glass * lit * 0.9;
}

shader_type spatial;
// Ojo LED que parpadea solo: cada ojo se cierra un instante cada ~4 s, desfasado según su posición.
render_mode unshaded;

uniform vec3 color : source_color = vec3(0.2, 0.72, 1.0);

void vertex() {
	float t = fract(TIME * 0.25 + NODE_POSITION_WORLD.x * 0.37 + NODE_POSITION_WORLD.z * 0.11);
	VERTEX.y *= 1.0 - 0.9 * step(0.97, t);
}

void fragment() {
	ALBEDO = color * 2.5;
}

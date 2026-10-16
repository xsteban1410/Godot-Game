shader_type spatial;
// Copa de árbol de juguete: plástico verde que se mece con el viento. Cuanto más alto el vértice, más se
// mueve (el árbol se dobla desde el tronco); la fase cambia despacio con la posición, así cada árbol va a
// su ritmo pero las bolas de una misma copa se mueven juntas. El color llega en los vértices (Kit.bake).

varying vec3 tint;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * 1.4 + world.x * 0.13 + world.z * 0.17;
	vec3 sway = vec3(sin(phase), 0.0, sin(phase * 0.8 + 1.3) * 0.6) * 0.06 * max(world.y - 1.6, 0.0);
	VERTEX += sway * mat3(MODEL_MATRIX);  // de mundo a local (sin escala: basta la traspuesta)
	tint = mix(pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.35;
	RIM = 0.3;
	RIM_TINT = 0.7;
}

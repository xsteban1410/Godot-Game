shader_type spatial;
// Ojo LED que parpadea solo: cada ojo se cierra un instante cada ~4 s, desfasado según dónde está el robot.
// Al parpadear solo queda una raya horizontal (por UV, así vale también con la malla animada por huesos).
render_mode unshaded;

uniform vec3 color : source_color = vec3(0.2, 0.72, 1.0);

void fragment() {
	float t = fract(TIME * 0.25 + NODE_POSITION_WORLD.x * 0.37 + NODE_POSITION_WORLD.z * 0.11);
	if (t > 0.97 && abs(UV.y - 0.5) > 0.07) {
		discard;
	}
	ALBEDO = color * 2.5;
}

shader_type spatial;
// Baldosa de una cuadrícula hecha con MultiMesh (todas en un solo draw call): cada instancia trae su
// color en rgb y en el alfa cuánto brilla.

varying vec3 tint;
varying float glow;

void vertex() {
	tint = mix(pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));  // sRGB → lineal
	glow = COLOR.a;
}

void fragment() {
	ALBEDO = tint;
	EMISSION = tint * glow * 2.0;
	ROUGHNESS = 0.25;
	RIM = 0.3;
	RIM_TINT = 0.7;
}

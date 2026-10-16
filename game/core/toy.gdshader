shader_type spatial;
// Plástico de juguete de las piezas que funde Kit.bake: el color de cada pieza llega en los vértices (rgb)
// y su luz propia en el alfa (× 8). Así piezas de distinto color, con o sin luz, comparten un material y
// un draw call por trozo, con el mismo aspecto que Kit.mat (rugosidad, metal y borde de luz).

uniform float metallic = 0.0;
uniform float roughness = 0.22;

varying vec4 tint;

void vertex() {
	vec3 linear = mix(pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));  // sRGB → lineal
	tint = vec4(linear, COLOR.a * 8.0);
}

void fragment() {
	ALBEDO = tint.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	RIM = 0.3;
	RIM_TINT = 0.7;
	EMISSION = tint.rgb * tint.a;
}

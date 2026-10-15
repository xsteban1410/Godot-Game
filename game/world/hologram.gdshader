shader_type spatial;
// Holograma: brillo aditivo más intenso en los bordes (fresnel) con líneas de escaneo que suben.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(0.2, 0.85, 1.0);

varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float scan = 0.65 + 0.35 * sin(height * 30.0 - TIME * 6.0);
	ALBEDO = color * (0.35 + 2.5 * rim) * scan;
}

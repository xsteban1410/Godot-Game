shader_type spatial;
// Charco de luz en el suelo bajo una farola: un disco que suma luz y se apaga hacia el borde. Imita una luz
// real sin su coste (la Radeon 610M no aguanta decenas de luces). El color llega en los vértices (Kit.bake
// funde todos los charcos de un trozo en una malla).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

varying vec3 tint;

void vertex() {
	tint = mix(pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));  // sRGB → lineal
}

void fragment() {
	float fade = 1.0 - clamp(length(UV - 0.5) * 2.0, 0.0, 1.0);
	ALBEDO = tint * fade * fade * 0.9;
}

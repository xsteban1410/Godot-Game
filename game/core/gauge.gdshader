shader_type spatial;
// Franja de combustible del jetpack: se apaga de un extremo al otro según `fill` (UV.x va de 0 a 1 a lo ancho).
render_mode unshaded;

uniform vec3 color : source_color = vec3(0.2, 0.72, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	ALBEDO = mix(vec3(0.04, 0.05, 0.07), color * 2.5, step(UV.x, fill));
}

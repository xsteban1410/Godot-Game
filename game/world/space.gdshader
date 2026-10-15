shader_type sky;
// Cielo lunar: negro, sin atmósfera, con estrellas que titilan y el disco del Sol.

void sky() {
	vec3 cell = floor(EYEDIR * 260.0);
	float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
	float star = step(0.996, h) * (1.0 - smoothstep(0.15, 0.35, length(fract(EYEDIR * 260.0) - 0.5)));
	float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + h * 60.0);
	COLOR = vec3(0.004, 0.006, 0.02) + vec3(star * twinkle * 2.0);
	COLOR += vec3(1.0, 0.96, 0.88) * smoothstep(0.9993, 0.9998, dot(EYEDIR, LIGHT0_DIRECTION)) * 6.0;
}

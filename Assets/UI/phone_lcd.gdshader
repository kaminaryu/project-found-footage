shader_type canvas_item;
// Makes pictures look like a cheap 2002 colour screen:
// only a few shades per colour, mixed with a checker-like "dither" pattern.
// With show_static on, it draws animated TV static instead (used when a photo is missing).

uniform float color_levels = 8.0;        // shades per colour channel (fewer = more retro)
uniform bool show_static = false;
uniform vec2 static_cells = vec2(44.0, 33.0); // how many static "pixels" across and down
uniform float static_brightness = 0.6;

// 4x4 ordered dither pattern, returns 0..1
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;
	if (show_static) {
		float frame = floor(TIME * 12.0);
		float n = hash(floor(UV * static_cells) + vec2(frame * 1.7, frame * 9.2));
		c = vec4(vec3(n * static_brightness + 0.05), 1.0);
	}
	float steps = max(color_levels - 1.0, 1.0);
	float dither = bayer4(FRAGCOORD.xy) - 0.5;
	c.rgb = clamp(floor(c.rgb * steps + 0.5 + dither) / steps, 0.0, 1.0);
	COLOR = c;
}

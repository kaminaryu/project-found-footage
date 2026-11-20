shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float intensity : hint_range(0.0, 1.5) = 0.0;
uniform float slice_amount : hint_range(0.0, 1.0) = 0.6;
uniform float rgb_split : hint_range(0.0, 0.1) = 0.02;
uniform float block_amount : hint_range(0.0, 1.0) = 0.4;
uniform float scanline : hint_range(0.0, 1.0) = 0.25;
uniform float noise : hint_range(0.0, 1.0) = 0.08;
uniform float seed = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 24.0);
	float power = clamp(intensity, 0.0, 1.0);

	float slice_count = mix(10.0, 72.0, slice_amount);
	float slice = floor(uv.y * slice_count);
	float slice_rand = hash21(vec2(slice, t + seed));
	float slice_gate = step(1.0 - 0.45 * power, slice_rand);
	float slice_shift = (slice_rand * 2.0 - 1.0) * 0.09 * power * slice_gate;

	float jump_rand = hash21(vec2(t * 0.37 + seed, 3.7));
	if (jump_rand > 1.0 - 0.18 * power) {
		slice_shift += (jump_rand * 2.0 - 1.0) * 0.2 * power;
	}

	vec2 block_id = floor(uv * vec2(16.0, 10.0));
	float block_rand = hash21(block_id + vec2(t, seed));
	float block_gate = step(1.0 - 0.08 * block_amount * power, block_rand);
	vec2 block_shift = vec2((block_rand * 2.0 - 1.0) * 0.12 * power, 0.0) * block_gate;

	vec2 offset = vec2(slice_shift, 0.0) + block_shift;
	float split = rgb_split * power;

	vec4 base = textureLod(screen_texture, uv, 0.0);
	vec3 color;
	color.r = textureLod(screen_texture, uv + offset + vec2(split, 0.0), 0.0).r;
	color.g = textureLod(screen_texture, uv + offset, 0.0).g;
	color.b = textureLod(screen_texture, uv + offset - vec2(split, 0.0), 0.0).b;

	float scan = sin(uv.y * 900.0 + TIME * 40.0) * 0.5 + 0.5;
	color *= 1.0 - scanline * power * scan * 0.35;

	float grain = hash21(uv * 800.0 + vec2(t, seed));
	color += (grain - 0.5) * noise * power;

	COLOR = vec4(color, base.a);
}

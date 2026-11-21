shader_type canvas_item;

uniform float exposure : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float noise : hint_range(0.0, 1.0) = 0.0;
uniform int filter_mode = 0;

float random(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (filter_mode == 4) {
		vec4 total = vec4(0.0);
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				vec2 offset = vec2(float(x), float(y)) * 0.004;
				total += texture(TEXTURE, UV + offset);
			}
		}
		color = total / 25.0;
	}

	vec3 rgb = color.rgb;

	rgb = rgb * pow(2.0, exposure);
	rgb = (rgb - 0.5) * contrast + 0.5;

	float gray = dot(rgb, vec3(0.299, 0.587, 0.114));
	if (filter_mode == 1) {
		rgb = vec3(gray);
	} else if (filter_mode == 2) {
		rgb = 1.0 - rgb;
	} else if (filter_mode == 3) {
		rgb = gray * vec3(1.0, 0.82, 0.6);
	}

	float grain = random(UV + fract(TIME)) - 0.5;
	rgb = rgb + grain * noise;

	COLOR = vec4(clamp(rgb, 0.0, 1.0), color.a);
}
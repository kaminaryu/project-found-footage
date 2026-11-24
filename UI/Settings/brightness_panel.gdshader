shader_type canvas_item;

uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float base_level : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.rgb *= base_level * brightness;
}
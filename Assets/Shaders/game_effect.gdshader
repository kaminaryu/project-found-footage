shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform float aa_softness : hint_range(0.0, 1.0, 0.05) = 0.6;
uniform float vignette_strength : hint_range(0.0, 2.0, 0.05) = 0.5;
uniform int levels = 3;
uniform float spread = 0.01;

vec3 chromatic_slice(float t){
	vec3 res = vec3(1.0-t, 1.0 - abs(t - 1.0), t - 1.0);
	return max(res, 0.0);
}

void fragment() {
	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	vec2 block_coord = floor(FRAGCOORD.xy / pixel_size) + 0.5;
	vec2 grid_uv = (block_coord * pixel_size) / screen_size;
	float mip_level = log2(pixel_size) * aa_softness;
	vec4 col = textureLod(screen_texture, grid_uv, mip_level);
	COLOR = col;
	vec3 sum;
	COLOR.rgb = vec3(0);
	vec2 offset = (UV - vec2(0.5))*vec2(1,-1);
	for(int i = 0; i < levels; i++){
		float t = 2.0*float(i)/float(levels-1); // range 0.0->2.0
		vec3 slice = vec3(1.0-t, 1.0 - abs(t - 1.0), t - 1.0);
		slice = max(slice, 0.0);
		sum += slice;
		vec2 slice_offset = (t-1.0)*spread*offset;
		COLOR.rgb += slice * texture(screen_texture, grid_uv + slice_offset).rgb;
	}
	COLOR.rgb /= sum;
	
	vec2 centered_uv = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(centered_uv, centered_uv) * vignette_strength;
	COLOR.rgb *= clamp(vignette, 0.0, 1.0);
}	
	

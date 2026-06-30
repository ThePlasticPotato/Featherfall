#define TRANSPARENT vec4(0.0, 0.0, 0.0, 0.0)
#define TOLERANCE 0.004
uniform Image palette_tex;
uniform vec4 palette_uvs;
uniform float palette_id;
uniform vec2 pixel_size;

vec4 find_alt_color(vec4 in_color, vec2 corner)
{
    if (in_color.a == 0.0) return TRANSPARENT;
    
    float dist;
    vec2 test_pos;
    vec4 left_color;
    for (float i = corner.y; i < palette_uvs.w; i += pixel_size.y) {
		test_pos = vec2(corner.x, i);
		left_color = Texel(palette_tex, test_pos);
        
		dist = distance(left_color, in_color);

		if (dist < TOLERANCE) {
			float max_index = floor((palette_uvs.z - corner.x) / pixel_size.x);
			float base_index = clamp(floor(palette_id), 0.0, max_index);
			float next_index = clamp(base_index + 1.0, 0.0, max_index);
			vec4 base_color = Texel(palette_tex, vec2(corner.x + pixel_size.x * base_index, i));
			vec4 next_color = Texel(palette_tex, vec2(corner.x + pixel_size.x * next_index, i));
			return mix(base_color, next_color, fract(palette_id));
		}
    }
    return in_color;
}

vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screen_coords) {
    vec4 pixel = Texel(image, uvs);
    if (pixel.a == 0.0) {
        discard;
    }
    pixel = find_alt_color(pixel, palette_uvs.xy);
    return pixel*color;
}

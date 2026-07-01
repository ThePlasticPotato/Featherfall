extern Image pattern;
extern vec2 pattern_size;
extern vec2 sprite_size;
extern vec2 scroll;
extern number amount;
extern number flip_x;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 source = Texel(tex, texture_coords);
    vec2 pattern_coords = texture_coords;
    if (flip_x > 0.5)
    {
        pattern_coords.x = 1.0 - pattern_coords.x;
    }
    vec2 pixel = pattern_coords * sprite_size;
    vec2 pattern_uv = mod(pixel + scroll, pattern_size) / pattern_size;
    vec4 overlay = Texel(pattern, pattern_uv);

    return vec4(overlay.rgb * color.rgb, source.a * overlay.a * amount * color.a);
}

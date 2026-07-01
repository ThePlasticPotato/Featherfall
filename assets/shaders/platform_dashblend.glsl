extern number iTime;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 uv = texture_coords.xy;
    vec4 result = vec4(0.0);

    uv.x -= iTime * 0.8;
    result += Texel(tex, fract(uv)) * 0.75;
    result.rgba *= result.r;

    uv.x -= iTime * -0.6;
    result += Texel(tex, fract(uv)) * 0.7;
    result.rgba *= result.r;

    uv.x -= iTime * 0.2;
    result += Texel(tex, fract(uv)) * 0.65;
    result.rgba *= result.r;

    result *= result * 1.3;
    result *= 4.0 - texture_coords.y * 3.0;
    result.rgb *= color.rgb;
    result.rgb *= color.a;
    return result;
}

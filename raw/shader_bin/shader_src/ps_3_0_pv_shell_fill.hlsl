// The GSC animates HUD alpha from 0 to 1. It is fill progress here.
// Do not multiply output opacity by progress: the revealed pixels stay bright.
sampler2D colorMapSampler;
struct PixelInput
{
    float4 color : COLOR0;
    float2 texCoord : TEXCOORD0;
};
float4 ps_main(PixelInput input) : COLOR0
{
    float progress = saturate(input.color.a);
    float4 shell = tex2D(colorMapSampler, input.texCoord);
    // UV origin is top-left. Discard the upper, not-yet-loaded part.
    clip(input.texCoord.y - (1.0 - progress));
    return float4(shell.rgb * input.color.rgb, shell.a * 0.85);
}

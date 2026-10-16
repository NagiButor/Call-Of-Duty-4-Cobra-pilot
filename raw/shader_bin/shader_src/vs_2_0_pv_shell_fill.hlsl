// HUD coordinates are already in screen space; use the same transform as 2d.
float4x4 worldViewProjectionMatrix;
struct VertexInput
{
    float4 position : POSITION;
    float4 color : COLOR0;
    float2 texCoord : TEXCOORD0;
};
struct PixelInput
{
    float4 position : POSITION;
    float4 color : COLOR0;
    float2 texCoord : TEXCOORD0;
};
PixelInput vs_main(VertexInput input)
{
    PixelInput output;
    output.position = mul(input.position, worldViewProjectionMatrix);
    output.color = input.color;
    output.texCoord = input.texCoord;
    return output;
}

#ifndef M_BLEND_TERRAIN_INCLUDED
#define M_BLEND_TERRAIN_INCLUDED


///////////////////////////////////////////////////////////////////////////////
//                          BLEND TERRAIN COLOR                              //
///////////////////////////////////////////////////////////////////////////////

struct BlendTerrainInput
{
    half3 baseColor;
    // half3 normal;
    // half roughness;
    float3 positionWS;
    
    half2 blendRange;
    half terrainBrightness;
    half terrainRoughness;
    half4 terrainTransformData;
    half4 simpleTerrainColor;
};
struct BlendTerrainOutput
{
    half blendMask;
    half3 blendColor;
    half3 blendNormal;
    half blendRoughness;
    //half3 terrainWorldNormal;
};


TEXTURE2D(_VGTerrainControl); SAMPLER(sampler_VGTerrainControl);
TEXTURE2D(_VGTerrainSplat0);  SAMPLER(sampler_VGTerrainSplat0);
TEXTURE2D(_VGTerrainSplat1);  SAMPLER(sampler_VGTerrainSplat1);
TEXTURE2D(_VGTerrainSplat2);  SAMPLER(sampler_VGTerrainSplat2);
TEXTURE2D(_VGTerrainSplat3);  SAMPLER(sampler_VGTerrainSplat3);
TEXTURE2D(_VGTerrainColor);   SAMPLER(sampler_VGTerrainColor);
half _VGTerrainRoughness;
half4 _VGTerrainTransformData;
float2 _BlendRange;
float _TerrainBrightness;
float4 _VGDiffuseRemapScale0;
float4 _VGDiffuseRemapScale1;
float4 _VGDiffuseRemapScale2;
float4 _VGDiffuseRemapScale3;
float4 _VGTerrainControl_ST;
float4 _VGTerrainSplat0_ST, _VGTerrainSplat1_ST, _VGTerrainSplat2_ST, _VGTerrainSplat3_ST;

inline float2 VgGetTerrainBlendUV(float3 positionWS, half4 terrainTransformData)
{
    float2 uv = positionWS.xz - terrainTransformData.xy;
    return uv / max(terrainTransformData.zw, half2(1e-4, 1e-4));
}

inline half VgComputeTerrainBlendMask(float3 positionWS, float originY, half2 blendRange)
{
    return smoothstep(blendRange.x, blendRange.y, positionWS.y - originY);
}

inline void VgBuildBlendTerrainOutput(
    half3 baseColor,
    half3 terrainColor,
    half terrainRoughness,
    half blendMask,
    out BlendTerrainOutput output)
{
    output.blendColor = lerp(terrainColor, baseColor, blendMask);
    output.blendNormal = half3(0, 0, 1);
    output.blendRoughness = lerp(terrainRoughness, 1.0h, blendMask);
    output.blendMask = blendMask;
}

inline half3 VgSampleTerrainMixedDiffuse(float3 positionWS, half4 terrainTransformData)
{
    float2 uv = VgGetTerrainBlendUV(positionWS, terrainTransformData);
    half4 splatControl = SAMPLE_TEXTURE2D(_VGTerrainControl, sampler_VGTerrainControl, uv);

    float2 uv0 = uv * _VGTerrainSplat0_ST.xy + _VGTerrainSplat0_ST.zw;
    float2 uv1 = uv * _VGTerrainSplat1_ST.xy + _VGTerrainSplat1_ST.zw;
    float2 uv2 = uv * _VGTerrainSplat2_ST.xy + _VGTerrainSplat2_ST.zw;
    float2 uv3 = uv * _VGTerrainSplat3_ST.xy + _VGTerrainSplat3_ST.zw;

    float4 diffAlbedo0 = SAMPLE_TEXTURE2D_LOD(_VGTerrainSplat0, sampler_VGTerrainSplat0, uv0, 0);
    float4 diffAlbedo1 = SAMPLE_TEXTURE2D_LOD(_VGTerrainSplat1, sampler_VGTerrainSplat1, uv1, 0);
    float4 diffAlbedo2 = SAMPLE_TEXTURE2D_LOD(_VGTerrainSplat2, sampler_VGTerrainSplat2, uv2, 0);
    float4 diffAlbedo3 = SAMPLE_TEXTURE2D_LOD(_VGTerrainSplat3, sampler_VGTerrainSplat3, uv3, 0);

    half4 mixedDiffuse = 0.0h;
    mixedDiffuse += diffAlbedo0 * float4(_VGDiffuseRemapScale0.rgb * splatControl.rrr, 1.0);
    mixedDiffuse += diffAlbedo1 * float4(_VGDiffuseRemapScale1.rgb * splatControl.ggg, 1.0);
    mixedDiffuse += diffAlbedo2 * float4(_VGDiffuseRemapScale2.rgb * splatControl.bbb, 1.0);
    mixedDiffuse += diffAlbedo3 * float4(_VGDiffuseRemapScale3.rgb * splatControl.aaa, 1.0);
    return mixedDiffuse.rgb;
}

inline half3 VgSampleTerrainBakedDiffuse(float3 positionWS, half4 terrainTransformData)
{
    float2 uv = VgGetTerrainBlendUV(positionWS, terrainTransformData);
    return SAMPLE_TEXTURE2D_LOD(_VGTerrainColor, sampler_VGTerrainColor, uv, 0).rgb;
}

inline void VgBlendTerrainFromSplat(
    float3 positionWS,
    float originY,
    half3 baseColor,
    half2 blendRange,
    half terrainBrightness,
    half terrainRoughness,
    half4 terrainTransformData,
    out BlendTerrainOutput output)
{
    half3 terrainColor = VgSampleTerrainMixedDiffuse(positionWS, terrainTransformData) * terrainBrightness;
    half blendMask = VgComputeTerrainBlendMask(positionWS, originY, blendRange);
    VgBuildBlendTerrainOutput(baseColor, terrainColor, terrainRoughness, blendMask, output);
}

inline void VgBlendTerrainFromBaked(
    float3 positionWS,
    float originY,
    half3 baseColor,
    half2 blendRange,
    half terrainBrightness,
    half terrainRoughness,
    half4 terrainTransformData,
    out BlendTerrainOutput output)
{
    half3 terrainColor = VgSampleTerrainBakedDiffuse(positionWS, terrainTransformData) * terrainBrightness;
    half blendMask = VgComputeTerrainBlendMask(positionWS, originY, blendRange);
    VgBuildBlendTerrainOutput(baseColor, terrainColor, terrainRoughness, blendMask, output);
}

inline void VgBlendTerrainFromColor(
    float3 positionWS,
    float originY,
    half3 baseColor,
    half3 terrainColor,
    half2 blendRange,
    half terrainBrightness,
    half terrainRoughness,
    out BlendTerrainOutput output)
{
    half blendMask = VgComputeTerrainBlendMask(positionWS, originY, blendRange);
    VgBuildBlendTerrainOutput(baseColor, terrainColor * terrainBrightness, terrainRoughness, blendMask, output);
}


void BlendTerrainNew(BlendTerrainInput input,half3x3 tangentToWorld,out BlendTerrainOutput output)
{
    half3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
    VgBlendTerrainFromSplat(
        input.positionWS,
        objToWorld.y,
        input.baseColor,
        input.blendRange,
        input.terrainBrightness,
        input.terrainRoughness,
        input.terrainTransformData,
        output);
}

//与地形混合
void BlendTerrain(BlendTerrainInput input,half3x3 tangentToWorld,out BlendTerrainOutput output)
{

    half3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
    VgBlendTerrainFromColor(
        input.positionWS,
        objToWorld.y,
        input.baseColor,
        input.simpleTerrainColor.rgb,
        input.blendRange,
        input.terrainBrightness,
        input.terrainRoughness,
        output);
}

void M_SimpleBlendTerrainn(half4 tangentWS , float3 normalWS, float3 positionWS ,
    half2 blendRange,SurfaceData surfaceData,half4 colorTerrain,out BlendTerrainOutput output)
{
    float sgn = tangentWS.w;
    float3 bitangent = sgn * cross(normalWS.xyz, tangentWS.xyz);

    BlendTerrainInput blendTerrainInput;
    blendTerrainInput.baseColor = surfaceData.albedo;
    // blendTerrainInput.normal = half3(0,0,1);
    // blendTerrainInput.roughness = 1;
    blendTerrainInput.positionWS = positionWS;
    
    blendTerrainInput.blendRange = blendRange;
    blendTerrainInput.terrainBrightness = _TerrainBrightness;
    blendTerrainInput.terrainRoughness = _VGTerrainRoughness;
    blendTerrainInput.terrainTransformData = _VGTerrainTransformData;
    blendTerrainInput.simpleTerrainColor = colorTerrain;

    
    BlendTerrain(blendTerrainInput,
        half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz) ,
        output);    
}

void M_BlendTerrain(half4 tangentWS , float3 normalWS, float3 positionWS ,
    half2 blendRange,SurfaceData surfaceData,out BlendTerrainOutput output)
{
    float sgn = tangentWS.w;
    float3 bitangent = sgn * cross(normalWS.xyz, tangentWS.xyz);

    BlendTerrainInput blendTerrainInput;
    blendTerrainInput.baseColor = surfaceData.albedo;
    // blendTerrainInput.normal = half3(0,0,1);
    // blendTerrainInput.roughness = 1;
    blendTerrainInput.positionWS = positionWS;
    
    blendTerrainInput.blendRange = blendRange;
    blendTerrainInput.terrainBrightness = _TerrainBrightness;
    blendTerrainInput.terrainRoughness = _VGTerrainRoughness;
    blendTerrainInput.terrainTransformData = _VGTerrainTransformData;
    blendTerrainInput.simpleTerrainColor = half4(0,0,0,0);
    
    BlendTerrainNew(blendTerrainInput,
        half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz) ,
        output);    
}

void BlendMoss(BlendTerrainInput input,half3x3 tangentToWorld,half4 mossColor,out BlendTerrainOutput output)
{

    half3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
    VgBlendTerrainFromColor(
        input.positionWS,
        objToWorld.y,
        input.baseColor,
        mossColor.rgb,
        input.blendRange,
        input.terrainBrightness,
        input.terrainRoughness,
        output);
}

void M_BlendMoss(half4 tangentWS , float3 normalWS, float3 positionWS ,
    half2 blendRange,SurfaceData surfaceData,half4 mossColor,out BlendTerrainOutput output)
{
    float sgn = tangentWS.w;
    float3 bitangent = sgn * cross(normalWS.xyz, tangentWS.xyz);

    BlendTerrainInput blendTerrainInput;
    blendTerrainInput.baseColor = surfaceData.albedo;
    // blendTerrainInput.normal = half3(0,0,1);
    // blendTerrainInput.roughness = 1;
    blendTerrainInput.positionWS = positionWS;
    
    blendTerrainInput.blendRange = blendRange;
    blendTerrainInput.terrainBrightness = _TerrainBrightness;
    blendTerrainInput.terrainRoughness = _VGTerrainRoughness;
    blendTerrainInput.terrainTransformData = _VGTerrainTransformData;
    BlendMoss(blendTerrainInput,
        half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz) ,mossColor,
        output);    
}

#endif

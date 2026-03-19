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


TEXTURE2D(_Control);    SAMPLER(sampler_Control);
TEXTURE2D(_Splat0);     SAMPLER(sampler_Splat0);
TEXTURE2D(_Splat1);     SAMPLER(sampler_Splat1);
TEXTURE2D(_Splat2);     SAMPLER(sampler_Splat2);
TEXTURE2D(_Splat3);     SAMPLER(sampler_Splat3);
float4 _DiffuseRemapScale0;
float4 _DiffuseRemapScale1;
float4 _DiffuseRemapScale2;
float4 _DiffuseRemapScale3;
float4 _Control_ST;
float4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;


void BlendTerrainNew(BlendTerrainInput input,half3x3 tangentToWorld,out BlendTerrainOutput output)
{
    float2 uv = float2(input.positionWS.x, input.positionWS.z) - float2(input.terrainTransformData.x,input.terrainTransformData.y);
    uv = uv/half2(input.terrainTransformData.z,input.terrainTransformData.w);
    
    half4 splatControl = SAMPLE_TEXTURE2D(_Control,sampler_Control,uv);

    float2 uv0 = uv * _Splat0_ST.xy + _Splat0_ST.zw;
    float2 uv1 = uv * _Splat1_ST.xy + _Splat1_ST.zw;
    float2 uv2 = uv * _Splat2_ST.xy + _Splat2_ST.zw;
    float2 uv3 = uv * _Splat3_ST.xy + _Splat3_ST.zw;

    float4 diffAlbedo[4];
    uint mipLevel = 0;
    diffAlbedo[0] =  SAMPLE_TEXTURE2D_LOD(_Splat0, sampler_Splat0, uv0, mipLevel);
    diffAlbedo[1] =  SAMPLE_TEXTURE2D_LOD(_Splat1, sampler_Splat1, uv1, mipLevel);
    diffAlbedo[2] =  SAMPLE_TEXTURE2D_LOD(_Splat2, sampler_Splat2, uv2, mipLevel);
    diffAlbedo[3] =  SAMPLE_TEXTURE2D_LOD(_Splat3, sampler_Splat3, uv3, mipLevel);
    
    half4 mixedDiffuse = 0.0h;
    mixedDiffuse += diffAlbedo[0] * float4(_DiffuseRemapScale0.rgb * splatControl.rrr, 1.0);
    mixedDiffuse += diffAlbedo[1] * float4(_DiffuseRemapScale1.rgb * splatControl.ggg, 1.0);
    mixedDiffuse += diffAlbedo[2] * float4(_DiffuseRemapScale2.rgb * splatControl.bbb, 1.0);
    mixedDiffuse += diffAlbedo[3] * float4(_DiffuseRemapScale3.rgb * splatControl.aaa, 1.0);

    half4 terrainColor = mixedDiffuse;
    terrainColor *= input.terrainBrightness;

    half3 normal = half3(0,0,1);
    half terrainRoughness = 1;

    half3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
    float smoothStep = smoothstep(input.blendRange.x,input.blendRange.y,input.positionWS.y - objToWorld.y);
    output.blendColor = lerp(terrainColor.rgb,input.baseColor,smoothStep);
    //output.blendColor = terrainColor;
    output.blendNormal = normal;
    output.blendRoughness = lerp(input.terrainRoughness,terrainRoughness,smoothStep);
    output.blendMask = smoothStep;
}

//与地形混合
void BlendTerrain(BlendTerrainInput input,half3x3 tangentToWorld,out BlendTerrainOutput output)
{

    half3 normal = half3(0,0,1);
    half terrainRoughness = 1;
    
    
    //float2 uv = float2(input.positionWS.x, input.positionWS.z) - float2(input.terrainTransformData.x,input.terrainTransformData.y);
    //uv = uv/half2(input.terrainTransformData.z,input.terrainTransformData.w) + float2(0.5,0.5);

    half4 _tColor = input.simpleTerrainColor;
    half3 terrainColor = _tColor.rgb * input.terrainBrightness;

    half3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
    float smoothStep = smoothstep(input.blendRange.x,input.blendRange.y,input.positionWS.y - objToWorld.y);
    output.blendColor = lerp(terrainColor,input.baseColor,smoothStep);
    //
    /*
    float3 terrianNormal = tex2D(input.terrainNormal2D,uv);
    terrianNormal = terrianNormal * 2 - 1;
    output.terrainWorldNormal = terrianNormal;

    float3 normalTS = TransformWorldToTangent(terrianNormal,tangentToWorld);
    output.blendNormal = lerp(normalTS,normal,smoothStep)
    */
    output.blendNormal = normal;

    output.blendRoughness = lerp(input.terrainRoughness,terrainRoughness,smoothStep);
    output.blendMask = smoothStep;

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
    blendTerrainInput.terrainRoughness = _TerrainRoughness;
    blendTerrainInput.terrainTransformData = _TerrainTransformData;
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
    blendTerrainInput.terrainRoughness = _TerrainRoughness;
    blendTerrainInput.terrainTransformData = _TerrainTransformData;
    blendTerrainInput.simpleTerrainColor = half4(0,0,0,0);
    
    BlendTerrainNew(blendTerrainInput,
        half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz) ,
        output);    
}

void BlendMoss(BlendTerrainInput input,half3x3 tangentToWorld,half4 mossColor,out BlendTerrainOutput output)
{

    half3 normal = half3(0,0,1);
    half terrainRoughness = 1;
    
    
    float2 uv = float2(input.positionWS.x, input.positionWS.z) - float2(input.terrainTransformData.x,input.terrainTransformData.y);
    uv = uv/half2(input.terrainTransformData.z,input.terrainTransformData.w);
    
    half3 terrainColor = mossColor.rgb * input.terrainBrightness;

    half3 objToWorld = mul( GetObjectToWorldMatrix(), float4( float3( 0,0,0 ), 1 ) ).xyz;
    float smoothStep = smoothstep(input.blendRange.x,input.blendRange.y,input.positionWS.y - objToWorld.y);
    output.blendColor = lerp(terrainColor,input.baseColor,smoothStep);
    //
    /*
    float3 terrianNormal = tex2D(input.terrainNormal2D,uv);
    terrianNormal = terrianNormal * 2 - 1;
    output.terrainWorldNormal = terrianNormal;

    float3 normalTS = TransformWorldToTangent(terrianNormal,tangentToWorld);
    output.blendNormal = lerp(normalTS,normal,smoothStep)
    */
    output.blendNormal = normal;

    output.blendRoughness = lerp(input.terrainRoughness,terrainRoughness,smoothStep);
    output.blendMask = smoothStep;

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
    blendTerrainInput.terrainRoughness = _TerrainRoughness;
    blendTerrainInput.terrainTransformData = _TerrainTransformData;
    BlendMoss(blendTerrainInput,
        half3x3(tangentWS.xyz, bitangent.xyz, normalWS.xyz) ,mossColor,
        output);    
}

#endif

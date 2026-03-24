#ifndef PLANTINDIRECT_FORWARD_INCLUDE
#define PLANTINDIRECT_FORWARD_INCLUDE

#include "Assets/Shaders/HLSL/Lighting/CustomLighting.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/BlendTerrain.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/CommonFunc.hlsl"

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float4 tangentOS  : TANGENT;
    float2 uv         : TEXCOORD0;
    float4 color      : COLOR;
    uint instanceID   : SV_InstanceID;
};

struct Varyings
{
    float2 uv         : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS   : TEXCOORD2;
    float4 tangentWS  : TEXCOORD3;
    half fogFactor    : TEXCOORD4;
    float4 shadowCoord : TEXCOORD5;
    half3 vertexSH    : TEXCOORD6;
    float2 staticLightmapUV : TEXCOORD7;
    float4 screenPos  : TEXCOORD8;
    float originY     : TEXCOORD9;
    float4 positionCS : SV_POSITION;
};

void VgPlantBlendTerrainBakedInstance(
    float3 positionWS,
    float originY,
    SurfaceData surfaceData,
    out BlendTerrainOutput output)
{
    VgBlendTerrainFromBaked(
        positionWS,
        originY,
        surfaceData.albedo,
        _BlendRange,
        _TerrainBrightness,
        _VGTerrainRoughness,
        _VGTerrainTransformData,
        output);
}

void VgPlantBlendMossInstance(
    float3 positionWS,
    float originY,
    SurfaceData surfaceData,
    out BlendTerrainOutput output)
{
    half2 mossUV_xy = half2(_MossUV.x, _MossUV.y);
    half2 mossUV_zw = half2(_MossUV.z, _MossUV.w);
    float2 uv1 = float2(positionWS.x, positionWS.z) / (half2(2, 2) / max(mossUV_xy, half2(1e-4, 1e-4)));
    float2 uv2 = mossUV_zw / max(mossUV_xy, half2(1e-4, 1e-4));
    float2 finalMossUV = uv1 + uv2;
    half4 mossColor = VgSampleAlbedoAlpha(finalMossUV, TEXTURE2D_ARGS(_MossBase, sampler_MossBase));

    VgBlendTerrainFromColor(
        positionWS,
        originY,
        surfaceData.albedo,
        mossColor.rgb,
        _BlendRange,
        _TerrainBrightness,
        _VGTerrainRoughness,
        output);
}

inline void ApplyPlantVertexAnimation(inout Attributes input)
{
    #if defined(_WIND_ON)
    WindStruct windData;
    windData.windSpeed = _WindSpeed;
    windData.vertexColor = input.color;
    windData.leafStrength = _LeafStrength;
    windData.normalOS = input.normalOS;
    windData.positionOS = input.positionOS.xyz;
    windData.bendStrength = _BendStrength;
    windData.bendSpeed = _BendSpeed;
    windData.bendWait = _BendWait;
    windData.windDirection = _WindDirection.xy;
    windData.instanceID = input.instanceID;
    input.positionOS.xyz += PlantWind(windData);
    #endif

    #if defined(_CIRCE_WIND_ON)
    NewWindStruct circleWind;
    circleWind.windDirection = _CirceWindDirection.xy;
    circleWind.windSpeed = _CirceWindSpeed;
    circleWind.windJitter = _WindJitter;
    circleWind.windStrength = _WindStrength;
    circleWind.instanceID = input.instanceID;
    input.positionOS.xyz += input.normalOS * GetWindScroll(circleWind, float4(input.positionOS.xyz, 1.0), _WindNoiseSize, _NoisePower);
    #endif

    input.positionOS.xyz += PlantInteractionOffset(input.positionOS.xyz) * input.positionOS.y;
}

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    float sgn = input.tangentWS.w;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    inputData.tangentToWorld = tangentToWorld;
    inputData.normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
    inputData.viewDirectionWS = viewDirWS;
    inputData.shadowCoord = input.shadowCoord;
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
}

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    ApplyPlantVertexAnimation(input);

    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    float3 normalWS = GetInstanceWorldNormal(input.normalOS, input.instanceID);
    float3 tangentWS = GetInstanceWorldDirection(input.tangentOS.xyz, input.instanceID);
    float4 positionCS = TransformWorldToHClip(positionWS);

    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    output.positionWS = positionWS;
    output.normalWS = normalize(normalWS);
    output.tangentWS = float4(normalize(tangentWS), input.tangentOS.w);
    output.fogFactor = ComputeFogFactor(positionCS.z);
    output.shadowCoord = TransformWorldToShadowCoord(positionWS);
    output.staticLightmapUV = 0;
    output.vertexSH = SampleSHVertex(output.normalWS);
    output.screenPos = ComputeScreenPos(positionCS);
    output.originY = GetInstanceOriginWS(input.instanceID).y;
    output.positionCS = positionCS;
    return output;
}

void LitPassFragment(
    Varyings input
    , out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    SurfaceData surfaceData = (SurfaceData)0;
    M_InitializePlantSurfaceData(input.uv, surfaceData, GetWorldSpaceNormalizeViewDir(input.positionWS));

    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif

    #if defined(_BLEND_TERRAIN_ON)
    BlendTerrainOutput blendTerrainOutput;
        #ifdef _USEGROSS
    VgPlantBlendMossInstance(input.positionWS, input.originY, surfaceData, blendTerrainOutput);
        #else
            #if defined(_TERRAIN_BLEND_BAKED)
    VgPlantBlendTerrainBakedInstance(input.positionWS, input.originY, surfaceData, blendTerrainOutput);
            #else
    M_BlendTerrain(input.tangentWS, input.normalWS, input.positionWS, _BlendRange, surfaceData, blendTerrainOutput);
            #endif
        #endif
    surfaceData.albedo.rgb = blendTerrainOutput.blendColor.rgb;
    #endif

    #if defined(_SSS_ON)
    half4 customLight = half4(surfaceData.albedo, 1);
    half4 sssLight = FakeSSS(input.positionWS, input.normalWS, customLight, 1, _SSSDistortion, _SSSPower, _SSSScale, _SSSColor);
    surfaceData.albedo.rgb = sssLight.rgb;
    #endif

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    #if defined(_SSAO)
    surfaceData.occlusion *= lerp(1.0h, SampleAmbientOcclusion(inputData.normalizedScreenSpaceUV), _AOStrength);
    #endif

    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;

    CustomLightingData lightingData;
    half4 color = UniversalFragmentPBR(inputData, surfaceData, surfaceDataExt, lightingData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);

    if (_BackFaceShadowInt < 1.0h)
    {
        half3 backLit = surfaceData.albedo * (lightingData.giColor * _GIInt + lightingData.mainLightColor * _MainLightInt);
        color.rgb = lerp(backLit, color.rgb, _BackFaceShadowInt);
    }

    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}

#endif

#ifndef LEAFINDIRECT_FORWARD_INCLUDE
#define LEAFINDIRECT_FORWARD_INCLUDE

#include "Assets/Shaders/HLSL/Lighting/CustomLighting.hlsl"

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
    float4 positionCS : SV_POSITION;
};

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

    #if defined(_WIND_ON)
    input.positionOS.xyz += PlantWind(windData);
    #endif

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
    M_InitializeLeafSurfaceData(input.uv, surfaceData);

    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;

    CustomLightingData lightingData;
    half4 color = UniversalFragmentPBR(inputData, surfaceData, surfaceDataExt, lightingData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}

#endif

#ifndef VG_M_SIMPLE_LEAF_FORWARD_PASS_INCLUDED
#define VG_M_SIMPLE_LEAF_FORWARD_PASS_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Lighting.hlsl"

void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    float sgn = input.tangentWS.w;
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
    inputData.tangentToWorld = tangentToWorld;
    inputData.normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
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
    ApplyMSimpleLeafWind(input);

    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    float3 normalWS = GetInstanceWorldNormal(input.normalOS, input.instanceID);
    float3 tangentWS = GetInstanceWorldDirection(input.tangentOS.xyz, input.instanceID);
    float4 positionCS = TransformWorldToHClip(positionWS);

    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.positionWS = positionWS;
    output.normalWS = normalize(normalWS);
    output.tangentWS = float4(normalize(tangentWS), input.tangentOS.w);
    output.fogFactor = ComputeFogFactor(positionCS.z);
    output.shadowCoord = TransformWorldToShadowCoord(positionWS);
    output.vertexSH = SampleSHVertex(output.normalWS);
    output.staticLightmapUV = 0;
    output.positionCS = positionCS;
    output.color = input.color;
    return output;
}

void LitPassFragment(Varyings input, out half4 outColor : SV_Target0)
{
    SurfaceData surfaceData = (SurfaceData)0;
    M_InitializeSimpleLeafSurfaceData(input.uv, input.positionWS, input.normalWS, input.color, surfaceData);

    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    #if defined(_SSAO)
    surfaceData.occlusion *= lerp(1.0h, SampleAmbientOcclusion(inputData.normalizedScreenSpaceUV), _AOStrength);
    #endif

    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;

    half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData, surfaceDataExt);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    outColor = color;
}

#endif

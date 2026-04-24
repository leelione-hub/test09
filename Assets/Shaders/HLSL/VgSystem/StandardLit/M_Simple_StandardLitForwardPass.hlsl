#ifndef VG_M_SIMPLE_STANDARD_LIT_FORWARD_PASS_INCLUDED
#define VG_M_SIMPLE_STANDARD_LIT_FORWARD_PASS_INCLUDED

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
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), ComputeFogFactor(input.positionCS.z));
    inputData.bakedGI = SampleSH(inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = 1;
}

Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.positionWS = positionWS;
    output.normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));
    output.tangentWS = float4(normalize(GetInstanceWorldDirection(input.tangentOS.xyz, input.instanceID)), input.tangentOS.w);
    return output;
}

void LitPassFragment(Varyings input, out half4 outColor : SV_Target0)
{
    SurfaceData surfaceData = (SurfaceData)0;
    M_InitializeSimpleStandardLitSurfaceData(input.uv, surfaceData);
    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;
    half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData, surfaceDataExt);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    outColor = color;
}

#endif

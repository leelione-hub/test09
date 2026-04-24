#ifndef VG_M_SIMPLE_ROCK_FORWARD_PASS_INCLUDED
#define VG_M_SIMPLE_ROCK_FORWARD_PASS_INCLUDED

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
    M_InitializeSimpleRockSurfaceData(input.uv, input.positionWS, normalize(input.normalWS), surfaceData);
    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    #if defined(_SSAO)
    half ao = SampleAmbientOcclusion(inputData.normalizedScreenSpaceUV);
        #if defined(_USEGROSS)
    half edgeNoise = SAMPLE_TEXTURE2D(_MixTexNR, sampler_MixTexNR, input.uv).a;
    half blendMask = MSimpleRockGetBlendMask(input.positionWS, normalize(input.normalWS), edgeNoise);
    surfaceData.occlusion *= lerp(1.0h, lerp(ao, 1.0h, blendMask), _AOStrength);
        #else
    surfaceData.occlusion *= lerp(1.0h, ao, _AOStrength);
        #endif
    #endif
    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;
    half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData, surfaceDataExt);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    outColor = color;
}

#endif

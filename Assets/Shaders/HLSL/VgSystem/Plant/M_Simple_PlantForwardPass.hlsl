#ifndef VG_M_SIMPLE_PLANT_FORWARD_PASS_INCLUDED
#define VG_M_SIMPLE_PLANT_FORWARD_PASS_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Lighting.hlsl"

half3 CalculateSimplePlantBackLit(InputData inputData, SurfaceData surfaceData)
{
    half3 bakedGI = inputData.bakedGI;
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, bakedGI);

    #if defined(_LAMBERT_HALFLAMBERT)
    half mainLightNdotL = saturate(lerp(_BackBrightness, 1.0h, dot(inputData.normalWS, mainLight.direction) * 0.5h + 0.5h));
    #else
    half mainLightNdotL = saturate(dot(inputData.normalWS, mainLight.direction));
    #endif

    half3 giColor = saturate(bakedGI * aoFactor.indirectAmbientOcclusion);
    half3 mainLightColor = mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation * mainLightNdotL);
    return surfaceData.albedo * (giColor * _GIInt + mainLightColor * _MainLightInt);
}

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
    ApplyMSimplePlantWind(input);
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
    return output;
}

void LitPassFragment(Varyings input, out half4 outColor : SV_Target0)
{
    SurfaceData surfaceData = (SurfaceData)0;
    M_InitializeSimplePlantSurfaceData(input.uv, GetWorldSpaceNormalizeViewDir(input.positionWS), surfaceData);
    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif
    #if defined(_SSS_ON)
    surfaceData.albedo = FakeSSS(input.positionWS, input.normalWS, half4(surfaceData.albedo, 1), 1, _SSSDistortion, _SSSPower, _SSSScale, _SSSColor).rgb;
    #endif
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    #if defined(_EDGELIGHT_ON)
    half NoV = abs(dot(inputData.normalWS, inputData.viewDirectionWS));
    half edgeMask = _EdgeBrightIntensity * pow(saturate(1.0h - NoV), _EdgeBrightScale);
    surfaceData.albedo += edgeMask * _EdgeBrightColor.rgb;
    #endif
    #if defined(_SSAO)
    surfaceData.occlusion *= lerp(1.0h, SampleAmbientOcclusion(inputData.normalizedScreenSpaceUV), _AOStrength);
    #endif
    SurfaceDataExt surfaceDataExt;
    surfaceDataExt.backBrightness = _BackBrightness;
    surfaceDataExt.shadowStrength = _ShadowStrength;
    half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData, surfaceDataExt);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    if (_BackFaceShadowInt < 1.0h)
    {
        half3 backLit = CalculateSimplePlantBackLit(inputData, surfaceData);
        color.rgb = lerp(backLit, color.rgb, _BackFaceShadowInt);
    }
    outColor = color;
}

#endif

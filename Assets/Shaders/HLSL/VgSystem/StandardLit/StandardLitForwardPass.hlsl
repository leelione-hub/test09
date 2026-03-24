#ifndef VG_STANDARD_LIT_FORWARD_PASS_INCLUDED
#define VG_STANDARD_LIT_FORWARD_PASS_INCLUDED

#include "Assets/Shaders/HLSL/Lighting/CustomLighting.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitInput.hlsl"

void InitializeInputData(StandardLitVaryings input, half3 normalTS, out InputData inputData)
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
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), ComputeFogFactor(input.positionCS.z));
    inputData.bakedGI = SampleSH(inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = half4(1, 1, 1, 1);
}

StandardLitVaryings LitPassVertex(StandardLitAttributes input)
{
    return StandardLitBuildVaryings(input);
}

void LitPassFragment(
    StandardLitVaryings input
    , out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    SurfaceData surfaceData = (SurfaceData)0;
    M_InitializeStandardLitSurfaceData(input.uv, surfaceData);

    #if defined(_ALPHATEST_ON)
    clip(surfaceData.alpha - _Cutoff);
    #endif

    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif

    half roughness = saturate(_Roughness);
    VgApplyOverlay(input.overlayUV, surfaceData.albedo, roughness);
    VgApplyVertexPaint(input, input.uv, surfaceData.albedo, surfaceData.normalTS, roughness);
    VgApplyTerrainBlend(input, surfaceData.albedo, roughness);
    surfaceData.smoothness = saturate(1.0h - roughness);
    surfaceData.occlusion = VgSampleAO(input.uv, surfaceData.albedo);

    #if defined(_EMISSION_ON)
    surfaceData.emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb * _EmissionColor.rgb * _EmissiveIntensity;
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
    outColor = color;

    #ifdef _WRITE_RENDERING_LAYERS
    uint renderingLayers = GetMeshRenderingLayer();
    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
    #endif
}

#endif

#ifndef VG_ROCK_FORWARD_PASS_INCLUDED
#define VG_ROCK_FORWARD_PASS_INCLUDED

#include "Assets/Shaders/HLSL/Lighting/CustomLighting.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/Rock/RockInput.hlsl"

void InitializeInputData(RockVaryings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = NormalizeNormalPerPixel(input.normalWS);
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), ComputeFogFactor(input.positionCS.z));
    inputData.bakedGI = SampleSH(inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = half4(1, 1, 1, 1);
}

RockVaryings LitPassVertex(RockAttributes input)
{
    return RockForwardVert(input);
}

void LitPassFragment(
    RockVaryings input
    , out half4 outColor : SV_Target0
#ifdef _WRITE_RENDERING_LAYERS
    , out float4 outRenderingLayers : SV_Target1
#endif
)
{
    SurfaceData surfaceData = (SurfaceData)0;
    M_InitializeRockSurfaceData(input.uv, surfaceData);

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

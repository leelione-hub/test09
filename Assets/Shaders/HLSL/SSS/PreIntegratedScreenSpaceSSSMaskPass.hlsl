#ifndef PREINTEGRATED_SCREEN_SPACE_SSS_MASK_PASS_INCLUDED
#define PREINTEGRATED_SCREEN_SPACE_SSS_MASK_PASS_INCLUDED

#include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"

SSSVaryings DepthOnlyVertex(SSSAttributes input)
{
    return BuildSSSVaryings(input);
}

half4 SSSMaskFragment(SSSVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    half4 baseSample = SSSSampleBase(input.uv);
    half alpha = baseSample.a * _BaseColor.a;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif

    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif

    #if !defined(_SCREEN_SPACE_SSS_ON)
    return half4(0, 0, 0, 0);
    #else
    half thickness = saturate(SAMPLE_TEXTURE2D(_ThicknessMap, sampler_ThicknessMap, input.uv).r * _ThicknessScale);
    half mask = saturate(thickness * _ScreenSpaceSSSIntensity * _ScreenSpaceSSSDepthWeight);
    half3 tint = _SSSColor.rgb * thickness * _ScreenSpaceSSSBlurScale;
    return half4(tint, mask);
    #endif
}

#endif

#ifndef PREINTEGRATED_SCREEN_SPACE_SSS_DEPTH_ONLY_PASS_INCLUDED
#define PREINTEGRATED_SCREEN_SPACE_SSS_DEPTH_ONLY_PASS_INCLUDED

#include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"

SSSVaryings DepthOnlyVertex(SSSAttributes input)
{
    return BuildSSSVaryings(input);
}

half DepthOnlyFragment(SSSVaryings input) : SV_Target
{
    half alpha = SSSSampleBase(input.uv).a * _BaseColor.a;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    return input.positionCS.z;
}

#endif

#ifndef PREINTEGRATED_SCREEN_SPACE_SSS_DEPTH_NORMALS_PASS_INCLUDED
#define PREINTEGRATED_SCREEN_SPACE_SSS_DEPTH_NORMALS_PASS_INCLUDED

#include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"

SSSVaryings DepthOnlyVertex(SSSAttributes input)
{
    return BuildSSSVaryings(input);
}

half4 DepthNormalsFragment(SSSVaryings input) : SV_Target
{
    half alpha = SSSSampleBase(input.uv).a * _BaseColor.a;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif

    half3 normalWS = SSSGetNormalWS(input, SSSSampleNormalTS(input.uv));
    return half4(normalWS, 0);
}

#endif

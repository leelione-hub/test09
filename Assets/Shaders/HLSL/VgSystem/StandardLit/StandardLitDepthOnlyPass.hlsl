#ifndef VG_STANDARD_LIT_DEPTH_ONLY_PASS_INCLUDED
#define VG_STANDARD_LIT_DEPTH_ONLY_PASS_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitInput.hlsl"

StandardLitVaryings DepthVert(StandardLitAttributes input)
{
    return StandardLitBuildVaryings(input);
}

half DepthFrag(StandardLitVaryings input) : SV_Target
{
    half alpha = VgSampleBase(input.uv).a * _BaseColor.a * _Alpha;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    return input.positionCS.z;
}

#endif

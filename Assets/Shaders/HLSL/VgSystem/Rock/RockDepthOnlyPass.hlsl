#ifndef VG_ROCK_DEPTH_ONLY_PASS_INCLUDED
#define VG_ROCK_DEPTH_ONLY_PASS_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/Rock/RockInput.hlsl"

RockVaryings DepthVert(RockAttributes input)
{
    return RockForwardVert(input);
}

half DepthFrag(RockVaryings input) : SV_Target
{
    half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    #if defined(_ALPHATEST_ON)
    clip(tex.a * _Alpha - _Cutoff);
    #endif
    return input.positionCS.z;
}

#endif

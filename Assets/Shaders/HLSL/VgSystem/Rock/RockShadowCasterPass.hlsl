#ifndef VG_ROCK_SHADOW_CASTER_PASS_INCLUDED
#define VG_ROCK_SHADOW_CASTER_PASS_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/Rock/RockInput.hlsl"

RockVaryings ShadowVert(RockAttributes input)
{
    RockVaryings output = (RockVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    float3 normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));

    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
    float3 lightDirectionWS = _LightDirection;
    #endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
    #if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

    output.positionCS = positionCS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    return output;
}

half4 ShadowFrag(RockVaryings input) : SV_Target
{
    half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    #if defined(_ALPHATEST_ON)
    clip(tex.a * _Alpha - _Cutoff);
    #endif
    return 0;
}

#endif

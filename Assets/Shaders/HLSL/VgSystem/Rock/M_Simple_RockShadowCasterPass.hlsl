#ifndef VG_M_SIMPLE_ROCK_SHADOW_CASTER_PASS_INCLUDED
#define VG_M_SIMPLE_ROCK_SHADOW_CASTER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

float3 _LightDirection;
float3 _LightPosition;

struct ShadowVaryings
{
    float2 uv : TEXCOORD0;
    float4 positionCS : SV_POSITION;
};

ShadowVaryings ShadowPassVertex(Attributes input)
{
    ShadowVaryings output = (ShadowVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    float3 normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));
    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
    float3 lightDirectionWS = _LightDirection;
    #endif
    output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    return output;
}

half4 ShadowPassFragment(ShadowVaryings input) : SV_Target
{
    #if defined(_ALPHATEST_ON)
    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a * _Alpha - _Cutoff);
    #endif
    return 0;
}

#endif

#ifndef PREINTEGRATED_SCREEN_SPACE_SSS_SHADOW_CASTER_PASS_INCLUDED
#define PREINTEGRATED_SCREEN_SPACE_SSS_SHADOW_CASTER_PASS_INCLUDED

#include "Assets/Shaders/HLSL/SSS/PreIntegratedScreenSpaceSSSInput.hlsl"

struct ShadowVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

ShadowVaryings ShadowPassVertex(SSSAttributes input)
{
    ShadowVaryings output = (ShadowVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    float3 positionWS = TransformObjectToWorld(input.positionOS);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

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

half4 ShadowPassFragment(ShadowVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    half alpha = SSSSampleBase(input.uv).a * _BaseColor.a;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif
    return 0;
}

#endif

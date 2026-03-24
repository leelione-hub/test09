#ifndef VG_STANDARD_LIT_SHADOW_CASTER_PASS_INCLUDED
#define VG_STANDARD_LIT_SHADOW_CASTER_PASS_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/StandardLit/StandardLitInput.hlsl"

StandardLitVaryings ShadowVert(StandardLitAttributes input)
{
    StandardLitVaryings output = (StandardLitVaryings)0;
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
    #ifdef GRAPHICDRAW_ON
    GrassInstanceData instanceData = _InstanceBuffer[input.instanceID];
    output.objectScale = float3(instanceData.scale.x, instanceData.scale.y, instanceData.scale.x);
    #else
    output.objectScale.x = length(UNITY_MATRIX_M._m00_m10_m20);
    output.objectScale.y = length(UNITY_MATRIX_M._m01_m11_m21);
    output.objectScale.z = length(UNITY_MATRIX_M._m02_m12_m22);
    #endif
    output.uv = VgApplyClassicRoofUV(output.uv, input.color, output.objectScale);
    return output;
}

half4 ShadowFrag(StandardLitVaryings input) : SV_Target
{
    half alpha = VgSampleBase(input.uv).a * _BaseColor.a * _Alpha;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif
    #if defined(LOD_FADE_CROSSFADE)
    LODFadeCrossFade(input.positionCS);
    #endif
    return 0;
}

#endif

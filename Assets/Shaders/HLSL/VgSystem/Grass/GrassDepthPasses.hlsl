#ifndef VG_GRASS_DEPTH_PASSES_INCLUDED
#define VG_GRASS_DEPTH_PASSES_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/Grass/GrassInput.hlsl"

float3 _LightDirection;
float3 _LightPosition;

GrassDepthVaryings DepthOnlyVertex(GrassAttributes input)
{
    GrassDepthVaryings output = (GrassDepthVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    GrassWindResult wind = CalculateGrassWind(input.positionOS, input.instanceID);
    float4 deformedOS = input.positionOS;
    deformedOS.xyz += wind.offset;

    float3 positionWS = GetInstanceWorldPosition(deformedOS.xyz, input.instanceID);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.normalWS = GetInstanceWorldNormal(input.normalOS, input.instanceID);
    return output;
}

half DepthOnlyFragment(GrassDepthVaryings input) : SV_Target
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return input.positionCS.z;
}

GrassDepthVaryings DepthNormalsVertex(GrassAttributes input)
{
    return DepthOnlyVertex(input);
}

half4 DepthNormalsFragment(GrassDepthVaryings input) : SV_Target
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return half4(normalize(input.normalWS), 0.0);
}

GrassShadowVaryings ShadowPassVertex(GrassAttributes input)
{
    GrassShadowVaryings output = (GrassShadowVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    GrassWindResult wind = CalculateGrassWind(input.positionOS, input.instanceID);
    float4 deformedOS = input.positionOS;
    deformedOS.xyz += wind.offset;

    float3 positionWS = GetInstanceWorldPosition(deformedOS.xyz, input.instanceID);
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
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    return output;
}

half4 ShadowPassFragment(GrassShadowVaryings input) : SV_Target
{
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}

#endif

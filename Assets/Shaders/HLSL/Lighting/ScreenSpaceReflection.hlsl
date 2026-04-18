#ifndef VG_SCREEN_SPACE_REFLECTION_INCLUDED
#define VG_SCREEN_SPACE_REFLECTION_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_RiverSSRTexture);
SAMPLER(sampler_RiverSSRTexture);

bool VgSSRProjectWorldToUV(float3 positionWS, out float2 uv, out float rayLinearDepth)
{
    float4 clipPos = TransformWorldToHClip(positionWS);
    if (clipPos.w <= 0.0001)
    {
        uv = 0;
        rayLinearDepth = 0;
        return false;
    }

    float4 screenPos = ComputeScreenPos(clipPos);
    uv = screenPos.xy / screenPos.w;

    float4 screenPosNorm = screenPos / screenPos.w;
    screenPosNorm.z = (UNITY_NEAR_CLIP_VALUE >= 0) ? screenPosNorm.z : screenPosNorm.z * 0.5 + 0.5;
    rayLinearDepth = LinearEyeDepth(screenPosNorm.z, _ZBufferParams);

    return all(uv >= 0.0.xx) && all(uv <= 1.0.xx);
}

half VgSSRComputeEdgeFade(float2 uv, half edgeFade)
{
    float2 edge = min(uv, 1.0 - uv);
    float edgeFactor = min(edge.x, edge.y);
    return saturate(edgeFactor / max(edgeFade, 0.0001h));
}

half4 VgSampleScreenSpaceReflection(
    float3 surfacePositionWS,
    half3 surfaceNormalWS,
    half3 viewDirWS,
    half fresnelMask,
    half surfaceMask,
    half intensity,
    half blend,
    half distortion,
    half maskByFresnel,
    half maskBySurface,
    half validThreshold,
    half stepSize,
    half maxDistance,
    half thickness,
    half edgeFade,
    half rayStartBias,
    half maxSteps)
{
    half3 reflectionDirWS = normalize(reflect(-viewDirWS, surfaceNormalWS));
    float actualStepSize = max(stepSize, 0.01h);
    float actualMaxDistance = max(maxDistance, actualStepSize);
    int actualMaxSteps = clamp((int)round(maxSteps), 1, 128);
    float travel = actualStepSize;
    float3 rayStartWS = surfacePositionWS + surfaceNormalWS * rayStartBias;
    half3 hitColor = 0;
    half hitMask = 0;

    [loop]
    for (int i = 0; i < 128; i++)
    {
        if (i >= actualMaxSteps || travel > actualMaxDistance)
        {
            break;
        }

        float3 rayPositionWS = rayStartWS + reflectionDirWS * travel;
        float2 hitUV;
        float rayLinearDepth;
        if (!VgSSRProjectWorldToUV(rayPositionWS, hitUV, rayLinearDepth))
        {
            break;
        }

        hitUV += surfaceNormalWS.xz * distortion;
        if (any(hitUV < 0.0.xx) || any(hitUV > 1.0.xx))
        {
            break;
        }

        float sceneLinearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, sampler_CameraDepthTexture, hitUV, 0), _ZBufferParams);
        float hitDelta = rayLinearDepth - sceneLinearDepth;
        if (hitDelta > 0.0 && hitDelta < thickness)
        {
            half4 ssrSample = SAMPLE_TEXTURE2D(_RiverSSRTexture, sampler_RiverSSRTexture, hitUV);
            half validity = step(validThreshold, ssrSample.a);
            half edgeMask = VgSSRComputeEdgeFade(hitUV, edgeFade);
            hitMask = validity * edgeMask;
            hitColor = ssrSample.rgb;
            break;
        }

        travel += actualStepSize;
    }

    half ssrMask = blend * intensity * hitMask;
    ssrMask *= lerp(1.0h, fresnelMask, maskByFresnel);
    ssrMask *= lerp(1.0h, surfaceMask, maskBySurface);
    return half4(hitColor, saturate(ssrMask));
}

#endif

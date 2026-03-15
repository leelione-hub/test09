
#ifndef VG_REALTIME_LIGHTS_INCLUDED
#define VG_REALTIME_LIGHTS_INCLUDED

// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LightCookie/LightCookie.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Clustering.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"


///////////////////////////////////////////////////////////////////////////////
//                      Light Abstraction                                    //
///////////////////////////////////////////////////////////////////////////////

Light M_GetMainLight(half3 direction)
{
    Light light;
    light.direction = direction;
    #if USE_FORWARD_PLUS
    #if defined(LIGHTMAP_ON) && defined(LIGHTMAP_SHADOW_MIXING)
        light.distanceAttenuation = _MainLightColor.a;
    #else
        light.distanceAttenuation = 1.0;
    #endif
    #else
    light.distanceAttenuation = unity_LightData.z; // unity_LightData.z is 1 when not culled by the culling mask, otherwise 0.
    #endif
    light.shadowAttenuation = 1.0;
    light.color = _MainLightColor.rgb;

    light.layerMask = _MainLightLayerMask;

    return light;
}

Light M_GetMainLight(half3 direction,float4 shadowCoord, float3 positionWS, half4 shadowMask)
{
    Light light = M_GetMainLight(direction);
    light.shadowAttenuation = MainLightShadow(shadowCoord, positionWS, shadowMask, _MainLightOcclusionProbes);

    #if defined(_LIGHT_COOKIES)
    real3 cookieColor = SampleMainLightCookie(positionWS);
    light.color *= cookieColor;
    #endif

    return light;
}

Light M_GetMainLight(half3 direction,InputData inputData, half4 shadowMask, AmbientOcclusionFactor aoFactor)
{
    Light light = M_GetMainLight(direction,inputData.shadowCoord, inputData.positionWS, shadowMask);

    #if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_SURFACE_TYPE_TRANSPARENT)
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_AMBIENT_OCCLUSION))
    {
        light.color *= aoFactor.directAmbientOcclusion;
    }
    #endif

    return light;
}



Light M_GetMainLight(half3 direction,float4 shadowCoord)
{
    Light light = M_GetMainLight(direction);
    light.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
    return light;
}

#endif

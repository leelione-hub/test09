#ifndef VG_SURFACE_INPUT_INCLUDED
#define VG_SURFACE_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/Custom/CommonFunc.hlsl"

// TEXTURE2D(_BaseMap);
// SAMPLER(sampler_BaseMap);
// float4 _BaseMap_TexelSize;
// float4 _BaseMap_MipInfo;
// TEXTURE2D(_BumpMap);
// SAMPLER(sampler_BumpMap);
// TEXTURE2D(_EmissionMap);
// SAMPLER(sampler_EmissionMap);


///////////////////////////////////////////////////////////////////////////////
//                           PROJECT M CUSTOM                                //
///////////////////////////////////////////////////////////////////////////////

half3 GetNRM_Normal(half4 nrm, half scale)
{
#if defined(_NRM_ON)
    return unpackNormal(nrm.r,nrm.g, scale);
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

half3 GetNRM_Normal_Plant(half4 nrm, half scale,half backScale ,half3 viewDirWS)
{
#if defined(_NRM_ON)
    half3 normalBack = unpackNormal(nrm.r,nrm.g, backScale);
    half3 normal = unpackNormal(nrm.r,nrm.g, scale);

    half l = clamp(dot(_MainLightPosition.xyz,viewDirWS) * 0.5 + 0.5 , 0.001,1);
    normal = lerp(normalBack,normal,l);
    return normal;
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

half GetNRM_Metallic(half4 nrm, half metallic)
{
#if defined(_NRM_ON)
    return nrm.a * metallic;
#else
    return metallic;
#endif
}

half GetNRM_Roughness(half4 nrm, half roughness,half roughnessMin = 0)
{
#if defined(_NRM_ON)
    return lerp(roughnessMin, roughness, nrm.b);
#else
    return roughness;
#endif
}

//for vertex paint
half3 GetVertexPaintNormal(half4 nrm,half scale)
{
    return unpackNormal(nrm.r,nrm.g, scale);
}

half GetVertexPaintRoughness(half4 nrm)
{
    return nrm.b;
}


half3 SampleEmission(float2 uv, half3 emissionColor, half emissionIntensity, TEXTURE2D_PARAM(emissionMap, sampler_emissionMap))
{
#ifndef _EMISSION_ON
    return 0;
#else
    return SAMPLE_TEXTURE2D(emissionMap, sampler_emissionMap, uv).rgb * emissionColor * emissionIntensity;
#endif
}



half MyCustomExpression( float A )
{
    return 0>=A;
}

#endif

#ifndef BASIC_CACULATE_INCLUDE
#define BASIC_CACULATE_INCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"

// ====================== 常用工具函数 ======================
half DisneyLuminance(half3 color)
{
    return dot(color,half3(0.2126, 0.7152, 0.0722));
}

real Custom_Sq(real x)
{
    return x * x;
}

// Schlick 近似 Fresnel（Disney 用 5 次幂）
half Custom_SchlickFresnel(half cosTheta)
{
    half m = saturate(1.0 - cosTheta);
    half m2 = m * m;
    return m2 * m2 * m; // m^5
}

// Schlick 近似 Fresnel
half3 Custom_SchlickFresnel(half3 f0,half u)
{
    return f0 + (1.0 - f0) * pow(max(1.0 - u, 0.0),5.0);
}

// 漫反射（Disney Diffuse）
real3 DisneyDiffuse(float NdotV, float NdotL, float LdotH, float roughness, float3 baseColor)
{
    float fd90 = 0.5 + 2.0 * roughness * Custom_Sq(LdotH);
    float lightScatter = 1.0 + (fd90 - 1.0) * pow(max(1.0 - NdotL, 0.0), 5.0);
    float viewScatter = 1.0 + (fd90 - 1.0) * pow(max(1.0 - NdotV, 0.0), 5.0);
    return (baseColor / PI) * lightScatter * viewScatter;
}

half3 URPDiffuse(half metallic,half3 albedo)
{
    half oneMinusReflectivity  = OneMinusReflectivityMetallic(metallic);
    return albedo * oneMinusReflectivity;
}

float Custom_D_GGX(float NdotH, float roughness) 
{
    float a = Custom_Sq(roughness);
    float a2 = Custom_Sq(a);
    float denom = PI * Custom_Sq(Custom_Sq(NdotH) * (a2 - 1.0) + 1.0);
    return a2 / max(denom, 1e-7);
}

half Custom_D_Blinn(half roughness,half NdotH)
{
    half a = 2 / pow(roughness,4) - 2;
    return (a + 2) * pow(NdotH,a) / 2 * PI;
}

float G_SchlickGGX(float NdotV, float roughness) 
{
    // Disney modification for direct lighting hotness reduction
    float r = roughness + 1.0;
    float k = (r * r) / 8.0; 
                
    float denom = NdotV * (1.0 - k) + k;
    return NdotV / max(denom, 1e-7);
}

half Custom_V_SmithGGX(half NdotV, half NdotL, half roughness)
{
    return G_SchlickGGX(NdotV, roughness) * G_SchlickGGX(NdotL, roughness);
}

#endif  
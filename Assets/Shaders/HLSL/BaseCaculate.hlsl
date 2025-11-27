#ifndef BASIC_CACULATE_INCLUDE
#define BASIC_CACULATE_INCLUDE

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"

// ====================== 常用工具函数 ======================
real DisneyLuminance(real3 color)
{
    return dot(color,real3(0.2126, 0.7152, 0.0722));
}

real Custom_Sq(real x)
{
    return x * x;
}

// Schlick 近似 Fresnel（Disney 用 5 次幂）
real Custom_SchlickFresnel(real cosTheta)
{
    real m = saturate(1.0 - cosTheta);
    real m2 = m * m;
    return m2 * m2 * m; // m^5
}

// Schlick 近似 Fresnel
real3 Custom_SchlickFresnel(real3 f0,real u)
{
    return f0 + (1.0 - f0) * pow(max(1.0 - u, 0.0),5.0);
}

// 漫反射（Disney Diffuse）
real3 DisneyDiffuse(real NdotV, real NdotL, real LdotH, real roughness, real3 baseColor)
{
    real fd90 = 0.5 + 2.0 * roughness * Custom_Sq(LdotH);
    real lightScatter = 1.0 + (fd90 - 1.0) * pow(max(1.0 - NdotL, 0.0), 5.0);
    real viewScatter = 1.0 + (fd90 - 1.0) * pow(max(1.0 - NdotV, 0.0), 5.0);
    return (baseColor / PI) * lightScatter * viewScatter;
}

real3 URPDiffuse(real metallic,real3 albedo)
{
    real oneMinusReflectivity  = OneMinusReflectivityMetallic(metallic);
    return albedo * oneMinusReflectivity;
}

real Custom_D_GGX(real NdotH, real roughness) 
{
    real a = Custom_Sq(roughness);
    real a2 = Custom_Sq(a);
    real denom = PI * Custom_Sq(Custom_Sq(NdotH) * (a2 - 1.0) + 1.0);
    return a2 / max(denom, 1e-7);
}

real Custom_D_Blinn(real roughness,real NdotH)
{
    real a = 2 / pow(roughness,4) - 2;
    return (a + 2) * pow(NdotH,a) / 2 * PI;
}

real Custom_D_GGX_Anisotropic(real NdotH, real3 H, real3 T, real3 B, real at, real ab)
{
    real TdotH = dot(T, H);
    real BdotH = dot(B, H);
    real a2 = at * ab;
    real3 d = real3(ab * TdotH, at * BdotH, a2 * NdotH);
    real d2 = dot(d, d);
    real b2 = a2 / d2;
    return a2 * b2 * b2 * INV_PI;
}

real G_SchlickGGX(real NdotV, real roughness) 
{
    // Disney modification for direct lighting hotness reduction
    real r = roughness + 1.0;
    real k = (r * r) / 8.0; 
                
    real denom = NdotV * (1.0 - k) + k;
    return NdotV / max(denom, 1e-7);
}

real Custom_V_SmithGGX(real NdotV, real NdotL, real roughness)
{
    return G_SchlickGGX(NdotV, roughness) * G_SchlickGGX(NdotL, roughness);
}

real3 DisneySheen(real loh,real3 sheenColor)
{
    return sheenColor * pow(max(1-loh,0.0),5.0);
}

#endif  
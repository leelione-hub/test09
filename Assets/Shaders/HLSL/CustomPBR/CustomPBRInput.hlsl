#ifndef CUSTOM_PBR_INPUT_INCLUDE
#define CUSTOM_PBR_INPUT_INCLUDE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half3 _EmissionColor;
half3 _SubsurfaceColor;
half _Glossiness;
half _Anisotropy;
half _Roughness;
half _Metallic;
half _BumpScale;
half _OcclusionStrength;
half _Cutoff;
half _Sheen;
half _SheenTint;
half _Clearcoat;
half _ClearcoatGloss;
half _Subsurface;
half _Thickness;
half _TransmissionPower;
half _TransmissionDistortion;
CBUFFER_END

TEXTURE2D(_MetallicMap);    SAMPLER(sampler_MetallicMap);
TEXTURE2D(_RoughnessMap);   SAMPLER(sampler_RoughnessMap);
TEXTURE2D(_OcclusionMap);   SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_ThicknessMap);   SAMPLER(sampler_ThicknessMap);

#endif
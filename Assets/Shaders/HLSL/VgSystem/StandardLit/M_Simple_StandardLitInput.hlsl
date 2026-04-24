#ifndef VG_M_SIMPLE_STANDARD_LIT_INPUT_INCLUDED
#define VG_M_SIMPLE_STANDARD_LIT_INPUT_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

CBUFFER_START(UnityPerMaterial)
float4 _BaseColor;
float4 _BaseMap_ST;
float4 _EmissionColor;
float _Cutoff;
float _Metallic;
float _Roughness;
float _Alpha;
float _BumpScale;
float _RoughnessMin;
float _EmissiveIntensity;
float _BackBrightness;
float _ShadowStrength;
CBUFFER_END

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_NRMTex); SAMPLER(sampler_NRMTex);
TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
    uint instanceID : SV_InstanceID;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
};

inline void M_InitializeSimpleStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = VgSampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    half4 nrm = SAMPLE_TEXTURE2D(_NRMTex, sampler_NRMTex, uv);
    outSurfaceData.alpha = albedoAlpha.a * _BaseColor.a * _Alpha;
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = GetNRM_Metallic(nrm, _Metallic);
    outSurfaceData.specular = 0;
    outSurfaceData.smoothness = 1.0h - GetNRM_Roughness(nrm, _Roughness, _RoughnessMin);
    outSurfaceData.normalTS = GetNRM_Normal(nrm, _BumpScale);
    outSurfaceData.occlusion = 1;
    #if defined(_EMISSION_ON)
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, _EmissiveIntensity, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    #else
    outSurfaceData.emission = 0;
    #endif
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif

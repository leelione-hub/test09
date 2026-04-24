#ifndef VG_M_SIMPLE_ROCK_INPUT_INCLUDED
#define VG_M_SIMPLE_ROCK_INPUT_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseColor;
float4 _BaseMap_ST;
float4 _MossUV;
float4 _MossTint;
float _Cutoff;
float _Alpha;
float _RockNormalIntensity;
float _RockRoughnessMin;
float _RockRoughnessMax;
float _MossRoughnessMin;
float _MossRoughnessMax;
float _NoiseMin;
float _NoiseMax;
float _MossContrast;
float _BackBrightness;
float _ShadowStrength;
float _AOStrength;
CBUFFER_END

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_MixTexNR); SAMPLER(sampler_MixTexNR);
TEXTURE2D(_MossBase); SAMPLER(sampler_MossBase);

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
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

inline float2 MSimpleRockGetMossUV(float3 positionWS)
{
    float2 mossScale = max(_MossUV.xy, float2(1e-4, 1e-4));
    return positionWS.xz / (float2(2, 2) / mossScale) + (_MossUV.zw / mossScale);
}

inline half MSimpleRockGetBlendMask(float3 positionWS, float3 normalWS, half edgeNoise)
{
    float s = smoothstep(_NoiseMin, _NoiseMax, normalWS.y);
    return saturate((s * (s + 1.0h)) - pow(abs(edgeNoise), max(_MossContrast, 0.01h)));
}

inline void M_InitializeSimpleRockSurfaceData(float2 uv, float3 positionWS, float3 normalWS, out SurfaceData outSurfaceData)
{
    half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    half4 mixSample = SAMPLE_TEXTURE2D(_MixTexNR, sampler_MixTexNR, uv);
    half edgeNoise = mixSample.a;
    half3 albedo = baseSample.rgb * _BaseColor.rgb;
    half roughness = saturate(lerp(_RockRoughnessMin, _RockRoughnessMax, mixSample.b));

    #if defined(_USEGROSS)
    float2 mossUV = MSimpleRockGetMossUV(positionWS);
    half4 mossColor = SAMPLE_TEXTURE2D(_MossBase, sampler_MossBase, mossUV);
    half groundRoughness = 1.0h - mossColor.a;
    half blendMask = MSimpleRockGetBlendMask(positionWS, normalWS, edgeNoise);
    albedo = lerp(mossColor.rgb * _MossTint.rgb, albedo, blendMask);
    roughness = lerp(lerp(_MossRoughnessMin, _MossRoughnessMax, groundRoughness), roughness, blendMask);
    #endif

    outSurfaceData.alpha = baseSample.a * _BaseColor.a * _Alpha;
    outSurfaceData.albedo = albedo;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = 0;
    outSurfaceData.smoothness = saturate(1.0h - roughness);
    outSurfaceData.normalTS = GetNRM_Normal(mixSample, _RockNormalIntensity);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif

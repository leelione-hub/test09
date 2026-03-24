#ifndef VG_ROCK_INPUT_INCLUDED
#define VG_ROCK_INPUT_INCLUDED

#include "Assets/Shaders/HLSL/VgSystem/VgVertexInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/HLSL/VgSystem/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
    float4 _BaseColor;
    float _Cutoff;
    float _Alpha;
    float _RockRoughnessMax;
    float _BackBrightness;
    float _ShadowStrength;
    float _AOStrength;
    float4 _BaseMap_ST;
CBUFFER_END

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

struct RockAttributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
    uint instanceID : SV_InstanceID;
};

struct RockVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
};

float3 _LightDirection;
float3 _LightPosition;

inline RockVaryings RockForwardVert(RockAttributes input)
{
    RockVaryings output = (RockVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    float3 positionWS = GetInstanceWorldPosition(input.positionOS, input.instanceID);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.positionWS = positionWS;
    output.normalWS = normalize(GetInstanceWorldNormal(input.normalOS, input.instanceID));
    return output;
}

inline half VgRockDiffuseTerm(half3 normalWS, half3 lightDirWS)
{
    half ndl = dot(normalWS, lightDirWS);
    #if defined(_LAMBERT_HALFLAMBERT)
    return saturate(ndl * 0.5h + 0.5h);
    #else
    return saturate(ndl);
    #endif
}

inline half3 VgRockSpecularTerm(half3 normalWS, half3 lightDirWS, half3 viewDirWS, half3 lightColor)
{
    #if defined(_SPECULARHIGHLIGHTS)
    half3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
    half ndh = saturate(dot(normalWS, halfDir));
    half exponent = lerp(64.0h, 4.0h, saturate(_RockRoughnessMax));
    return lightColor * pow(ndh, exponent);
    #else
    return 0;
    #endif
}

inline half3 VgRockEnvironmentReflection(half3 normalWS, half3 viewDirWS, float3 positionWS, float2 normalizedScreenSpaceUV)
{
    #if defined(_ENVIRONMENTREFLECTIONS)
    half3 reflectVector = reflect(-viewDirWS, normalWS);
    return GlossyEnvironmentReflection(reflectVector, positionWS, saturate(_RockRoughnessMax), 1.0h, normalizedScreenSpaceUV);
    #else
    return 0;
    #endif
}

inline void M_InitializeRockSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    outSurfaceData.alpha = tex.a * _BaseColor.a * _Alpha;
    outSurfaceData.albedo = tex.rgb * _BaseColor.rgb;
    outSurfaceData.metallic = 0;
    outSurfaceData.specular = half3(0, 0, 0);
    outSurfaceData.smoothness = saturate(1.0h - _RockRoughnessMax);
    outSurfaceData.normalTS = half3(0, 0, 1);
    outSurfaceData.occlusion = 1;
    outSurfaceData.emission = 0;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif
